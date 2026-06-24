import 'dart:convert';
import 'package:http/http.dart' as http;

class GeocodingService {
  static const _base = 'https://nominatim.openstreetmap.org/reverse';
  static const _headers = {'User-Agent': 'SkySight/1.0'};

  /// "País — Cidade" — usado para a posição da ISS.
  static Future<String?> toCountryCity(double lat, double lon) async {
    try {
      final uri = Uri.parse(
          '$_base?lat=$lat&lon=$lon&format=json&zoom=10&accept-language=pt-BR');
      final resp = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return null;
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final addr = json['address'] as Map<String, dynamic>?;
      if (addr == null) return null;
      final country = addr['country'] as String?;
      final city = (addr['city'] ??
          addr['town'] ??
          addr['village'] ??
          addr['county']) as String?;
      if (country != null && city != null) return '$country — $city';
      return country ?? city;
    } catch (_) {
      return null;
    }
  }

  /// "Bairro — Cidade" — usado para localização de registros.
  static Future<String?> toNeighborhoodCity(double lat, double lon) async {
    try {
      final uri = Uri.parse(
          '$_base?lat=$lat&lon=$lon&format=json&zoom=16&accept-language=pt-BR');
      final resp = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return null;
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final addr = json['address'] as Map<String, dynamic>?;
      if (addr == null) return null;
      final neighbourhood =
          (addr['neighbourhood'] ?? addr['suburb'] ?? addr['quarter'])
              as String?;
      final city = (addr['city'] ?? addr['town'] ?? addr['village']) as String?;
      if (neighbourhood != null && city != null) return '$neighbourhood — $city';
      return city ?? neighbourhood;
    } catch (_) {
      return null;
    }
  }
}
