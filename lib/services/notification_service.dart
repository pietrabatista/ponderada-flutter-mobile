import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _issChannelId = 'iss_channel';
  static const _issNotifId = 1;

  static Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    // Pede permissão no Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  /// Agenda notificação para a próxima passagem da ISS.
  /// Notifica 5 min antes (ou imediatamente se < 5 min).
  static Future<void> scheduleIssPass(DateTime passTime) async {
    await initialize();

    // Cancela notificação anterior de ISS
    await _plugin.cancel(_issNotifId);

    final now = DateTime.now();
    final diff = passTime.difference(now);
    if (diff.isNegative || diff.inSeconds < 30) return;

    // Notificar 5 min antes, ou na hora se menos de 5 min
    final notifyAt = diff.inMinutes > 5
        ? passTime.subtract(const Duration(minutes: 5))
        : passTime;

    final minUntilPass = passTime.difference(notifyAt).inMinutes;
    final timeStr =
        '${passTime.hour.toString().padLeft(2, '0')}:${passTime.minute.toString().padLeft(2, '0')}';

    final body = minUntilPass > 0
        ? 'A ISS passa às $timeStr (em ${minUntilPass}min). Olhe para o céu! 🔭'
        : 'A ISS está passando agora às $timeStr! Olhe para o céu! 🔭';

    final tzNotifyAt = tz.TZDateTime.from(notifyAt, tz.local);

    await _plugin.zonedSchedule(
      _issNotifId,
      '🛸 ISS passando em breve!',
      body,
      tzNotifyAt,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _issChannelId,
          'Passagem da ISS',
          channelDescription:
              'Notificações de passagem da Estação Espacial Internacional',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
