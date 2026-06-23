import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/apod_model.dart';

class NasaService {
  static const _apiKey = 'DEMO_KEY';

  static Future<ApodModel> fetchApod() async {
    final uri = Uri.parse(
      'https://api.nasa.gov/planetary/apod?api_key=$_apiKey',
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Erro ao buscar APOD: ${response.statusCode}');
    }
    return ApodModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }
}
