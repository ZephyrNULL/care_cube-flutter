#include <Wire.h>
#include <RTClib.h>
#include <LiquidCrystal_I2C.h>
#include <DHT.h>
#include <VL53L0X.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>

// =====================================================
// CONFIGURATION - UPDATE THESE
// =====================================================
const char* WIFI_SSID     = "YOUR_WIFI_SSID";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";

// Unique ID for your box - MUST match the ID in the mobile app
const char* BOX_ID        = "care_cube_user_123";

// MQTT / HIVEMQ
const char* MQTT_SERVER   = "broker.hivemq.com";
const int   MQTT_PORT     = 1883;
const char* STATUS_TOPIC  = "care_cube/care_cube_user_123/status";
const char* ALERT_TOPIC   = "medicinebox/notifications";
const char* MQTT_CLIENT   = "esp32_care_cube_123";

WiFiClient   wifiClient;
PubSubClient mqtt(wifiClient);

// =====================================================
// HARDWARE PINS
// =====================================================
#define SDA_PIN 21
#define SCL_PIN 22
#define DHTPIN 4
#define DHTTYPE DHT22
#define BUZZER 25
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
// MEDICINE SETTINGS
// =====================================================
const int S1_HOUR   = 15;
const int S1_MINUTE = 50;
const int S2_HOUR   = 15;
const int S2_MINUTE = 55;
const int DISTANCE_LIMIT = 70;
const unsigned long MEDICINE_DISPLAY_TIME = 2UL * 60UL * 1000UL;

// State Flags
bool s1ReminderDone   = false;
bool s2ReminderDone   = false;
bool s1ReminderActive = false;
bool s2ReminderActive = false;
bool s1MedicineTaken = false;
bool s2MedicineTaken = false;
int activeSensor = 0;
bool medicineTakenDisplay   = false;
unsigned long medicineTakenStartTime = 0;
unsigned long lastStatusPublish = 0;
unsigned long lastMqttReconnect = 0;

// =====================================================
// HELPER FUNCTIONS
// =====================================================

int getDistance(VL53L0X &sensor) {
  long total = 0;
  int validReadings = 0;
  for(int i = 0; i < 5; i++) {
    int distance = sensor.readRangeContinuousMillimeters();
    if(!sensor.timeoutOccurred()) {
      total += distance;
      validReadings++;
    }
    delay(20);
  }
  return (validReadings == 0) ? 9999 : total / validReadings;
}

bool mqttConnect() {
  if(mqtt.connected()) return true;
  if(mqtt.connect(MQTT_CLIENT)) {
    Serial.println("MQTT Connected");
    return true;
  }
  return false;
}

void publishAlert(const char* message) {
  if(mqttConnect()) {
    mqtt.publish(ALERT_TOPIC, message);
    Serial.print("Alert Published: ");
    Serial.println(message);
  }
}

void publishBoxStatus(float temp, float hum, bool p1, bool p2) {
  StaticJsonDocument<300> doc;
  doc["box_id"] = BOX_ID;
  doc["temperature"] = isnan(temp) ? 0 : temp;
  doc["humidity"] = isnan(hum) ? 0 : hum;
  doc["compartment1_present"] = p1;
  doc["compartment2_present"] = p2;
  doc["medicine_count"] = (p1 ? 1 : 0) + (p2 ? 1 : 0);
  doc["total_compartments"] = 2;

  char buffer[300];
  serializeJson(doc, buffer);
  if(mqttConnect()) {
    mqtt.publish(STATUS_TOPIC, buffer);
    Serial.println("Status JSON Published");
  }
}

void connectWiFi() {
  Serial.print("WiFi connecting...");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  int attempts = 0;
  while(WiFi.status() != WL_CONNECTED && attempts < 40) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  if(WiFi.status() == WL_CONNECTED) Serial.println("\nWiFi OK");
}

// =====================================================
// UI SCREENS
// =====================================================

void showNormalScreen(DateTime now, float temp, float hum) {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Time: ");
  if(now.hour() < 10) lcd.print("0"); lcd.print(now.hour()); lcd.print(":");
  if(now.minute() < 10) lcd.print("0"); lcd.print(now.minute());

  lcd.setCursor(0, 1);
  lcd.print("Tmp:"); lcd.print(temp, 1); lcd.print("C ");
  lcd.print("Hum:"); lcd.print(hum, 0); lcd.print("%");

  lcd.setCursor(0, 2);
  lcd.print(BOX_ID);

  lcd.setCursor(0, 3);
  if(s1MedicineTaken || s2MedicineTaken) lcd.print("MEDICINE TAKEN");
  else lcd.print("SYSTEM READY");
}

void showMedicineScreen(int sensorNumber, int distance) {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("!! REMINDER !!");
  lcd.setCursor(0, 1);
  lcd.print("CUP "); lcd.print(sensorNumber);
  lcd.print(distance <= DISTANCE_LIMIT ? ": PLEASE TAKE" : ": TAKEN");
}

void showMedicineTakenScreen(int sensorNumber) {
  lcd.clear();
  lcd.setCursor(0, 1);
  lcd.print("CUP "); lcd.print(sensorNumber);
  lcd.setCursor(0, 2);
  lcd.print("TAKEN SUCCESSFULLY");
}

// =====================================================
// SETUP & LOOP
// =====================================================

void setup() {
  Serial.begin(115200);
  Wire.begin(SDA_PIN, SCL_PIN);
  lcd.init();
  lcd.backlight();
  dht.begin();
  pinMode(BUZZER, OUTPUT);
  digitalWrite(BUZZER, LOW);

  if(!rtc.begin()) { Serial.println("RTC Fail"); while(1); }

  pinMode(XSHUT1, OUTPUT);
  pinMode(XSHUT2, OUTPUT);
  digitalWrite(XSHUT1, LOW);
  digitalWrite(XSHUT2, LOW);
  delay(100);

  // Sensor 1 Init
  digitalWrite(XSHUT1, HIGH); delay(100);
  sensor1.setTimeout(500);
  if(!sensor1.init()) { Serial.println("S1 Fail"); while(1); }
  sensor1.setAddress(0x30);
  sensor1.startContinuous();

  // Sensor 2 Init
  digitalWrite(XSHUT2, HIGH); delay(100);
  sensor2.setTimeout(500);
  if(!sensor2.init()) { Serial.println("S2 Fail"); while(1); }
  sensor2.setAddress(0x31);
  sensor2.startContinuous();

  connectWiFi();
  mqtt.setServer(MQTT_SERVER, MQTT_PORT);
  mqttConnect();
  publishAlert("CARE CUBE: Online");
}

void loop() {
  mqtt.loop();

  // Reconnect Logic
  if(WiFi.status() != WL_CONNECTED) {
    if(millis() - lastMqttReconnect > 10000) { lastMqttReconnect = millis(); connectWiFi(); }
  } else if(!mqtt.connected()) {
    if(millis() - lastMqttReconnect > 5000) { lastMqttReconnect = millis(); mqttConnect(); }
  }

  DateTime now = rtc.now();
  float temp = dht.readTemperature();
  float hum  = dht.readHumidity();
  int d1 = getDistance(sensor1);
  int d2 = getDistance(sensor2);
  bool p1 = d1 <= DISTANCE_LIMIT;
  bool p2 = d2 <= DISTANCE_LIMIT;

  // Periodic Status Update for App GUI
  if(millis() - lastStatusPublish > 5000) {
    lastStatusPublish = millis();
    publishBoxStatus(temp, hum, p1, p2);
  }

  // Reminder Logic
  if(now.hour() == S1_HOUR && now.minute() == S1_MINUTE && !s1ReminderDone && !s1ReminderActive) {
    s1ReminderActive = true; activeSensor = 1;
    digitalWrite(BUZZER, HIGH);
    publishAlert("REMINDER: Take Cup 1 medicine NOW!");
  }

  if(now.hour() == S2_HOUR && now.minute() == S2_MINUTE && !s2ReminderDone && !s2ReminderActive) {
    s2ReminderActive = true; activeSensor = 2;
    digitalWrite(BUZZER, HIGH);
    publishAlert("REMINDER: Take Cup 2 medicine NOW!");
  }

  // Handle Active Reminders
  if(medicineTakenDisplay) {
    showMedicineTakenScreen(activeSensor);
    if(millis() - medicineTakenStartTime >= MEDICINE_DISPLAY_TIME) {
      medicineTakenDisplay = false; activeSensor = 0; lcd.clear();
    }
  } else if(s1ReminderActive) {
    showMedicineScreen(1, d1);
    if(d1 > DISTANCE_LIMIT) {
      s1ReminderActive = false; s1ReminderDone = true; s1MedicineTaken = true;
      digitalWrite(BUZZER, LOW);
      medicineTakenDisplay = true; activeSensor = 1; medicineTakenStartTime = millis();
      publishAlert("CONFIRMED: Cup 1 medicine TAKEN");
    }
  } else if(s2ReminderActive) {
    showMedicineScreen(2, d2);
    if(d2 > DISTANCE_LIMIT) {
      s2ReminderActive = false; s2ReminderDone = true; s2MedicineTaken = true;
      digitalWrite(BUZZER, LOW);
      medicineTakenDisplay = true; activeSensor = 2; medicineTakenStartTime = millis();
      publishAlert("CONFIRMED: Cup 2 medicine TAKEN");
    }
  } else {
    showNormalScreen(now, temp, hum);
  }

  // Reset at Midnight
  if(now.hour() == 0 && now.minute() == 1) { s1ReminderDone = false; s2ReminderDone = false; }

  delay(500);
}
