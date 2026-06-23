import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/apod_model.dart';

class NasaService {
  static Future<ApodModel> fetchApod() async {
    final apiKey = dotenv.env['NASA_API_KEY'] ?? 'DEMO_KEY';
    final uri = Uri.parse(
      'https://api.nasa.gov/planetary/apod?api_key=$apiKey',
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Erro ao buscar APOD: ${response.statusCode}');
    }
    return ApodModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}
