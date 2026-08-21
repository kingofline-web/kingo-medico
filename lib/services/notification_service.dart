import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Rome'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);

    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
  }

  Future<void> scheduleAppointmentReminder({
    required int id,
    required String title,
    required DateTime appointment,
  }) async {
    final reminder = DateTime(
      appointment.year,
      appointment.month,
      appointment.day - 1,
      9,
      0,
    );

    if (reminder.isBefore(DateTime.now())) return;

    await _plugin.zonedSchedule(
      id,
      'Visita domani',
      '$title è programmata per domani.',
      tz.TZDateTime.from(reminder, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'kingo_visits',
          'Visite e appuntamenti',
          channelDescription: 'Promemoria delle visite programmate',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> scheduleDailyMedicine({
    required int id,
    required String medicine,
    required int hour,
    required int minute,
  }) async {
    var scheduled = tz.TZDateTime(
      tz.local,
      tz.TZDateTime.now(tz.local).year,
      tz.TZDateTime.now(tz.local).month,
      tz.TZDateTime.now(tz.local).day,
      hour,
      minute,
    );

    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id,
      'È ora di prendere il farmaco',
      medicine,
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'kingo_medicines',
          'Promemoria farmaci',
          channelDescription: 'Avvisi giornalieri per i farmaci',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('kingo_medicine'),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }
}
