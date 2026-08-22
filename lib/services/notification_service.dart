import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'mqtt_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        if (response.actionId == 'stop_alarm') {
          // Stop the notification sound by canceling it
          if (response.id != null) {
            await _notificationsPlugin.cancel(response.id!);
          }
        }
      },
    );

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.requestNotificationsPermission();
      await _requestExactAlarmPermission();
    }

    _listenToMqtt();
    _isInitialized = true;
  }

  void _listenToMqtt() {
    final mqttService = MqttService();

    // Listen to raw messages (REMINDER, CONFIRMED, etc.)
    mqttService.messageStream.listen((message) {
      if (message.contains('REMINDER')) {
        showInstantNotification('Medicine Reminder', message);
      } else if (message.contains('CONFIRMED')) {
        showInstantNotification('Dose Confirmed', message);
      } else if (message.contains('CARE CUBE') || message.contains('SCHEDULE')) {
        showInstantNotification('Care Cube', message);
      }
    });

    // Listen to status updates for temperature/humidity alerts
    mqttService.statusStream.listen((data) async {
      final prefs = await SharedPreferences.getInstance();
      final storageAlertsEnabled = prefs.getBool('storageAlerts') ?? true;
      if (!storageAlertsEnabled) return;

      final temp = data['temperature'];
      final hum = data['humidity'];

      if (temp is num && temp > 35) {
        showInstantNotification('Storage Alert', 'Temperature is high: ${temp.toStringAsFixed(1)}°C. Check medicine storage conditions.');
      }
      if (hum is num && hum > 70) {
        showInstantNotification('Storage Alert', 'Humidity is high: ${hum.toStringAsFixed(0)}%. Check medicine storage conditions.');
      }
    });
  }

  Future<void> showInstantNotification(String title, String body) async {
    final prefs = await SharedPreferences.getInstance();
    final soundType = prefs.getString('alarm_sound') ?? 'alarm';
    final customSoundUri = prefs.getString('alarm_sound_uri');
    final vibrationEnabled = prefs.getBool('vibration') ?? true;

    AndroidNotificationDetails androidDetails;
    
    if (customSoundUri != null && customSoundUri.isNotEmpty) {
      androidDetails = AndroidNotificationDetails(
        'mqtt_alerts_custom_${customSoundUri.hashCode}',
        'Care Cube MQTT Alerts',
        channelDescription: 'Alerts received from the smart medicine box',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: UriAndroidNotificationSound(customSoundUri),
        enableVibration: vibrationEnabled,
      );
    } else {
      androidDetails = AndroidNotificationDetails(
        'mqtt_alerts_$soundType',
        'Care Cube MQTT Alerts',
        channelDescription: 'Alerts received from the smart medicine box',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: vibrationEnabled,
        category: soundType == 'alarm' ? AndroidNotificationCategory.alarm : AndroidNotificationCategory.reminder,
      );
    }

    final NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      DateTime.now().millisecond,
      title,
      body,
      platformDetails,
    );
  }

  Future<void> _requestExactAlarmPermission() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      try {
        await androidImplementation?.requestExactAlarmsPermission();
      } catch (e) {
        print("Exact alarm permission request error: $e");
      }
    }
  }

  Future<void> scheduleMedicineAlarm(String id, String medicineName, String timeStr) async {
    final prefs = await SharedPreferences.getInstance();
    final doseRemindersEnabled = prefs.getBool('doseReminders') ?? true;
    
    if (!doseRemindersEnabled) return;

    DateTime now = DateTime.now();
    DateTime scheduledTime;
    
    try {
      final format = DateFormat.jm();
      final time = format.parse(timeStr);
      scheduledTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    } catch (e) {
      try {
        final time = DateFormat("HH:mm").parse(timeStr);
        scheduledTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);
      } catch (e2) {
        return;
      }
    }

    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    final soundType = prefs.getString('alarm_sound') ?? 'alarm';
    final customSoundUri = prefs.getString('alarm_sound_uri');
    final vibrationEnabled = prefs.getBool('vibration') ?? true;
    
    AndroidNotificationDetails androidDetails;
    
    if (customSoundUri != null && customSoundUri.isNotEmpty) {
      final channelId = 'medicine_alarms_custom_${customSoundUri.hashCode}';
      
      androidDetails = AndroidNotificationDetails(
        channelId,
        'Medicine Alarms',
        channelDescription: 'Alarms for medicine reminders',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: UriAndroidNotificationSound(customSoundUri),
        enableVibration: vibrationEnabled,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        additionalFlags: Int32List.fromList([4]),
        actions: <AndroidNotificationAction>[
          const AndroidNotificationAction(
            'stop_alarm',
            'Stop Alarm',
            showsUserInterface: true,
            cancelNotification: true,
          ),
        ],
      );
    } else {
      androidDetails = AndroidNotificationDetails(
        'medicine_alarms_$soundType',
        'Medicine Alarms',
        channelDescription: 'Alarms for medicine reminders',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: vibrationEnabled,
        category: soundType == 'alarm' ? AndroidNotificationCategory.alarm : AndroidNotificationCategory.reminder,
        fullScreenIntent: true,
        additionalFlags: Int32List.fromList([4]),
        actions: <AndroidNotificationAction>[
          const AndroidNotificationAction(
            'stop_alarm',
            'Stop Alarm',
            showsUserInterface: true,
            cancelNotification: true,
          ),
        ],
      );
    }

    final NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.zonedSchedule(
      id.hashCode,
      'Time for Medicine!',
      'It\'s time to take your $medicineName',
      tz.TZDateTime.from(scheduledTime, tz.local),
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> previewSound(String uri) async {
    final channelId = 'preview_channel_${uri.hashCode}';
    
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      'Sound Preview',
      channelDescription: 'Previewing alarm sounds',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: UriAndroidNotificationSound(uri),
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );

    final NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      999,
      'Care Cube Sound Preview',
      'This is how your medicine reminder will sound.',
      platformDetails,
    );
  }

  Future<void> stopPreview() async {
    await _notificationsPlugin.cancel(999);
  }

  Future<void> showTestNotification(String soundType) async {
    final prefs = await SharedPreferences.getInstance();
    final customSoundUri = prefs.getString('alarm_sound_uri');
    final vibrationEnabled = prefs.getBool('vibration') ?? true;

    AndroidNotificationDetails androidDetails;
    
    if (customSoundUri != null && customSoundUri.isNotEmpty) {
      final channelId = 'medicine_alarms_preview_${customSoundUri.hashCode}';
      androidDetails = AndroidNotificationDetails(
        channelId,
        'Medicine Alarms',
        channelDescription: 'Alarms for medicine reminders',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: UriAndroidNotificationSound(customSoundUri),
        enableVibration: vibrationEnabled,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      );
    } else {
      androidDetails = AndroidNotificationDetails(
        'medicine_alarms_$soundType',
        'Medicine Alarms',
        channelDescription: 'Alarms for medicine reminders',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: vibrationEnabled,
        category: soundType == 'alarm' ? AndroidNotificationCategory.alarm : AndroidNotificationCategory.reminder,
      );
    }

    final NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      999,
      'Sound Preview',
      'This is how your alert will sound.',
      platformDetails,
    );
  }

  Future<void> cancelAlarm(String id) async {
    await _notificationsPlugin.cancel(id.hashCode);
  }

  Future<void> cancelAllAlarms() async {
    await _notificationsPlugin.cancelAll();
  }
}
