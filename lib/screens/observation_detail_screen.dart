import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart' show Share;
import '../models/observation_model.dart';
import '../services/geocoding_service.dart';
import '../widgets/supabase_image.dart';

class ObservationDetailScreen extends StatefulWidget {
  final ObservationModel observation;

  const ObservationDetailScreen({super.key, required this.observation});

  @override
  State<ObservationDetailScreen> createState() =>
      _ObservationDetailScreenState();
}

class _ObservationDetailScreenState extends State<ObservationDetailScreen> {
  String? _geoLabel;

  @override
  void initState() {
    super.initState();
    final obs = widget.observation;
    if (obs.lat != null && obs.long != null) {
      GeocodingService.toNeighborhoodCity(obs.lat!, obs.long!).then((label) {
        if (mounted && label != null) setState(() => _geoLabel = label);
      });
    }
  }

  ObservationModel get _obs => widget.observation;

  String get _formattedDate {
    final d = _obs.data;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
        'às ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String get _locationText {
    if (_geoLabel != null) return _geoLabel!;
    if (_obs.lat == null || _obs.long == null) return 'Localização não disponível';
    return '${_obs.lat!.toStringAsFixed(5)}, ${_obs.long!.toStringAsFixed(5)}';
  }

  String get _shareText =>
      'Vi ${_obs.titulo} em $_formattedDate! via SkySight ✨';

  Future<void> _share() async {
    final box = context.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    await Share.share(
      _shareText,
      subject: _obs.titulo,
      sharePositionOrigin: origin,
    );
  }

  void _openImageModal(String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5.0,
                child: SupabaseImage(
                  url: url,
                  fit: BoxFit.contain,
                  placeholder: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  errorWidget: () => const Icon(Icons.broken_image_outlined,
                      size: 64, color: Colors.white30),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                ),
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: 'Compartilhar',
                onPressed: _share,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                _obs.titulo,
                style: const TextStyle(
                  shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                ),
              ),
              background: _obs.fotoUrl != null
                  ? GestureDetector(
                      onTap: () => _openImageModal(_obs.fotoUrl!),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          SupabaseImage(
                            url: _obs.fotoUrl!,
                            fit: BoxFit.cover,
                            placeholder: _photoPlaceholder,
                            errorWidget: _photoPlaceholder,
                          ),
                          // Hint visual: ícone de expand no canto
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.open_in_full,
                                  color: Colors.white70, size: 16),
                            ),
                          ),
                        ],
                      ),
                    )
                  : _photoPlaceholder(),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Data e hora',
                    value: _formattedDate,
                  ),
                  const Divider(height: 28),

                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    label: 'Localização',
                    value: _locationText,
                  ),
                  if (_geoLabel != null &&
                      _obs.lat != null &&
                      _obs.long != null) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: Text(
                        '${_obs.lat!.toStringAsFixed(5)}, ${_obs.long!.toStringAsFixed(5)}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white38),
                      ),
                    ),
                  ],

                  if (_obs.descricao != null &&
                      _obs.descricao!.isNotEmpty) ...[
                    const Divider(height: 28),
                    _InfoRow(
                      icon: Icons.notes_outlined,
                      label: 'Descrição',
                      value: _obs.descricao!,
                    ),
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoPlaceholder() => Container(
        color: Colors.indigo.shade900,
        child: const Center(
          child: Icon(Icons.photo, size: 64, color: Colors.white24),
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.amber),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white54,
                      letterSpacing: 0.8,
                    ),
              ),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
