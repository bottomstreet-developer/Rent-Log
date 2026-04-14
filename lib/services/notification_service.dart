import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static const String _channelId = 'rentlog_reminders';
  static const String _channelName = 'RentLog Reminders';
  static const String _channelDescription =
      'Rent due and lease renewal reminders';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static Future<void> init() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      if (_initialized) return;
      tzdata.initializeTimeZones();

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const settings = InitializationSettings(android: android, iOS: ios);

      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (NotificationResponse r) {},
      );

      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService.init error: $e');
    }
  }

  static Future<void> requestPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      if (Platform.isIOS) {
        await _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      }
    } catch (_) {}
  }

  static Future<void> scheduleMonthlyRentReminder({
    required int dayOfMonth,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDay =
          prefs.getInt('rent_reminder_day') ?? prefs.getInt('dueDay') ?? 5;
      final now = tz.TZDateTime.now(tz.local);
      var scheduled =
          tz.TZDateTime(tz.local, now.year, now.month, savedDay, 9);
      if (scheduled.isBefore(now)) {
        scheduled =
            tz.TZDateTime(tz.local, now.year, now.month + 1, savedDay, 9);
      }
      await _plugin.zonedSchedule(
        id: 1001,
        title: 'Rent reminder',
        body: 'Your rent is due soon. Log your payment in RentLog.',
        scheduledDate: scheduled,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
      );
    } catch (_) {}
  }

  static Future<void> scheduleLeaseRenewalReminders({
    required DateTime leaseEndDate,
    required List<int> daysBefore,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDays = prefs.getInt('lease_reminder_days') ??
          prefs.getInt('leaseReminderDays') ??
          60;
      final when = leaseEndDate.subtract(Duration(days: savedDays));
      if (when.isBefore(DateTime.now())) return;
      final tzWhen = tz.TZDateTime.from(when, tz.local);
      await _plugin.zonedSchedule(
        id: 2000 + savedDays,
        title: 'Lease renewal reminder',
        body: 'Your lease ends in $savedDays days. Plan your renewal now.',
        scheduledDate: tzWhen,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {}
  }

  static Future<void> cancelAllReminders() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      await _plugin.cancelAll();
      debugPrint('RentLog reminders cleared');
    } catch (_) {}
  }

  static Future<void> scheduleTestRentReminder({required int days}) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      final scheduled =
          tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5));
      await _plugin.zonedSchedule(
        id: DateTime.now().millisecondsSinceEpoch.remainder(1000000),
        title: 'Rent Due Soon',
        body: 'Your rent payment is due in $days days',
        scheduledDate: scheduled,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {}
  }

  static Future<void> scheduleTestLeaseReminder({required int days}) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      final scheduled =
          tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5));
      await _plugin.zonedSchedule(
        id: DateTime.now().millisecondsSinceEpoch.remainder(1000000) + 1,
        title: 'Lease Expiring Soon',
        body: 'Your lease expires in $days days',
        scheduledDate: scheduled,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {}
  }
}
