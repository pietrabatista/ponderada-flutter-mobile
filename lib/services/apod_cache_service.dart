import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/apod_model.dart';

/// Gerencia o cache local do APOD (foto + metadados).
/// A foto é salva em arquivo local; os metadados ficam no SharedPreferences.
/// O cache é válido apenas para o dia atual (mesma data da NASA).
class ApodCacheService {
  static const _keyDate = 'apod_date';
  static const _keyTitle = 'apod_title';
  static const _keyUrl = 'apod_url';
  static const _keyMediaType = 'apod_media_type';
  static const _keyExplanation = 'apod_explanation';
  static const _imageFileName = 'apod_today.jpg';

  /// Retorna o APOD salvo localmente se for do dia de hoje; null caso contrário.
  static Future<ApodModel?> loadToday() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString(_keyDate);

    if (savedDate == null || savedDate != _todayStr()) return null;

    final title = prefs.getString(_keyTitle);
    final url = prefs.getString(_keyUrl);
    final mediaType = prefs.getString(_keyMediaType);
    final explanation = prefs.getString(_keyExplanation) ?? '';

    if (title == null || url == null || mediaType == null) return null;

    return ApodModel(
      title: title,
      url: url,
      mediaType: mediaType,
      explanation: explanation,
      date: savedDate,
    );
  }

  /// Salva o APOD localmente (metadados + download da imagem).
  static Future<void> save(ApodModel apod) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDate, _todayStr());
    await prefs.setString(_keyTitle, apod.title);
    await prefs.setString(_keyUrl, apod.url);
    await prefs.setString(_keyMediaType, apod.mediaType);
    await prefs.setString(_keyExplanation, apod.explanation);

    // Baixa e salva a imagem em arquivo local (só para imagens, não vídeos)
    if (apod.mediaType == 'image') {
      try {
        final response =
            await http.get(Uri.parse(apod.url)).timeout(const Duration(seconds: 30));
        if (response.statusCode == 200) {
          final file = await _imageFile();
          await file.writeAsBytes(response.bodyBytes);
        }
      } catch (_) {
        // Falha no download: app continua funcionando via URL
      }
    }
  }

  /// Retorna o arquivo de imagem local do APOD se existir e for de hoje.
  static Future<File?> localImageFile() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString(_keyDate);
    if (savedDate != _todayStr()) return null;

    final file = await _imageFile();
    return file.existsSync() ? file : null;
  }

  static Future<File> _imageFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_imageFileName');
  }

  static String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
