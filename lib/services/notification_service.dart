import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(initializationSettings);

    // Request permissions for Android 13+
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.requestNotificationsPermission();
      
      // Specifically for exact alarms on Android 12+
      await _requestExactAlarmPermission();
    }
  }

  Future<void> _requestExactAlarmPermission() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      
      // requestExactAlarmsPermission was added in newer versions of the plugin
      // If it doesn't exist, we skip or use a manual intent (but this is usually enough)
      try {
        await androidImplementation?.requestExactAlarmsPermission();
      } catch (e) {
        print("Exact alarm permission request error: $e");
      }
    }
  }

  Future<void> scheduleMedicineAlarm(String id, String medicineName, String timeStr) async {
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

    final prefs = await SharedPreferences.getInstance();
    final soundType = prefs.getString('alarm_sound') ?? 'alarm';
    
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'medicine_alarms',
      'Medicine Alarms',
      channelDescription: 'Alarms for medicine reminders',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      category: soundType == 'alarm' ? AndroidNotificationCategory.alarm : AndroidNotificationCategory.reminder,
      fullScreenIntent: true,
    );

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

  Future<void> cancelAlarm(String id) async {
    await _notificationsPlugin.cancel(id.hashCode);
  }
}
