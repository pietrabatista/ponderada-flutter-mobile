import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class IssPassTime {
  final DateTime? time;
  final String? currentLat;
  final String? currentLon;
  final bool isFallback;

  const IssPassTime({
    this.time,
    this.currentLat,
    this.currentLon,
    this.isFallback = false,
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

  String get coordsLabel {
    if (currentLat != null) return '$currentLat°, $currentLon°';
    if (time != null) {
      final t =
          '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}';
      return 'Próxima passagem às $t';
    }
    return 'Serviço temporariamente indisponível';
  }
}

class IssService {
  static const _nowApi = 'http://api.open-notify.org/iss-now.json';
  static const _positionApi = 'https://api.wheretheiss.at/v1/satellites/25544';
  static const _timeout = Duration(seconds: 20);

  // Cache de GPS para não chamar o hardware a cada 5s
  static Position? _cachedPosition;
  static DateTime? _positionCacheTime;
  static const _positionCacheDuration = Duration(minutes: 2);

  // Override de depuração: força posição de SP por N segundos
  static DateTime? _forcedSpUntil;

  /// Força a posição da ISS para São Paulo durante [duration].
  static void forceSpLocation({Duration duration = const Duration(seconds: 10)}) {
    _forcedSpUntil = DateTime.now().add(duration);
    debugPrint('[ISS] 🛠 Override SP ativado por ${duration.inSeconds}s');
  }

  static Future<IssPassTime> nextPass() async {
    // Override de debug: retorna coords de SP sem chamar a API
    if (_forcedSpUntil != null && DateTime.now().isBefore(_forcedSpUntil!)) {
      debugPrint('[ISS] 🛠 Override SP ativo — retornando lat=-23.55 lon=-46.63');
      return const IssPassTime(
        isFallback: true,
        currentLat: '-23.55',
        currentLon: '-46.63',
      );
    }
    debugPrint('[ISS] === Buscando posição ===');

    // 1. GPS (cacheado 2 min)
    Position position;
    try {
      position = await _getPosition();
      debugPrint('[ISS] GPS: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}');
    } catch (e) {
      debugPrint('[ISS] GPS falhou: $e');
      throw Exception('Permissão de localização negada ou GPS desativado.');
    }

    // 2. open-notify/iss-now.json (~400ms)
    final t1 = DateTime.now();
    try {
      final uri = Uri.parse(_nowApi);
      debugPrint('[ISS] → GET $uri');
      final response = await http.get(uri).timeout(_timeout);
      final ms = DateTime.now().difference(t1).inMilliseconds;
      debugPrint('[ISS] ← HTTP ${response.statusCode} (${ms}ms) ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        if (json['message'] == 'success') {
          final pos = json['iss_position'] as Map<String, dynamic>;
          final lat =
              double.parse(pos['latitude'] as String).toStringAsFixed(2);
          final lon =
              double.parse(pos['longitude'] as String).toStringAsFixed(2);
          debugPrint('[ISS] ✓ open-notify: lat=$lat lon=$lon');
          return IssPassTime(
              isFallback: true, currentLat: lat, currentLon: lon);
        }
      }
      debugPrint('[ISS] ✗ open-notify HTTP ${response.statusCode}');
    } catch (e) {
      debugPrint('[ISS] ✗ open-notify ${e.runtimeType}: $e');
    }

    // 3. Fallback: wheretheiss.at (~12s)
    final t2 = DateTime.now();
    try {
      final uri = Uri.parse(_positionApi);
      debugPrint('[ISS] → GET $uri (fallback, timeout ${_timeout.inSeconds}s)');
      final response = await http.get(uri).timeout(_timeout);
      final ms = DateTime.now().difference(t2).inMilliseconds;
      debugPrint('[ISS] ← HTTP ${response.statusCode} (${ms}ms)');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final lat = (json['latitude'] as num).toDouble().toStringAsFixed(2);
        final lon = (json['longitude'] as num).toDouble().toStringAsFixed(2);
        debugPrint('[ISS] ✓ wheretheiss.at: lat=$lat lon=$lon');
        return IssPassTime(
            isFallback: true, currentLat: lat, currentLon: lon);
      }
    } on TimeoutException catch (e) {
      final ms = DateTime.now().difference(t2).inMilliseconds;
      debugPrint('[ISS] ✗ wheretheiss.at timeout ${ms}ms: $e');
    } on SocketException catch (e) {
      debugPrint('[ISS] ✗ sem internet: $e');
      throw Exception('Sem conexão com a internet.');
    } catch (e) {
      debugPrint('[ISS] ✗ wheretheiss.at ${e.runtimeType}: $e');
    }

    debugPrint('[ISS] === Todas as APIs falharam ===');
    throw Exception(
        'Serviço de rastreamento da ISS temporariamente indisponível.');
  }

  static Future<Position> _getPosition() async {
    final now = DateTime.now();
    if (_cachedPosition != null &&
        _positionCacheTime != null &&
        now.difference(_positionCacheTime!) < _positionCacheDuration) {
      return _cachedPosition!;
    }

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

    final pos = await Geolocator.getCurrentPosition(
      locationSettings:
          const LocationSettings(accuracy: LocationAccuracy.low),
    );
    _cachedPosition = pos;
    _positionCacheTime = now;
    return pos;
  }
}
