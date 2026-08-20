import 'dart:async';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  static final MqttService _instance = MqttService._internal();
  factory MqttService() => _instance;
  MqttService._internal();

  final String broker = 'broker.hivemq.com';
  final int port = 1883;
  late MqttServerClient client;

  final _statusController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get statusStream => _statusController.stream;

  final _messageController = StreamController<String>.broadcast();
  Stream<String> get messageStream => _messageController.stream;

  final _alertController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get alertStream => _alertController.stream;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  String? _boxId;

  Future<bool> connect(String boxId) async {
    if (_isConnected && _boxId == boxId) return true;

    _boxId = boxId;
    final String clientId = 'care_cube_app_${DateTime.now().millisecondsSinceEpoch}';
    client = MqttServerClient(broker, clientId);
    client.port = port;
    client.keepAlivePeriod = 20;
    client.onDisconnected = onDisconnected;
    client.onConnected = onConnected;
    client.logging(on: false);

    final connMess = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    client.connectionMessage = connMess;

    try {
      await client.connect();
    } catch (e) {
      print('MQTT Exception: $e');
      client.disconnect();
      return false;
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      print('MQTT Connected');
      _isConnected = true;
      _subscribeToTopics();
      return true;
    } else {
      print('MQTT Connection failed: ${client.connectionStatus}');
      client.disconnect();
      return false;
    }
  }

  void _subscribeToTopics() {
    if (_boxId == null) return;

    final statusTopic = 'care_cube/$_boxId/status';
    final legacyTopic = 'medicinebox/notifications';

    client.subscribe(statusTopic, MqttQos.atLeastOnce);
    client.subscribe(legacyTopic, MqttQos.atLeastOnce);

    client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      final MqttPublishMessage recMess = c![0].payload as MqttPublishMessage;
      final pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

      print('MQTT Message on ${c[0].topic}: $pt');

      if (c[0].topic == statusTopic) {
        try {
          final data = jsonDecode(pt) as Map<String, dynamic>;
          _statusController.add(data);
        } catch (e) {
          _messageController.add(pt);
        }
      } else if (c[0].topic == legacyTopic) {
        _handleAlertMessage(pt);
      }
    });
  }

  void _handleAlertMessage(String message) {
    _messageController.add(message);

    String type = 'info';
    String title = 'Care Cube';
    String body = message;

    if (message.contains('REMINDER')) {
      type = 'reminder';
      title = 'Medicine Reminder';
      body = message.replaceFirst('REMINDER: ', '');
    } else if (message.contains('CONFIRMED')) {
      type = 'confirmed';
      title = 'Dose Confirmed';
      body = message.replaceFirst('CONFIRMED: ', '');
    } else if (message.contains('Online') || message.contains('OFFLINE')) {
      type = 'status';
      title = 'Box Status';
    }

    _alertController.add({
      'type': type,
      'title': title,
      'body': body,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void publishCommand(String command, Map<String, dynamic> data) {
    if (!_isConnected || _boxId == null) return;

    final topic = 'care_cube/$_boxId/commands';
    final payload = jsonEncode({
      'command': command,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });

    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  void publishScheduleToBox(int sensor, int hour, int minute) {
    if (!_isConnected || _boxId == null) return;

    final topic = 'care_cube/$_boxId/commands';
    final payload = jsonEncode({
      'command': 'set_schedule',
      'sensor': sensor,
      'hour': hour,
      'minute': minute,
    });

    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    print('Published schedule to box: sensor=$sensor, $hour:${minute.toString().padLeft(2, '0')}');
  }

  void onConnected() {
    print('MQTT Connection established');
    _isConnected = true;
  }

  void onDisconnected() {
    print('MQTT Disconnected');
    _isConnected = false;
  }

  void disconnect() {
    client.disconnect();
    _isConnected = false;
  }
}
