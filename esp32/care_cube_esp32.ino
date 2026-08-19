/*
 * Care Cube - Smart Medicine Box (ESP32)
 * ==========================================================
 *  2x VL53L0X Time-of-Flight sensors   -> medicine presence/count
 *  16x2 I2C LCD display
 *  MQTT over HiveMQ public broker      -> live status to Flutter app
 *
 * REQUIRED LIBRARIES (Arduino IDE -> Library Manager):
 *   - Adafruit VL53L0X
 *   - LiquidCrystal I2C (Frank de Brabander)
 *   - PubSubClient (Nick O'Leary)
 *
 * HOW IT WORKS:
 *   - The box reads distance from 2 sensors. When an object is closer
 *     than MEDICINE_THRESHOLD_MM (70mm), that compartment counts as
 *     "filled". medicine_count = number of filled compartments.
 *   - Publishes JSON status to HiveMQ topic:
 *         care_cube/<BOX_ID>/status
 *       Status payload:
 *         {
 *           "box_id": "CARE-1234",
 *           "sensor1_distance": 55,
 *           "sensor2_distance": 120,
 *           "compartment1_present": true,
 *           "compartment2_present": false,
 *           "medicine_count": 1,
 *           "total_compartments": 2,
 *           "dose_taken": "Cup 1"   <-- only sent once when medicine is removed
 *         }
 *   - When medicine is removed from a compartment (sensor goes
 *     present -> absent), the box publishes a one-time "dose_taken"
 *     field ("Cup 1" / "Cup 2"). The app marks that dose as taken.
 *   - Listens for commands (open / dose_taken / add_schedule) on:
 *         care_cube/<BOX_ID>/commands
 *       add_schedule payload from the app:
 *         {"command":"add_schedule","data":{
 *           "compartment":"Cup 1",
 *           "scheduled_time":"8:30 PM",
 *           "medicine_name":"Paracetamol",
 *           "dosage":"1 Tablet",
 *           "active":true},...}
 *   - Wi-Fi: enter credentials below, or use the app's Setup Wizard.
 *     If the box cannot connect it starts an access point
 *     "CareCube_Setup" (http://192.168.4.1/setup) to receive Wi-Fi.
 * ==========================================================
 */

#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <VL53L0X.h>
#include <WiFi.h>
#include <WebServer.h>
#include <PubSubClient.h>
#include <Preferences.h>

// ----------------------- CONFIGURATION ------------------------
// Your home Wi-Fi credentials (can also be set via the app Setup Wizard)
const char* WIFI_SSID = "YOUR_WIFI_SSID";
const char* WIFI_PASS = "YOUR_WIFI_PASSWORD";

// Care Cube Box ID - MUST match the Box ID entered in the app
const char* box_id = "CARE-1234";

// HiveMQ public MQTT broker
const char* mqtt_server = "broker.hivemq.com";
const int   mqtt_port   = 1883;

// Compartment counts as "filled" when an object is closer than this (mm)
const int MEDICINE_THRESHOLD_MM = 70;

// Publish interval for live status (ms)
const unsigned long PUBLISH_INTERVAL = 3000;
// --------------------------------------------------------------

LiquidCrystal_I2C lcd(0x27, 16, 2);

VL53L0X sensor1;
VL53L0X sensor2;

#define XSHUT1 18
#define XSHUT2 19

WiFiClient espClient;
PubSubClient mqtt(espClient);
WebServer setupServer(80);
Preferences prefs;

unsigned long lastPublish = 0;
bool setupMode = false;

// Previous presence state used to detect when medicine is removed
bool prevPresent1 = false;
bool prevPresent2 = false;

// Extract a string value for `key` from a JSON string (no library needed)
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

// Smooth distance reading (average of 5 samples). -1 on timeout.
int getDistance(VL53L0X &sensor) {
  long total = 0;
  int valid = 0;
  for (int i = 0; i < 5; i++) {
    uint16_t dist = sensor.readRangeContinuousMillimeters();
    if (!sensor.timeoutOccurred()) {
      total += dist;
      valid++;
    }
    delay(50);
  }
  return valid == 0 ? -1 : (int)(total / valid);
}

void printLcd(String line1, String line2) {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print(line1);
  lcd.setCursor(0, 1);
  lcd.print(line2);
  delay(1500);
}

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
    prefs.end();

    printLcd("SAVING WIFI...", "");

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

void mqttCallback(char* topic, byte* payload, unsigned int length) {
  String message;
  for (unsigned int i = 0; i < length; i++) message += (char)payload[i];

  Serial.print("Command received: ");
  Serial.println(message);

  String command = getJsonValue(message, "command");
  String compartment = getJsonValue(message, "compartment");

  if (command == "open") {
    Serial.println("Opening compartment: " + compartment);
    printLcd("OPENING", compartment);
    // TODO: Add GPIO/servo logic here to physically open the compartment
  } else if (command == "dose_taken") {
    Serial.println("Dose marked as taken: " + compartment);
  } else if (command == "add_schedule") {
    String medicine = getJsonValue(message, "medicine_name");
    String time = getJsonValue(message, "scheduled_time");
    Serial.println("New schedule added: " + medicine + " at " + time);
    printLcd("SCHEDULE ADDED", medicine.length() > 16 ? medicine.substring(0, 16) : medicine);
  } else {
    Serial.println("Unknown command: " + command);
  }
}

void reconnectMqtt() {
  while (!mqtt.connected()) {
    Serial.print("Connecting to MQTT broker...");
    String clientId = String("care_cube_") + String(box_id) + "_" +
                      String((uint32_t)ESP.getEfuseMac(), HEX);
    if (mqtt.connect(clientId.c_str())) {
      Serial.println(" connected!");
      mqtt.subscribe((String("care_cube/") + String(box_id) + "/commands").c_str());
      lastPublish = 0;
    } else {
      Serial.print(" failed, state=");
      Serial.print(mqtt.state());
      Serial.println(" retrying in 5s");
      delay(5000);
    }
  }
}

void publishStatus(int d1, int d2, bool p1, bool p2, int count, String doseTaken) {
  String payload = String("{") +
                   "\"box_id\":\"" + String(box_id) + "\"," +
                   "\"sensor1_distance\":" + String(d1) + "," +
                   "\"sensor2_distance\":" + String(d2) + "," +
                   "\"compartment1_present\":" + String(p1 ? "true" : "false") + "," +
                   "\"compartment2_present\":" + String(p2 ? "true" : "false") + ",";

  // One-time field sent when medicine is removed from a compartment
  if (doseTaken.length() > 0) {
    payload += "\"dose_taken\":\"" + doseTaken + "\",";
  }

  payload += "\"medicine_count\":" + String(count) + "," +
             "\"total_compartments\":2" +
             "}";

  String topic = String("care_cube/") + String(box_id) + "/status";
  mqtt.publish(topic.c_str(), payload.c_str());
  Serial.print("Published: ");
  Serial.println(payload);
}

void updateLcd(bool p1, bool p2) {
  lcd.clear();

  lcd.setCursor(0, 0);
  if (p1) {
    lcd.print("S1 TAKE MEDICINE");
    Serial.println("S1 TAKE MEDICINE");
  } else {
    lcd.print("S1 MEDICINE TAKEN");
    Serial.println("S1 MEDICINE TAKEN");
  }

  lcd.setCursor(0, 1);
  if (p2) {
    lcd.print("S2 TAKE MEDICINE");
    Serial.println("S2 TAKE MEDICINE");
  } else {
    lcd.print("S2 MEDICINE TAKEN");
    Serial.println("S2 MEDICINE TAKEN");
  }
}

void setup() {
  Serial.begin(115200);
  Serial.println();
  Serial.println("Care Cube starting...");

  Wire.begin(21, 22);

  lcd.begin(16, 2);
  lcd.backlight();

  pinMode(XSHUT1, OUTPUT);
  pinMode(XSHUT2, OUTPUT);

  // Turn OFF both sensors
  digitalWrite(XSHUT1, LOW);
  digitalWrite(XSHUT2, LOW);
  delay(100);

  // Start Sensor 1
  digitalWrite(XSHUT1, HIGH);
  delay(100);
  sensor1.setTimeout(500);
  if (!sensor1.init()) {
    Serial.println("Sensor 1 Failed");
    lcd.clear();
    lcd.print("Sensor 1 Fail");
    while (1);
  }
  sensor1.setAddress(0x30);
  sensor1.startContinuous();

  // Start Sensor 2
  digitalWrite(XSHUT2, HIGH);
  delay(100);
  sensor2.setTimeout(500);
  if (!sensor2.init()) {
    Serial.println("Sensor 2 Failed");
    lcd.clear();
    lcd.print("Sensor 2 Fail");
    while (1);
  }
  sensor2.setAddress(0x31);
  sensor2.startContinuous();

  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("MEDICINE BOX");
  delay(1500);

  prefs.begin("carecube", false);
  String ssid = prefs.getString("ssid", String(WIFI_SSID));
  String pass = prefs.getString("pass", String(WIFI_PASS));

  if (connectWiFi(ssid, pass)) {
    mqtt.setServer(mqtt_server, mqtt_port);
    mqtt.setCallback(mqttCallback);
    reconnectMqtt();
  } else {
    startSetupMode();
  }
}

void loop() {
  if (WiFi.status() == WL_CONNECTED) {
    if (setupMode) {
      setupMode = false;
      WiFi.mode(WIFI_STA);
    }

    if (!mqtt.connected()) reconnectMqtt();
    mqtt.loop();

    int distance1 = getDistance(sensor1);
    int distance2 = getDistance(sensor2);

    bool present1 = distance1 >= 0 && distance1 <= MEDICINE_THRESHOLD_MM;
    bool present2 = distance2 >= 0 && distance2 <= MEDICINE_THRESHOLD_MM;
    int medicineCount = (present1 ? 1 : 0) + (present2 ? 1 : 0);

    // Detect when medicine is removed: present -> absent
    String doseTaken = "";
    if (prevPresent1 && !present1) doseTaken = "Cup 1";
    if (prevPresent2 && !present2) doseTaken = (doseTaken.length() > 0 ? doseTaken : "Cup 2");
    prevPresent1 = present1;
    prevPresent2 = present2;

    unsigned long now = millis();
    if (now - lastPublish >= PUBLISH_INTERVAL) {
      lastPublish = now;
      publishStatus(distance1, distance2, present1, present2, medicineCount, doseTaken);
    }

    updateLcd(present1, present2);
    delay(50);
  } else {
    if (!setupMode) startSetupMode();
    setupServer.handleClient();
    delay(10);
  }
}
