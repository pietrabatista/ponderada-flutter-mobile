import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _issNotifId = 1;
  static const _apodNotifId = 2;
  static const _testNotifId = 99;
  static const _issProximityNotifId = 3;

  // Coordenadas de São Paulo
  static const _spLat = -23.5505;
  static const _spLon = -46.6333;
  static const _proximityRadiusKm = 100.0;
  static const _proximityCooldown = Duration(minutes: 10);
  static DateTime? _lastProximityNotif;

  static const _issChannelId = 'iss_channel';
  static const _apodChannelId = 'apod_channel';

  static const _prefIss = 'notif_iss_enabled';
  static const _prefApod = 'notif_apod_enabled';

  // ─── Inicialização ──────────────────────────────────────────────────────────

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
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  // ─── Preferências ───────────────────────────────────────────────────────────

  static Future<bool> isIssEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefIss) ?? true;
  }

  static Future<bool> isApodEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefApod) ?? true;
  }

  static Future<void> setIssEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefIss, value);
    if (!value) await cancelIss();
  }

  static Future<void> setApodEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefApod, value);
    if (value) {
      await scheduleApodDaily();
    } else {
      await cancelApod();
    }
  }

  // ─── ISS ────────────────────────────────────────────────────────────────────

  /// Agenda notificação para a próxima passagem da ISS (5 min antes).
  static Future<void> scheduleIssPass(DateTime passTime) async {
    await initialize();

    final enabled = await isIssEnabled();
    if (!enabled) return;

    await _plugin.cancel(_issNotifId);

    final now = DateTime.now();
    final diff = passTime.difference(now);
    if (diff.isNegative || diff.inSeconds < 30) return;

    final notifyAt = diff.inMinutes > 5
        ? passTime.subtract(const Duration(minutes: 5))
        : passTime;

    final minUntilPass = passTime.difference(notifyAt).inMinutes;
    final timeStr =
        '${passTime.hour.toString().padLeft(2, '0')}:${passTime.minute.toString().padLeft(2, '0')}';

    final body = minUntilPass > 0
        ? 'A ISS passa às $timeStr (em ${minUntilPass}min). Olhe para o céu! 🔭'
        : 'A ISS está passando agora às $timeStr! Olhe para o céu! 🔭';

    await _plugin.zonedSchedule(
      _issNotifId,
      '🛸 ISS passando em breve!',
      body,
      tz.TZDateTime.from(notifyAt, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _issChannelId,
          'Passagem da ISS',
          channelDescription: 'Notificações de passagem da ISS',
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

  static Future<void> cancelIss() async {
    await initialize();
    await _plugin.cancel(_issNotifId);
  }

  // ─── APOD ───────────────────────────────────────────────────────────────────

  /// Agenda notificação diária às 9h avisando sobre a foto do dia.
  static Future<void> scheduleApodDaily() async {
    await initialize();

    final enabled = await isApodEnabled();
    if (!enabled) return;

    await _plugin.cancel(_apodNotifId);

    // Próximo horário 9h
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 9);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _apodNotifId,
      '🌌 Foto Astronômica do Dia',
      'A imagem de hoje do universo está disponível. Vem ver! ✨',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _apodChannelId,
          'APOD Diário',
          channelDescription: 'Notificação diária da Foto Astronômica do Dia',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancelApod() async {
    await initialize();
    await _plugin.cancel(_apodNotifId);
  }

  // ─── Proximidade ISS / São Paulo ────────────────────────────────────────────

  /// Verifica se a ISS está a ≤100 km de São Paulo e dispara notificação
  /// (máx uma a cada 10 minutos para não spammar).
  static Future<void> checkIssProximity(double issLat, double issLon) async {
    final distKm = _haversineKm(issLat, issLon, _spLat, _spLon);
    if (distKm > _proximityRadiusKm) return;

    final now = DateTime.now();
    if (_lastProximityNotif != null &&
        now.difference(_lastProximityNotif!) < _proximityCooldown) {
      return;
    }
    _lastProximityNotif = now;

    await initialize();
    await _plugin.show(
      _issProximityNotifId,
      '🛸 ISS sobre São Paulo!',
      'A Estação Espacial Internacional está a ${distKm.toStringAsFixed(0)} km de São Paulo. Olhe para o céu! 🔭',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _issChannelId,
          'Passagem da ISS',
          channelDescription: 'Notificações de passagem da ISS',
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
    );
  }

  static double _haversineKm(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _toRad(double deg) => deg * pi / 180;

  // ─── Teste ──────────────────────────────────────────────────────────────────

  static Future<void> sendTest() async {
    await initialize();
    await _plugin.show(
      _testNotifId,
      '🔔 Notificação de teste',
      'SkySight está funcionando corretamente! 🌟',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_channel',
          'Teste',
          channelDescription: 'Canal de teste de notificações',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: true,
        ),
      ),
    );
  }
}
