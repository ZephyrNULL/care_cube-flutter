/*
 * Care Cube - Smart Medicine Box (ESP32)
 * ==========================================================
 *  2x VL53L0X Time-of-Flight sensors   -> medicine presence/count
 *  RTC DS3231                           -> scheduled medicine times
 *  DHT22                                -> temperature & humidity
 *  16x4 I2C LCD display                 -> status screens
 *  Buzzer + 2 LEDs                      -> audio/visual reminders
 *  MQTT over HiveMQ public broker       -> live status to Flutter app
 *
 * REQUIRED LIBRARIES (Arduino IDE -> Library Manager):
 *   - Adafruit VL53L0X
 *   - LiquidCrystal I2C (Frank de Brabander)
 *   - PubSubClient (Nick O'Leary)
 *   - RTClib (Adafruit)
 *   - DHT sensor library (Adafruit)
 *   - ArduinoJson
 *
 * HOW IT WORKS:
 *   - Reads time from RTC, temperature/humidity from DHT22,
 *     distance from 2 VL53L0X sensors.
 *   - At scheduled medicine times, activates buzzer + LED reminder
 *     and shows "PLEASE TAKE" on LCD.
 *   - When medicine is removed (distance > threshold), confirms
 *     dose taken, shows "TAKEN" on LCD for 2 minutes.
 *   - Publishes rich JSON status to HiveMQ MQTT broker:
 *         care_cube/<BOX_ID>/status
 *   - Publishes alerts to:
 *         medicinebox/notifications
 *   - Receives schedule commands from app via:
 *         care_cube/<BOX_ID>/commands
 *   - Wi-Fi: enter credentials below, or use the app's Setup Wizard.
 *     If the box cannot connect it starts an access point
 *     "CareCube_Setup" (http://192.168.4.1/setup) to receive Wi-Fi.
 * ==========================================================
 */

#include <Wire.h>
#include <RTClib.h>
#include <LiquidCrystal_I2C.h>
#include <DHT.h>
#include <VL53L0X.h>
#include <WiFi.h>
#include <WebServer.h>
#include <PubSubClient.h>
#include <Preferences.h>
#include <ArduinoJson.h>

// =====================================================
// CONFIGURATION - UPDATE THESE
// =====================================================

const char* WIFI_SSID_DEFAULT = "YOUR_WIFI_SSID";
const char* WIFI_PASS_DEFAULT  = "YOUR_WIFI_PASSWORD";

const char* BOX_ID     = "CARE-1234";
const char* MQTT_SERVER = "broker.hivemq.com";
const int   MQTT_PORT   = 1883;

// =====================================================
// I2C PINS
// =====================================================

#define SDA_PIN 21
#define SCL_PIN 22

// =====================================================
// HARDWARE PINS
// =====================================================

#define DHTPIN 4
#define DHTTYPE DHT22
#define BUZZER 25
#define LED1 26
#define LED2 27
#define XSHUT1 18
#define XSHUT2 19

// =====================================================
// SENSORS & PERIPHERALS
// =====================================================

RTC_DS3231 rtc;
LiquidCrystal_I2C lcd(0x27, 16, 4);
DHT dht(DHTPIN, DHTTYPE);
VL53L0X sensor1;
VL53L0X sensor2;

// =====================================================
// NETWORK
// =====================================================

WiFiClient espClient;
PubSubClient mqtt(espClient);
WebServer setupServer(80);
Preferences prefs;

// =====================================================
// MEDICINE SETTINGS (default - overridden by app via MQTT)
// =====================================================

int s1Hour = 8;
int s1Minute = 0;
int s2Hour = 20;
int s2Minute = 0;

const int DISTANCE_LIMIT = 70;
const unsigned long MEDICINE_DISPLAY_TIME = 2UL * 60UL * 1000UL;

// =====================================================
// STATE FLAGS
// =====================================================

bool s1ReminderDone   = false;
bool s2ReminderDone   = false;
bool s1ReminderActive = false;
bool s2ReminderActive = false;
bool s1MedicineTaken  = false;
bool s2MedicineTaken  = false;
int  activeSensor     = 0;
bool medicineTakenDisplay = false;
unsigned long medicineTakenStartTime = 0;

// =====================================================
// TIMING
// =====================================================

unsigned long lastStatusPublish = 0;
unsigned long lastMqttReconnect = 0;
unsigned long lastScheduleCheck = 0;
bool setupMode = false;

// Previous presence state for dose_taken detection
bool prevPresent1 = false;
bool prevPresent2 = false;

// =====================================================
// TOPIC HELPERS
// =====================================================

String statusTopic() {
  return String("care_cube/") + String(BOX_ID) + "/status";
}

String commandTopic() {
  return String("care_cube/") + String(BOX_ID) + "/commands";
}

String alertTopic() {
  return String("medicinebox/notifications");
}

// =====================================================
// JSON HELPER (lightweight parser for command values)
// =====================================================

String getJsonValue(String json, String key) {
  String search = String("\"") + key + "\"";
  int pos = json.indexOf(search);
  if (pos == -1) return "";
  pos += search.length();
  while (pos < (int)json.length() &&
         (json[pos] == ' ' || json[pos] == ':' || json[pos] == '"')) {
    pos++;
  }
  String value;
  while (pos < (int)json.length() &&
         json[pos] != '"' && json[pos] != '}' && json[pos] != ',') {
    value += json[pos];
    pos++;
  }
  return value;
}

// =====================================================
// GET AVERAGE DISTANCE
// =====================================================

int getDistance(VL53L0X &sensor) {
  long total = 0;
  int validReadings = 0;
  for (int i = 0; i < 5; i++) {
    int distance = sensor.readRangeContinuousMillimeters();
    if (!sensor.timeoutOccurred()) {
      total += distance;
      validReadings++;
    }
    delay(20);
  }
  return (validReadings == 0) ? 9999 : total / validReadings;
}

// =====================================================
// MQTT CONNECT
// =====================================================

bool mqttConnect() {
  if (mqtt.connected()) return true;
  String clientId = String("care_cube_") + String(BOX_ID) + "_" +
                    String((uint32_t)ESP.getEfuseMac(), HEX);
  Serial.print("MQTT connecting... ");
  if (mqtt.connect(clientId.c_str())) {
    Serial.println("connected");
    mqtt.subscribe(commandTopic().c_str());
    return true;
  }
  Serial.print("failed, rc=");
  Serial.println(mqtt.state());
  return false;
}

// =====================================================
// MQTT PUBLISH: STATUS (rich JSON)
// =====================================================

void publishStatus(float temp, float hum, int d1, int d2,
                    bool p1, bool p2, int count,
                    String doseTaken, String reminderActive) {
  StaticJsonDocument<512> doc;
  doc["box_id"] = BOX_ID;
  doc["temperature"] = isnan(temp) ? 0 : temp;
  doc["humidity"] = isnan(hum) ? 0 : hum;
  doc["sensor1_distance"] = d1;
  doc["sensor2_distance"] = d2;
  doc["compartment1_present"] = p1;
  doc["compartment2_present"] = p2;
  doc["medicine_count"] = count;
  doc["total_compartments"] = 2;
  doc["s1_medicine_taken"] = s1MedicineTaken;
  doc["s2_medicine_taken"] = s2MedicineTaken;

  if (doseTaken.length() > 0) {
    doc["dose_taken"] = doseTaken;
  }
  if (reminderActive.length() > 0) {
    doc["reminder_active"] = reminderActive;
  }

  char buffer[512];
  serializeJson(doc, buffer);
  mqtt.publish(statusTopic().c_str(), buffer);
  Serial.print("Published status: ");
  Serial.println(buffer);
}

// =====================================================
// MQTT PUBLISH: ALERT
// =====================================================

void publishAlert(const char* message) {
  mqtt.publish(alertTopic().c_str(), message);
  Serial.print("Alert: ");
  Serial.println(message);
}

// =====================================================
// MQTT COMMAND HANDLER
// =====================================================

void mqttCallback(char* topic, byte* payload, unsigned int length) {
  String message;
  for (unsigned int i = 0; i < length; i++) message += (char)payload[i];

  Serial.print("Command received: ");
  Serial.println(message);

  String command = getJsonValue(message, "command");

  if (command == "set_schedule") {
    // App sends: {"command":"set_schedule","sensor":1,"hour":8,"minute":30}
    int sensor = getJsonValue(message, "sensor").toInt();
    int hour = getJsonValue(message, "hour").toInt();
    int minute = getJsonValue(message, "minute").toInt();

    if (sensor == 1) {
      s1Hour = hour;
      s1Minute = minute;
      s1ReminderDone = false;
      Serial.println("S1 schedule set to " + String(hour) + ":" + String(minute < 10 ? "0" : "") + String(minute));
    } else if (sensor == 2) {
      s2Hour = hour;
      s2Minute = minute;
      s2ReminderDone = false;
      Serial.println("S2 schedule set to " + String(hour) + ":" + String(minute < 10 ? "0" : "") + String(minute));
    }
  } else if (command == "open") {
    String compartment = getJsonValue(message, "compartment");
    Serial.println("Opening compartment: " + compartment);
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("OPENING");
    lcd.setCursor(0, 1);
    lcd.print(compartment);
  } else if (command == "dose_taken") {
    String compartment = getJsonValue(message, "compartment");
    Serial.println("Dose marked as taken: " + compartment);
  } else if (command == "add_schedule") {
    String medicine = getJsonValue(message, "medicine_name");
    String time = getJsonValue(message, "scheduled_time");
    Serial.println("New schedule: " + medicine + " at " + time);
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("SCHEDULE ADDED");
    lcd.setCursor(0, 1);
    lcd.print(medicine.length() > 16 ? medicine.substring(0, 16) : medicine);
  }
}

// =====================================================
// WIFI CONNECTION
// =====================================================

bool connectWiFi(String ssid, String pass) {
  if (ssid.isEmpty() || ssid == "YOUR_WIFI_SSID" || ssid == "your_wifi_ssid") {
    Serial.println("No valid Wi-Fi credentials stored.");
    return false;
  }
  Serial.print("Connecting to Wi-Fi: ");
  Serial.println(ssid);
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid.c_str(), pass.c_str());

  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < 20000) {
    delay(500);
    Serial.print(".");
  }
  Serial.println();
  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("Wi-Fi connected. IP: ");
    Serial.println(WiFi.localIP());
    return true;
  }
  Serial.println("Wi-Fi connection failed.");
  return false;
}

// =====================================================
// SETUP MODE (AP for WiFi provisioning)
// =====================================================

void startSetupMode() {
  setupMode = true;
  Serial.println("Starting setup access point 'CareCube_Setup'");
  WiFi.mode(WIFI_AP);
  WiFi.softAP("CareCube_Setup");

  setupServer.on("/setup", HTTP_POST, []() {
    String body = setupServer.arg("plain");
    Serial.println("Setup request: " + body);

    String ssid = getJsonValue(body, "ssid");
    String pass = getJsonValue(body, "pass");

    setupServer.send(200, "text/plain", "OK");

    if (ssid.isEmpty()) return;

    prefs.putString("ssid", ssid);
    prefs.putString("pass", pass);

    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("SAVING WIFI...");

    if (connectWiFi(ssid, pass)) {
      Serial.println("Wi-Fi configured. Rebooting...");
      delay(500);
      ESP.restart();
    } else {
      Serial.println("Wi-Fi failed, restarting setup AP.");
      WiFi.mode(WIFI_AP);
      WiFi.softAP("CareCube_Setup");
    }
  });

  setupServer.begin();
  Serial.println("Setup server ready at http://192.168.4.1/setup");

  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("SETUP MODE");
  lcd.setCursor(0, 1);
  lcd.print("CONNECT TO WIFI");
}

// =====================================================
// LCD SCREENS
// =====================================================

void showNormalScreen(DateTime now, float temp, float hum) {
  lcd.clear();

  // LINE 1 - TIME
  lcd.setCursor(0, 0);
  lcd.print("Time: ");
  if (now.hour() < 10) lcd.print("0");
  lcd.print(now.hour());
  lcd.print(":");
  if (now.minute() < 10) lcd.print("0");
  lcd.print(now.minute());
  lcd.print(":");
  if (now.second() < 10) lcd.print("0");
  lcd.print(now.second());

  // LINE 2 - DATE
  lcd.setCursor(0, 1);
  lcd.print("Date: ");
  if (now.day() < 10) lcd.print("0");
  lcd.print(now.day());
  lcd.print("/");
  if (now.month() < 10) lcd.print("0");
  lcd.print(now.month());
  lcd.print("/");
  lcd.print(now.year() % 100);

  // LINE 3 - TEMP + HUM
  lcd.setCursor(0, 2);
  lcd.print("Tmp:");
  if (!isnan(temp)) {
    lcd.print(temp, 1);
    lcd.print((char)223);
    lcd.print("C");
  } else {
    lcd.print("ERR");
  }
  lcd.print(" Hum:");
  if (!isnan(hum)) {
    lcd.print(hum, 1);
    lcd.print("%");
  } else {
    lcd.print("ERR");
  }

  // LINE 4 - STATUS
  lcd.setCursor(0, 3);
  if (s1MedicineTaken || s2MedicineTaken) {
    lcd.print("MEDICINE TAKEN");
  } else {
    lcd.print(BOX_ID);
  }
}

void showMedicineScreen(int sensorNumber, int distance) {
  lcd.clear();

  lcd.setCursor(0, 0);
  lcd.print("----------------");

  lcd.setCursor(0, 1);
  if (distance <= DISTANCE_LIMIT) {
    lcd.print("S");
    lcd.print(sensorNumber);
    lcd.print(": TAKE MEDICINE");
  } else {
    lcd.print("S");
    lcd.print(sensorNumber);
    lcd.print(": MEDICINE");
  }

  lcd.setCursor(0, 2);
  lcd.print("----------------");

  lcd.setCursor(0, 3);
  if (distance > DISTANCE_LIMIT) {
    lcd.print("TAKEN");
  } else {
    lcd.print("PLEASE TAKE");
  }
}

void showMedicineTakenScreen(int sensorNumber) {
  lcd.clear();

  lcd.setCursor(0, 0);
  lcd.print("----------------");

  lcd.setCursor(0, 1);
  lcd.print("S");
  lcd.print(sensorNumber);
  lcd.print(": MEDICINE");

  lcd.setCursor(0, 2);
  lcd.print("TAKEN");

  lcd.setCursor(0, 3);
  lcd.print("----------------");
}

// =====================================================
// SETUP
// =====================================================

void setup() {
  Serial.begin(115200);
  Serial.println();
  Serial.println("Care Cube starting...");

  Wire.begin(SDA_PIN, SCL_PIN);

  // LCD
  lcd.init();
  lcd.backlight();
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("MEDICINE BOX");
  lcd.setCursor(0, 1);
  lcd.print("Starting...");

  // DHT22
  dht.begin();

  // Buzzer
  pinMode(BUZZER, OUTPUT);
  digitalWrite(BUZZER, LOW);

  // LEDs
  pinMode(LED1, OUTPUT);
  pinMode(LED2, OUTPUT);
  digitalWrite(LED1, LOW);
  digitalWrite(LED2, LOW);

  // RTC
  if (!rtc.begin()) {
    lcd.clear();
    lcd.print("RTC ERROR");
    Serial.println("RTC ERROR");
    while (1);
  }
  // Uncomment ONLY ONCE if RTC time needs setting:
  // rtc.adjust(DateTime(F(__DATE__), F(__TIME__)));

  // VL53L0X XSHUT
  pinMode(XSHUT1, OUTPUT);
  pinMode(XSHUT2, OUTPUT);
  digitalWrite(XSHUT1, LOW);
  digitalWrite(XSHUT2, LOW);
  delay(100);

  // Sensor 1
  digitalWrite(XSHUT1, HIGH);
  delay(100);
  sensor1.setTimeout(500);
  if (!sensor1.init()) {
    lcd.clear();
    lcd.print("S1 SENSOR FAIL");
    Serial.println("Sensor 1 Failed");
    while (1);
  }
  sensor1.setAddress(0x30);
  sensor1.startContinuous();

  // Sensor 2
  digitalWrite(XSHUT2, HIGH);
  delay(100);
  sensor2.setTimeout(500);
  if (!sensor2.init()) {
    lcd.clear();
    lcd.print("S2 SENSOR FAIL");
    Serial.println("Sensor 2 Failed");
    while (1);
  }
  sensor2.setAddress(0x31);
  sensor2.startContinuous();

  // Preferences
  prefs.begin("carecube", false);
  String ssid = prefs.getString("ssid", String(WIFI_SSID_DEFAULT));
  String pass = prefs.getString("pass", String(WIFI_PASS_DEFAULT));

  // Connect WiFi or start setup AP
  if (connectWiFi(ssid, pass)) {
    mqtt.setServer(MQTT_SERVER, MQTT_PORT);
    mqtt.setCallback(mqttCallback);
    mqttConnect();
    publishAlert("CARE CUBE: Online");
  } else {
    startSetupMode();
  }

  // Ready
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("MEDICINE BOX");
  lcd.setCursor(0, 1);
  lcd.print("SYSTEM READY");
  delay(2000);
  lcd.clear();
}

// =====================================================
// LOOP
// =====================================================

void loop() {
  // Handle WiFi connected mode
  if (WiFi.status() == WL_CONNECTED) {
    if (setupMode) {
      setupMode = false;
      WiFi.mode(WIFI_STA);
    }

    // MQTT
    if (!mqtt.connected()) {
      if (millis() - lastMqttReconnect > 5000) {
        lastMqttReconnect = millis();
        mqttConnect();
      }
    }
    mqtt.loop();

    // GET SENSORS
    DateTime now = rtc.now();
    float temp = dht.readTemperature();
    float hum  = dht.readHumidity();
    int d1 = getDistance(sensor1);
    int d2 = getDistance(sensor2);
    bool p1 = d1 >= 0 && d1 <= DISTANCE_LIMIT;
    bool p2 = d2 >= 0 && d2 <= DISTANCE_LIMIT;
    int medicineCount = (p1 ? 1 : 0) + (p2 ? 1 : 0);

    // Detect dose_taken: present -> absent
    String doseTaken = "";
    if (prevPresent1 && !p1) doseTaken = "Cup 1";
    if (prevPresent2 && !p2) {
      if (doseTaken.length() > 0) doseTaken = "Cup 1&Cup 2";
      else doseTaken = "Cup 2";
    }
    prevPresent1 = p1;
    prevPresent2 = p2;

    // Determine reminder active string
    String reminderActive = "";
    if (s1ReminderActive) reminderActive = "S1";
    else if (s2ReminderActive) reminderActive = "S2";

    // Periodic status publish (every 5 seconds)
    if (millis() - lastStatusPublish > 5000) {
      lastStatusPublish = millis();
      publishStatus(temp, hum, d1, d2, p1, p2, medicineCount,
                    doseTaken, reminderActive);
    }

    // ===================================================
    // MEDICINE TAKEN DISPLAY (2 minutes)
    // ===================================================

    if (medicineTakenDisplay) {
      showMedicineTakenScreen(activeSensor);
      if (millis() - medicineTakenStartTime >= MEDICINE_DISPLAY_TIME) {
        medicineTakenDisplay = false;
        activeSensor = 0;
        lcd.clear();
      }
    }

    // ===================================================
    // S1 REMINDER TRIGGER
    // ===================================================

    else if (now.hour() == s1Hour && now.minute() == s1Minute &&
             !s1ReminderDone && !s1ReminderActive && !s2ReminderActive) {
      s1ReminderActive = true;
      activeSensor = 1;
      s1MedicineTaken = false;

      digitalWrite(BUZZER, HIGH);
      digitalWrite(LED1, HIGH);
      digitalWrite(LED2, LOW);

      publishAlert("REMINDER: Take Cup 1 medicine NOW!");
      Serial.println("S1 REMINDER STARTED");
    }

    // ===================================================
    // S2 REMINDER TRIGGER
    // ===================================================

    else if (now.hour() == s2Hour && now.minute() == s2Minute &&
             !s2ReminderDone && !s2ReminderActive && !s1ReminderActive) {
      s2ReminderActive = true;
      activeSensor = 2;
      s2MedicineTaken = false;

      digitalWrite(BUZZER, HIGH);
      digitalWrite(LED2, HIGH);
      digitalWrite(LED1, LOW);

      publishAlert("REMINDER: Take Cup 2 medicine NOW!");
      Serial.println("S2 REMINDER STARTED");
    }

    // ===================================================
    // S1 REMINDER ACTIVE - CHECK SENSOR
    // ===================================================

    else if (s1ReminderActive) {
      showMedicineScreen(1, d1);

      if (d1 > DISTANCE_LIMIT || (!p1 && d1 != 9999)) {
        // Medicine taken
        s1ReminderActive = false;
        s1ReminderDone = true;
        s1MedicineTaken = true;

        digitalWrite(BUZZER, LOW);
        digitalWrite(LED1, LOW);
        digitalWrite(LED2, LOW);

        medicineTakenDisplay = true;
        activeSensor = 1;
        medicineTakenStartTime = millis();

        publishAlert("CONFIRMED: Cup 1 medicine TAKEN");
        Serial.println("S1: MEDICINE TAKEN");
      } else {
        // Keep reminder active
        digitalWrite(BUZZER, HIGH);
        digitalWrite(LED1, HIGH);
        digitalWrite(LED2, LOW);
      }
    }

    // ===================================================
    // S2 REMINDER ACTIVE - CHECK SENSOR
    // ===================================================

    else if (s2ReminderActive) {
      showMedicineScreen(2, d2);

      if (d2 > DISTANCE_LIMIT || (!p2 && d2 != 9999)) {
        // Medicine taken
        s2ReminderActive = false;
        s2ReminderDone = true;
        s2MedicineTaken = true;

        digitalWrite(BUZZER, LOW);
        digitalWrite(LED2, LOW);
        digitalWrite(LED1, LOW);

        medicineTakenDisplay = true;
        activeSensor = 2;
        medicineTakenStartTime = millis();

        publishAlert("CONFIRMED: Cup 2 medicine TAKEN");
        Serial.println("S2: MEDICINE TAKEN");
      } else {
        // Keep reminder active
        digitalWrite(BUZZER, HIGH);
        digitalWrite(LED2, HIGH);
        digitalWrite(LED1, LOW);
      }
    }

    // ===================================================
    // NORMAL SCREEN
    // ===================================================

    else {
      showNormalScreen(now, temp, hum);
      digitalWrite(LED1, LOW);
      digitalWrite(LED2, LOW);
    }

    // ===================================================
    // RESET EVERY DAY (00:01)
    // ===================================================

    if (now.hour() == 0 && now.minute() == 1) {
      s1ReminderDone = false;
      s2ReminderDone = false;
    }

    delay(500);

  } else {
    // WiFi not connected - setup mode
    if (!setupMode) startSetupMode();
    setupServer.handleClient();
    delay(10);
  }
}
