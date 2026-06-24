import 'dart:convert';
import 'package:http/http.dart' as http;

class GeocodingService {
  static const _base = 'https://nominatim.openstreetmap.org/reverse';
  static const _headers = {'User-Agent': 'SkySight/1.0'};

  /// "País — Cidade" ou "Nome do Oceano/Mar" — usado para a posição da ISS.
  /// Usa Nominatim para terra firme e BigDataCloud como fallback para oceanos.
  static Future<String?> toCountryCity(double lat, double lon) async {
    // 1. Nominatim (rápido para terra firme)
    try {
      final uri = Uri.parse(
          '$_base?lat=$lat&lon=$lon&format=json&zoom=10&accept-language=pt-BR');
      final resp = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        if (!json.containsKey('error')) {
          final addr = json['address'] as Map<String, dynamic>?;
          if (addr != null) {
            final country = addr['country'] as String?;
            final city = (addr['city'] ??
                addr['town'] ??
                addr['village'] ??
                addr['county'] ??
                addr['state']) as String?;
            if (country != null && city != null) return '$country — $city';
            if (country != null) return country;
          }
        }
      }
    } catch (_) {}

    // 2. BigDataCloud — lida com oceanos e mares
    try {
      final uri = Uri.parse(
          'https://api.bigdatacloud.net/data/reverse-geocode-client'
          '?latitude=$lat&longitude=$lon&localityLanguage=pt');
      final resp = await http.get(uri).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        final country = json['countryName'] as String?;
        final city = (json['city'] as String?)?.isNotEmpty == true
            ? json['city'] as String
            : (json['locality'] as String?)?.isNotEmpty == true
                ? json['locality'] as String
                : null;
        if (country != null && country.isNotEmpty && city != null) {
          return '$country — $city';
        }
        if (city != null && city.isNotEmpty) return city;
        if (country != null && country.isNotEmpty) return country;
      }
    } catch (_) {}

    return null;
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
