import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../models/assignment_model.dart';
import '../utils/app_time.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> init() async {
    if (!Platform.isAndroid) return;
    if (_isInitialized) return;

    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);

    _isInitialized = true;
    
    // Request permissions asynchronously after a delay so we don't block runApp()
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Future.delayed(const Duration(seconds: 2));
    
    final androidImpl = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
            
    if (androidImpl != null) {
      await androidImpl.requestNotificationsPermission();
      await androidImpl.requestExactAlarmsPermission();
    }
  }

  Future<void> scheduleAssignmentReminder(Assignment assignment) async {
    if (!Platform.isAndroid || !_isInitialized) return;
    if (assignment.isDone) return;

    // We want 5:00 PM the day BEFORE the due date.
    final due = assignment.dueDate;
    final targetDate = DateTime(due.year, due.month, due.day)
        .subtract(const Duration(days: 1))
        .add(const Duration(hours: 17));

    // If it was created after the target time (e.g. after 5 PM day before, or on the due date)
    if (assignment.createdAt.isAfter(targetDate)) {
      return;
    }

    // If the target time is already in the past compared to right now
    if (targetDate.isBefore(AppTime.now())) {
      return;
    }

    final scheduledDate = tz.TZDateTime.from(targetDate, tz.local);

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'assignment_reminders',
      'Assignment Reminders',
      channelDescription: 'Reminders for upcoming assignments',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      color: Color(0xFF8B0000), // Scopus primary crimson color
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    try {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        assignment.id.hashCode & 0x7FFFFFFF,
        'Assignment Due Soon',
        '${assignment.title} is due today, Hurry!',
        scheduledDate,
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Failed to schedule notification (likely Exact Alarm permission denied): $e');
    }
  }

  Future<void> cancelReminder(String assignmentId) async {
    if (!Platform.isAndroid || !_isInitialized) return;
    await _flutterLocalNotificationsPlugin.cancel(assignmentId.hashCode & 0x7FFFFFFF);
  }
}
