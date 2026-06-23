import 'dart:convert';
import 'dart:io';
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

  /// Countdown atualizado em tempo real (recalcula a cada chamada).
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
  // API principal de passagens (instável)
  static const _passApi = 'http://api.open-notify.org/iss-pass.json';
  // API de posição alternativa (mais estável)
  static const _positionApi =
      'https://api.wheretheiss.at/v1/satellites/25544';

  static Future<IssPassTime> nextPass() async {
    // 1. Obtém localização do usuário
    Position position;
    try {
      position = await _getPosition();
    } catch (e) {
      throw Exception('Permissão de localização negada ou GPS desativado.');
    }

    // 2. Tenta o endpoint de passagens
    try {
      final uri = Uri.parse(
          '$_passApi?lat=${position.latitude}&lon=${position.longitude}&n=1');
      final response =
          await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final passes = json['response'] as List<dynamic>;
        if (passes.isNotEmpty) {
          final riseTime = passes[0]['risetime'] as int;
          return IssPassTime(
            time: DateTime.fromMillisecondsSinceEpoch(riseTime * 1000),
          );
        }
      }
    } catch (_) {
      // Endpoint de passagens falhou (servidor fora, timeout, etc.)
      // → vai tentar fallback abaixo
    }

    // 3. Fallback: posição atual via wheretheiss.at (API diferente e mais confiável)
    try {
      final uri = Uri.parse(_positionApi);
      final response =
          await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final lat =
            (json['latitude'] as num).toDouble().toStringAsFixed(2);
        final lon =
            (json['longitude'] as num).toDouble().toStringAsFixed(2);
        return IssPassTime(
          isFallback: true,
          currentLat: lat,
          currentLon: lon,
        );
      }
    } on SocketException {
      // wheretheiss.at também falhou via SocketException → sem internet de fato
      throw Exception('Sem conexão com a internet.');
    } catch (_) {
      // Outro erro no fallback
    }

    throw Exception('Serviço de rastreamento da ISS temporariamente indisponível.');
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
      locationSettings:
          const LocationSettings(accuracy: LocationAccuracy.low),
    );
  }
}
