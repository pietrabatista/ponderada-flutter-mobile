import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class IssPassTime {
  final DateTime? time; // null quando só temos posição atual (fallback)
  final String? currentLat;
  final String? currentLon;
  final bool isFallback;

  const IssPassTime({
    this.time,
    this.currentLat,
    this.currentLon,
    this.isFallback = false,
  });

  String get label {
    if (isFallback && currentLat != null) {
      return 'ISS agora em $currentLat°, $currentLon° (passagens indisponíveis)';
    }
    if (time == null) return 'Dados indisponíveis';
    final now = DateTime.now();
    final diff = time!.difference(now);
    if (diff.isNegative) return 'Passou recentemente';
    if (diff.inMinutes < 60) return 'ISS passa em ${diff.inMinutes} min';
    return 'ISS passa às ${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}';
  }
}

class IssService {
  static Future<IssPassTime> nextPass() async {
    Position? position;
    try {
      position = await _getPosition();
    } catch (e) {
      throw Exception('Permissão de localização negada ou GPS desativado.');
    }

    // Tenta o endpoint de passagens
    try {
      final uri = Uri.parse(
        'https://api.open-notify.org/iss-pass.json'
        '?lat=${position.latitude}&lon=${position.longitude}&n=1',
      );
      final response =
          await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final passes = json['response'] as List<dynamic>;
        if (passes.isNotEmpty) {
          final riseTime = passes[0]['risetime'] as int;
          return IssPassTime(
              time: DateTime.fromMillisecondsSinceEpoch(riseTime * 1000));
        }
      }
    } on SocketException {
      // Sem internet — propaga com mensagem clara
      throw Exception('Sem conexão com a internet.');
    } catch (_) {
      // Servidor rejeitou ou timeout — tenta fallback com posição atual
    }

    // Fallback: mostra posição atual da ISS via iss-now (mais estável)
    try {
      final nowUri =
          Uri.parse('http://api.open-notify.org/iss-now.json');
      final nowResp =
          await http.get(nowUri).timeout(const Duration(seconds: 8));
      if (nowResp.statusCode == 200) {
        final json = jsonDecode(nowResp.body) as Map<String, dynamic>;
        final pos = json['iss_position'] as Map<String, dynamic>;
        final lat = (double.parse(pos['latitude'].toString())).toStringAsFixed(2);
        final lon = (double.parse(pos['longitude'].toString())).toStringAsFixed(2);
        return IssPassTime(
          isFallback: true,
          currentLat: lat,
          currentLon: lon,
        );
      }
    } on SocketException {
      throw Exception('Sem conexão com a internet.');
    } catch (_) {}

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
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
    );
  }
}
