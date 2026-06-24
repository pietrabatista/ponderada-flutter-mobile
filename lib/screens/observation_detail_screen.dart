import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart' show Share;
import '../models/observation_model.dart';
import '../widgets/supabase_image.dart';

class ObservationDetailScreen extends StatelessWidget {
  final ObservationModel observation;

  const ObservationDetailScreen({super.key, required this.observation});

  String get _formattedDate {
    final d = observation.data;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
        'às ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String get _locationText {
    if (observation.lat == null || observation.long == null) {
      return 'Localização não disponível';
    }
    return '${observation.lat!.toStringAsFixed(5)}, ${observation.long!.toStringAsFixed(5)}';
  }

  String get _shareText {
    return 'Vi ${observation.titulo} em $_formattedDate! via SkySight ✨';
  }

  Future<void> _share(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    await Share.share(
      _shareText,
      subject: observation.titulo,
      sharePositionOrigin: origin,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Foto grande com AppBar sobreposta
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: 'Compartilhar',
                onPressed: () => _share(context),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                observation.titulo,
                style: const TextStyle(
                  shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                ),
              ),
              background: observation.fotoUrl != null
                  ? SupabaseImage(
                      url: observation.fotoUrl!,
                      fit: BoxFit.cover,
                      placeholder: _photoPlaceholder,
                      errorWidget: _photoPlaceholder,
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
                  // Data/hora
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Data e hora',
                    value: _formattedDate,
                  ),
                  const Divider(height: 28),

                  // Localização
                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    label: 'Localização',
                    value: _locationText,
                  ),

                  // Mini mapa estático (se tiver coordenadas)
                  if (observation.lat != null && observation.long != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        'https://maps.googleapis.com/maps/api/staticmap'
                        '?center=${observation.lat},${observation.long}'
                        '&zoom=13&size=600x200&maptype=roadmap'
                        '&markers=color:red%7C${observation.lat},${observation.long}'
                        '&key=YOUR_GOOGLE_MAPS_KEY',
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              _locationText,
                              style: const TextStyle(color: Colors.white54),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Descrição
                  if (observation.descricao != null &&
                      observation.descricao!.isNotEmpty) ...[
                    const Divider(height: 28),
                    _InfoRow(
                      icon: Icons.notes_outlined,
                      label: 'Descrição',
                      value: observation.descricao!,
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
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
