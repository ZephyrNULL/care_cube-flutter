import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/medicine_schedule.dart';

class Esp32Service {
  String _boxIp = '';
  bool _isConnected = false;
  DateTime? _lastSync;

  String get boxIp => _boxIp;
  bool get isConnected => _isConnected;
  DateTime? get lastSync => _lastSync;

  void setBoxIp(String ip) {
    _boxIp = ip;
  }

  Future<bool> testConnection() async {
    if (_boxIp.isEmpty) return false;

    try {
      final response = await http
          .get(Uri.parse('http://$_boxIp/api/status'))
          .timeout(const Duration(seconds: 5));

      _isConnected = response.statusCode == 200;
      return _isConnected;
    } catch (e) {
      _isConnected = false;
      return false;
    }
  }

  Future<Map<String, dynamic>?> getBoxStatus() async {
    if (_boxIp.isEmpty || !_isConnected) return null;

    try {
      final response = await http
          .get(Uri.parse('http://$_boxIp/api/status'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      _isConnected = false;
      return null;
    }
  }

  Future<bool> syncSchedule(List<MedicineSchedule> schedules) async {
    if (_boxIp.isEmpty) return false;

    try {
      final payload = {
        'schedules': schedules.map((s) => s.toEsp32Json()).toList(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      final response = await http
          .post(
            Uri.parse('http://$_boxIp/api/schedule'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _lastSync = DateTime.now();
        return true;
      }
      return false;
    } catch (e) {
      _isConnected = false;
      return false;
    }
  }

  Future<bool> markDoseAsTaken(String compartment) async {
    if (_boxIp.isEmpty || !_isConnected) return false;

    try {
      final response = await http
          .post(
            Uri.parse('http://$_boxIp/api/dose-taken'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'compartment': compartment}),
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> openCompartment(String compartment) async {
    if (_boxIp.isEmpty || !_isConnected) return false;

    try {
      final response = await http
          .post(
            Uri.parse('http://$_boxIp/api/open'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'compartment': compartment}),
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> resetBox() async {
    if (_boxIp.isEmpty || !_isConnected) return false;

    try {
      final response = await http
          .post(Uri.parse('http://$_boxIp/api/reset'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _lastSync = null;
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  String generateEsp32ArduinoCode(List<MedicineSchedule> schedules, String boxId) {
    return '''
#include <WiFi.h>
#include <WebServer.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>

const char* box_id = "$boxId";
const char* mqtt_server = "broker.hivemq.com";

WiFiClient espClient;
PubSubClient client(espClient);
WebServer setupServer(80);

struct Schedule {
  String compartment;
  String time;
  String medicine;
  String dosage;
  bool active;
};

Schedule schedules[10];
int scheduleCount = 0;

void callback(char* topic, byte* payload, unsigned int length) {
  String message;
  for (int i = 0; i < length; i++) message += (char)payload[i];

  DynamicJsonDocument doc(1024);
  deserializeJson(doc, message);

  String command = doc["command"];
  if (command == "add_schedule") {
    if (scheduleCount < 10) {
      JsonObject data = doc["data"];
      schedules[scheduleCount].compartment = data["compartment"].as<String>();
      schedules[scheduleCount].time = data["scheduled_time"].as<String>();
      schedules[scheduleCount].medicine = data["medicine_name"].as<String>();
      schedules[scheduleCount].dosage = data["dosage"].as<String>();
      schedules[scheduleCount].active = data["active"] | true;
      scheduleCount++;
      Serial.println("New schedule added remotely");
    }
  } else if (command == "open") {
    String comp = doc["data"]["compartment"];
    Serial.println("Opening compartment: " + comp);
    // Add GPIO trigger logic here
  } else if (command == "dose_taken") {
    String comp = doc["data"]["compartment"];
    Serial.println("Dose marked as taken: " + comp);
  }
}

void reconnect() {
  while (!client.connected()) {
    if (client.connect("CareCubeBox")) {
      client.subscribe(("care_cube/" + String(box_id) + "/commands").c_str());
    } else {
      delay(5000);
    }
  }
}

void publishStatus() {
  // Replace with real VL53L0X sensor readings (mm). -1 = no reading.
  int sensor1_distance = -1;
  int sensor2_distance = -1;
  bool compartment1_present = sensor1_distance >= 0 && sensor1_distance <= 70;
  bool compartment2_present = sensor2_distance >= 0 && sensor2_distance <= 70;

  DynamicJsonDocument statusDoc(256);
  statusDoc["box_id"] = box_id;
  statusDoc["sensor1_distance"] = sensor1_distance;
  statusDoc["sensor2_distance"] = sensor2_distance;
  statusDoc["compartment1_present"] = compartment1_present;
  statusDoc["compartment2_present"] = compartment2_present;
  statusDoc["medicine_count"] = (compartment1_present ? 1 : 0) + (compartment2_present ? 1 : 0);
  statusDoc["total_compartments"] = 2;
  String statusJson;
  serializeJson(statusDoc, statusJson);
  client.publish(("care_cube/" + String(box_id) + "/status").c_str(), statusJson.c_str());
}

void setup() {
  Serial.begin(115200);
  WiFi.begin();

  if (WiFi.status() != WL_CONNECTED) {
    WiFi.softAP("CareCube_Setup");
    setupServer.on("/setup", HTTP_POST, []() {
      DynamicJsonDocument doc(512);
      deserializeJson(doc, setupServer.arg("plain"));
      WiFi.begin(doc["ssid"], doc["pass"]);
      setupServer.send(200, "text/plain", "OK");
      delay(2000);
      ESP.restart();
    });
    setupServer.begin();
  }

  client.setServer(mqtt_server, 1883);
  client.setCallback(callback);
}

void loop() {
  if (WiFi.status() == WL_CONNECTED) {
    if (!client.connected()) reconnect();
    client.loop();

    static unsigned long lastStatus = 0;
    if (millis() - lastStatus > 3000) {
      lastStatus = millis();
      publishStatus();
    }
  } else {
    setupServer.handleClient();
  }
}
''';
  }
}
