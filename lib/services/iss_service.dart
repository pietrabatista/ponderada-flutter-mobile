import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class IssPassTime {
  final DateTime time;

  const IssPassTime(this.time);

  String get label {
    final now = DateTime.now();
    final diff = time.difference(now);
    if (diff.isNegative) return 'Passou recentemente';
    if (diff.inMinutes < 60) return 'ISS passa em ${diff.inMinutes} min';
    return 'ISS passa às ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class IssService {
  static Future<IssPassTime> nextPass() async {
    final position = await _getPosition();
    final uri = Uri.parse(
      'https://api.open-notify.org/iss-pass.json'
      '?lat=${position.latitude}&lon=${position.longitude}&n=1',
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Erro ao buscar passagem da ISS: ${response.statusCode}');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final passes = json['response'] as List<dynamic>;
    if (passes.isEmpty) throw Exception('Nenhuma passagem encontrada');
    final riseTime = passes[0]['risetime'] as int;
    return IssPassTime(DateTime.fromMillisecondsSinceEpoch(riseTime * 1000));
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
