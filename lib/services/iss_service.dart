import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

/// Entrada de log do fluxo ISS para exibição visual.
class IssLogEntry {
  final String step;
  final String detail;
  final bool ok;
  final Duration? elapsed;

  const IssLogEntry({
    required this.step,
    required this.detail,
    required this.ok,
    this.elapsed,
  });

  @override
  String toString() =>
      '[ISS] ${ok ? "✓" : "✗"} $step${elapsed != null ? " (${elapsed!.inMilliseconds}ms)" : ""}: $detail';
}

class IssPassTime {
  final DateTime? time;
  final String? currentLat;
  final String? currentLon;
  final bool isFallback;
  final List<IssLogEntry> logs;

  const IssPassTime({
    this.time,
    this.currentLat,
    this.currentLon,
    this.isFallback = false,
    this.logs = const [],
  });

  String get countdown {
    if (time == null) return '';
    final diff = time!.difference(DateTime.now());
    if (diff.isNegative) return 'Passou recentemente';
    if (diff.inSeconds < 60) return 'Passando agora!';
    if (diff.inMinutes < 60) return 'Em ${diff.inMinutes} min';
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    return 'Em ${h}h ${m.toString().padLeft(2, '0')}min';
  }

  String get label {
    if (isFallback && currentLat != null) {
      return 'Posição atual: $currentLat°, $currentLon°\n(horário de passagem indisponível)';
    }
    if (time == null) return 'Serviço temporariamente indisponível';
    final timeStr =
        '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}';
    return 'Próxima passagem às $timeStr';
  }
}

class IssService {
  // API de posição atual — open-notify (rápida, ~400ms)
  static const _nowApi = 'http://api.open-notify.org/iss-now.json';
  // Fallback de posição — wheretheiss.at (lenta ~12s)
  static const _positionApi = 'https://api.wheretheiss.at/v1/satellites/25544';

  static const _timeout = Duration(seconds: 20);

  static Future<IssPassTime> nextPass() async {
    final logs = <IssLogEntry>[];

    void log(IssLogEntry entry) {
      logs.add(entry);
      debugPrint(entry.toString());
    }

    debugPrint('[ISS] === Iniciando busca de passagem da ISS ===');

    // 1. Localização
    final t0 = DateTime.now();
    Position position;
    try {
      position = await _getPosition();
      final elapsed = DateTime.now().difference(t0);
      log(IssLogEntry(
        step: 'GPS',
        detail: 'lat=${position.latitude.toStringAsFixed(4)}, lon=${position.longitude.toStringAsFixed(4)}',
        ok: true,
        elapsed: elapsed,
      ));
    } catch (e) {
      log(IssLogEntry(step: 'GPS', detail: e.toString(), ok: false));
      throw Exception('Permissão de localização negada ou GPS desativado.');
    }

    // 2. Posição atual via open-notify/iss-now.json (rápida, ~400ms)
    final t1 = DateTime.now();
    try {
      final uri = Uri.parse(_nowApi);
      debugPrint('[ISS] → GET $uri');
      final response = await http.get(uri).timeout(_timeout);
      final elapsed = DateTime.now().difference(t1);
      debugPrint('[ISS] ← HTTP ${response.statusCode} (${elapsed.inMilliseconds}ms) body: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        if (json['message'] == 'success') {
          final pos = json['iss_position'] as Map<String, dynamic>;
          final lat = double.parse(pos['latitude'] as String).toStringAsFixed(2);
          final lon = double.parse(pos['longitude'] as String).toStringAsFixed(2);
          log(IssLogEntry(
            step: 'open-notify/iss-now',
            detail: 'Posição atual: lat=$lat, lon=$lon',
            ok: true,
            elapsed: elapsed,
          ));
          return IssPassTime(
            isFallback: true,
            currentLat: lat,
            currentLon: lon,
            logs: List.unmodifiable(logs),
          );
        } else {
          log(IssLogEntry(step: 'open-notify/iss-now', detail: 'message=${json["message"]}', ok: false, elapsed: elapsed));
        }
      } else {
        log(IssLogEntry(
          step: 'open-notify/iss-now',
          detail: 'HTTP ${response.statusCode}',
          ok: false,
          elapsed: elapsed,
        ));
      }
    } catch (e) {
      final elapsed = DateTime.now().difference(t1);
      log(IssLogEntry(step: 'open-notify/iss-now', detail: '${e.runtimeType}: $e', ok: false, elapsed: elapsed));
    }

    // 3. Fallback: posição atual via wheretheiss.at
    final t2 = DateTime.now();
    try {
      final uri = Uri.parse(_positionApi);
      debugPrint('[ISS] → GET $uri (timeout: ${_timeout.inSeconds}s)');
      final response = await http.get(uri).timeout(_timeout);
      final elapsed = DateTime.now().difference(t2);
      debugPrint('[ISS] ← HTTP ${response.statusCode} (${elapsed.inMilliseconds}ms) body: ${response.body.substring(0, response.body.length.clamp(0, 200))}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final lat = (json['latitude'] as num).toDouble().toStringAsFixed(2);
        final lon = (json['longitude'] as num).toDouble().toStringAsFixed(2);
        log(IssLogEntry(
          step: 'wheretheiss.at',
          detail: 'Posição atual: lat=$lat, lon=$lon',
          ok: true,
          elapsed: elapsed,
        ));
        return IssPassTime(
          isFallback: true,
          currentLat: lat,
          currentLon: lon,
          logs: List.unmodifiable(logs),
        );
      } else {
        log(IssLogEntry(
          step: 'wheretheiss.at',
          detail: 'HTTP ${response.statusCode}',
          ok: false,
          elapsed: elapsed,
        ));
      }
    } on TimeoutException catch (e) {
      final elapsed = DateTime.now().difference(t2);
      log(IssLogEntry(step: 'wheretheiss.at', detail: 'Timeout após ${elapsed.inSeconds}s: $e', ok: false, elapsed: elapsed));
    } on SocketException catch (e) {
      log(IssLogEntry(step: 'wheretheiss.at', detail: 'Sem internet: $e', ok: false));
      throw Exception('Sem conexão com a internet.');
    } catch (e) {
      final elapsed = DateTime.now().difference(t2);
      log(IssLogEntry(step: 'wheretheiss.at', detail: '${e.runtimeType}: $e', ok: false, elapsed: elapsed));
    }

    debugPrint('[ISS] === Todas as APIs falharam ===');
    throw IssException(
      'Serviço de rastreamento da ISS temporariamente indisponível.',
      logs: List.unmodifiable(logs),
    );
  }

  static Future<Position> _getPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('GPS desativado');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Permissão de localização negada');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
    );
  }
}

/// Exceção com logs do fluxo ISS para exibição visual na UI.
class IssException implements Exception {
  final String message;
  final List<IssLogEntry> logs;
  const IssException(this.message, {required this.logs});

  @override
  String toString() => message;
}
