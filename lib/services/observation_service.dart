import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;

class ObservationService {
  static final _client = Supabase.instance.client;

  /// Exclui uma observação do banco e a foto do Storage.
  static Future<void> delete(String id, String? fotoUrl) async {
    // 1. Deleta o registro do banco
    await _client.from('observations').delete().eq('id', id);

    // 2. Remove a foto do Storage (extrai o path do URL)
    if (fotoUrl != null && fotoUrl.isNotEmpty) {
      try {
        // URL format: .../object/public/observation-photos/{userId}/{file}
        // ou         .../object/sign/observation-photos/{userId}/{file}
        final uri = Uri.parse(fotoUrl);
        final segments = uri.pathSegments;
        final bucketIdx = segments.indexOf('observation-photos');
        if (bucketIdx != -1 && bucketIdx + 1 < segments.length) {
          final storagePath =
              segments.sublist(bucketIdx + 1).join('/');
          await _client.storage
              .from('observation-photos')
              .remove([storagePath]);
        }
      } catch (_) {
        // Falha ao deletar storage não impede o fluxo
      }
    }
  }

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
