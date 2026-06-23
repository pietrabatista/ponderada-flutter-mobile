import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;

class ObservationService {
  static final _client = Supabase.instance.client;

  static Future<void> save({
    required File photoFile,
    required String titulo,
    double? lat,
    double? long,
    String? descricao,
  }) async {
    final userId = _client.auth.currentUser!.id;

    // 1. Upload da foto
    final ext = p.extension(photoFile.path);
    final fileName = '$userId/${DateTime.now().millisecondsSinceEpoch}$ext';
    await _client.storage.from('observation-photos').upload(
          fileName,
          photoFile,
          fileOptions: const FileOptions(upsert: false),
        );
    final fotoUrl = _client.storage
        .from('observation-photos')
        .getPublicUrl(fileName);

    // 2. Salvar registro
    await _client.from('observations').insert({
      'user_id': userId,
      'titulo': titulo,
      'foto_url': fotoUrl,
      'lat': lat,
      'long': long,
      'data': DateTime.now().toIso8601String(),
      'descricao': descricao,
    });
  }

  static Future<List<Map<String, dynamic>>> fetchRecent({int limit = 3}) async {
    final data = await _client
        .from('observations')
        .select()
        .order('data', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(data as List);
  }
}
