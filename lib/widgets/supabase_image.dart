import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Carrega imagem do Supabase Storage.
/// Tenta a URL pública diretamente; se receber 400/403/404,
/// gera uma signed URL autenticada como fallback.
class SupabaseImage extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget Function()? placeholder;
  final Widget Function()? errorWidget;

  const SupabaseImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<SupabaseImage> createState() => _SupabaseImageState();
}

class _SupabaseImageState extends State<SupabaseImage> {
  late Future<String> _urlFuture;

  @override
  void initState() {
    super.initState();
    _urlFuture = _resolveUrl();
  }

  @override
  void didUpdateWidget(SupabaseImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _urlFuture = _resolveUrl();
    }
  }

  /// Extrai o path do storage a partir da URL pública para poder
  /// gerar uma signed URL caso necessário.
  /// URL format: .../storage/v1/object/public/{bucket}/{path}
  String? _extractPath(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final segments = uri.pathSegments;
    // procura pelo bucket após 'public'
    final publicIdx = segments.indexOf('public');
    if (publicIdx != -1 && publicIdx + 2 < segments.length) {
      // segments[publicIdx+1] = bucket name
      // segments[publicIdx+2..] = path inside bucket
      return segments.sublist(publicIdx + 2).join('/');
    }
    return null;
  }

  String? _extractBucket(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final segments = uri.pathSegments;
    final publicIdx = segments.indexOf('public');
    if (publicIdx != -1 && publicIdx + 1 < segments.length) {
      return segments[publicIdx + 1];
    }
    return null;
  }

  Future<String> _resolveUrl() async {
    // Tenta gerar signed URL (válida por 1 hora) para garantir acesso
    // tanto em buckets públicos quanto privados
    try {
      final bucket = _extractBucket(widget.url);
      final path = _extractPath(widget.url);
      if (bucket != null && path != null) {
        final signed = await Supabase.instance.client.storage
            .from(bucket)
            .createSignedUrl(path, 3600); // 1 hora
        return signed;
      }
    } catch (_) {
      // Se falhar (ex: objeto não existe), usa URL original
    }
    return widget.url;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _urlFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: widget.placeholder?.call() ??
                Container(color: Colors.grey.shade800),
          );
        }

        return Image.network(
          snapshot.data!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : _placeholderWidget(),
          errorBuilder: (_, __, ___) =>
              widget.errorWidget?.call() ?? _placeholderWidget(),
        );
      },
    );
  }

  Widget _placeholderWidget() => SizedBox(
        width: widget.width,
        height: widget.height,
        child: widget.placeholder?.call() ??
            Container(
              color: Colors.grey.shade800,
              child: const Icon(Icons.photo, color: Colors.white30),
            ),
      );
}
