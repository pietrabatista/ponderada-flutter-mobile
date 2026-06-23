import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/apod_model.dart';
import 'apod_cache_service.dart';

class NasaService {
  static const _apiKey = 'DEMO_KEY';

  /// Retorna o APOD do dia.
  /// Primeiro verifica o cache local; só chama a API se não houver cache válido.
  /// Ao buscar da API, salva automaticamente no cache local (metadados + imagem).
  static Future<ApodModel> fetchApod() async {
    // 1. Tenta carregar do cache local (mesmo dia)
    final cached = await ApodCacheService.loadToday();
    if (cached != null) return cached;

    // 2. Cache inválido ou desatualizado → chama a API
    final uri = Uri.parse(
      'https://api.nasa.gov/planetary/apod?api_key=$_apiKey',
    );

    final http.Response response;
    try {
      response = await http.get(uri).timeout(const Duration(seconds: 15));
    } catch (e) {
      throw Exception('Sem conexão com a internet.');
    }

    if (response.statusCode == 429 || response.statusCode == 503) {
      throw Exception('NASA API temporariamente indisponível. Tente mais tarde.');
    }
    if (response.statusCode != 200) {
      throw Exception('Erro ao buscar APOD: ${response.statusCode}');
    }

    final apod = ApodModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);

    // 3. Salva no cache local em background (não bloqueia o retorno)
    ApodCacheService.save(apod).catchError((_) {});

    return apod;
  }
}
