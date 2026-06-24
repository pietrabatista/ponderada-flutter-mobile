import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'observation_detail_screen.dart';
import '../models/apod_model.dart';
import '../models/observation_model.dart';
import '../services/nasa_service.dart';
import '../services/iss_service.dart';
import '../services/notification_service.dart';
import '../services/apod_cache_service.dart';
import '../widgets/supabase_image.dart';

class HomeScreen extends StatelessWidget {
  final ValueNotifier<int>? refreshTrigger;

  const HomeScreen({super.key, this.refreshTrigger});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SkySight'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _ApodCard(),
          const SizedBox(height: 16),
          const _IssCard(),
          const SizedBox(height: 16),
          _RecentObservations(refreshTrigger: refreshTrigger),
        ],
      ),
    );
  }
}

// ─── APOD Card ───────────────────────────────────────────────────────────────

class _ApodCard extends StatefulWidget {
  const _ApodCard();

  @override
  State<_ApodCard> createState() => _ApodCardState();
}

// Agrupamento do model + arquivo local da imagem
class _ApodData {
  final ApodModel apod;
  final File? localImage; // null = sem cache de imagem local
  const _ApodData(this.apod, this.localImage);
}

class _ApodCardState extends State<_ApodCard> {
  late Future<_ApodData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ApodData> _load() async {
    final apod = await NasaService.fetchApod();
    NotificationService.scheduleApodDaily().catchError((_) {});
    // Tenta carregar imagem local (pode não existir ainda se acabou de baixar)
    final localFile = await ApodCacheService.localImageFile();
    return _ApodData(apod, localFile);
  }

  void _retry() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ApodData>(
      future: _future,
      builder: (context, snapshot) {
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: snapshot.hasData ? () => _openUrl(snapshot.data!.apod.url) : null,
                child: _buildMedia(snapshot),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FOTO DO DIA',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.amber,
                            letterSpacing: 1.2,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      snapshot.hasData
                          ? snapshot.data!.apod.title
                          : snapshot.hasError
                              ? 'Não foi possível carregar'
                              : 'Carregando...',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (snapshot.hasError) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _retry,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Tentar novamente'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMedia(AsyncSnapshot<_ApodData> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return _mediaBox(child: const CircularProgressIndicator());
    }
    if (snapshot.hasError || !snapshot.hasData) {
      return _mediaBox(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.cloud_off_outlined, size: 48, color: Colors.white30),
            SizedBox(height: 8),
            Text('Sem conexão', style: TextStyle(color: Colors.white38)),
          ],
        ),
      );
    }

    final data = snapshot.data!;
    final apod = data.apod;

    if (apod.mediaType != 'image') {
      final ytId = _youtubeId(apod.url);
      if (ytId != null) {
        // Mostra thumbnail do YouTube com ícone de play sobreposto
        return Stack(
          alignment: Alignment.center,
          children: [
            Image.network(
              'https://img.youtube.com/vi/$ytId/hqdefault.jpg',
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _mediaBox(
                child: const Icon(Icons.play_circle_outline,
                    size: 64, color: Colors.white54),
              ),
            ),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 40),
            ),
          ],
        );
      }
      return _mediaBox(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.play_circle_outline, size: 64, color: Colors.white54),
            SizedBox(height: 8),
            Text('Vídeo do dia', style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    // Preferência: arquivo local → fallback para URL da rede
    if (data.localImage != null) {
      return Image.file(
        data.localImage!,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _networkImage(apod.url),
      );
    }

    return _networkImage(apod.url);
  }

  /// Extrai o ID do vídeo do YouTube de uma URL embed ou watch.
  String? _youtubeId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    // youtube.com/embed/ID ou youtube.com/watch?v=ID
    if (uri.host.contains('youtube.com')) {
      final segments = uri.pathSegments;
      final embedIdx = segments.indexOf('embed');
      if (embedIdx != -1 && embedIdx + 1 < segments.length) {
        return segments[embedIdx + 1];
      }
      return uri.queryParameters['v'];
    }
    // youtu.be/ID
    if (uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.first;
    }
    return null;
  }

  Widget _networkImage(String url) => Image.network(
        url,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : _mediaBox(child: const CircularProgressIndicator()),
        errorBuilder: (_, __, ___) => _mediaBox(
          child: const Icon(Icons.broken_image_outlined, size: 64, color: Colors.white30),
        ),
      );

  Widget _mediaBox({required Widget child}) => Container(
        height: 200,
        width: double.infinity,
        color: Colors.indigo.shade900,
        child: Center(child: child),
      );
}

// ─── ISS Card ────────────────────────────────────────────────────────────────

class _IssCard extends StatefulWidget {
  const _IssCard();

  @override
  State<_IssCard> createState() => _IssCardState();
}

class _IssCardState extends State<_IssCard> {
  late Future<IssPassTime> _future;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _future = _fetchAndSchedule();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  List<IssLogEntry> _lastLogs = [];

  Future<IssPassTime> _fetchAndSchedule() async {
    try {
      final pass = await IssService.nextPass();
      if (mounted) setState(() => _lastLogs = pass.logs);
      if (pass.time != null) {
        NotificationService.scheduleIssPass(pass.time!).catchError((_) {});
        _countdownTimer?.cancel();
        _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
          if (mounted) setState(() {});
        });
      }
      return pass;
    } on IssException catch (e) {
      if (mounted) setState(() => _lastLogs = e.logs);
      rethrow;
    }
  }

  void _retry() {
    _countdownTimer?.cancel();
    setState(() {
      _future = _fetchAndSchedule();
    });
  }

  bool _showLogs = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<IssPassTime>(
      future: _future,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final hasError = snapshot.hasError;
        final pass = snapshot.data;

        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.blueGrey,
                      child: Icon(Icons.rocket_launch_outlined, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Estação Espacial Internacional',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          if (isLoading)
                            const Text('Buscando posição da ISS...',
                                style: TextStyle(fontSize: 12, color: Colors.white54))
                          else if (hasError)
                            Text(
                              snapshot.error.toString().replaceAll('Exception: ', ''),
                              style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                              maxLines: 2,
                            )
                          else ...[
                            Text(
                              pass!.label,
                              style: const TextStyle(fontSize: 12, color: Colors.white70),
                              maxLines: 2,
                            ),
                            if (pass.countdown.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey.shade700,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  pass.countdown,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                    if (isLoading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else ...[
                      if (hasError)
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _retry,
                          tooltip: 'Tentar novamente',
                        ),
                      if (_lastLogs.isNotEmpty)
                        IconButton(
                          icon: Icon(
                            _showLogs ? Icons.bug_report : Icons.bug_report_outlined,
                            size: 20,
                            color: _showLogs ? Colors.amber : Colors.white38,
                          ),
                          tooltip: 'Log de APIs',
                          onPressed: () => setState(() => _showLogs = !_showLogs),
                        ),
                    ],
                  ],
                ),
                if (_showLogs && _lastLogs.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'LOG DE APIS',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.amber,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ..._lastLogs.map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.ok ? '✓' : '✗',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: e.ok ? Colors.greenAccent : Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${e.step}${e.elapsed != null ? " (${e.elapsed!.inMilliseconds}ms)" : ""}\n${e.detail}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.white60,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Recent Observations ─────────────────────────────────────────────────────

class _RecentObservations extends StatefulWidget {
  final ValueNotifier<int>? refreshTrigger;

  const _RecentObservations({this.refreshTrigger});

  @override
  State<_RecentObservations> createState() => _RecentObservationsState();
}

class _RecentObservationsState extends State<_RecentObservations> {
  late Future<List<ObservationModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
    widget.refreshTrigger?.addListener(_onRefresh);
  }

  @override
  void dispose() {
    widget.refreshTrigger?.removeListener(_onRefresh);
    super.dispose();
  }

  void _onRefresh() {
    setState(() {
      _future = _fetch();
    });
  }

  Future<List<ObservationModel>> _fetch() async {
    final data = await Supabase.instance.client
        .from('observations')
        .select()
        .order('data', ascending: false)
        .limit(3);
    return (data as List)
        .map((e) => ObservationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Últimos registros',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white70,
                  letterSpacing: 0.5,
                ),
          ),
        ),
        FutureBuilder<List<ObservationModel>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Column(
                children: List.generate(3, (_) => const _SkeletonTile()),
              );
            }
            if (snapshot.hasError) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Erro ao carregar registros',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _future = _fetch();
                          });
                        },
                        child: const Text('Tentar'),
                      ),
                    ],
                  ),
                ),
              );
            }
            final list = snapshot.data!;
            if (list.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: Column(
                    children: [
                      const Icon(Icons.nightlight_round, size: 40, color: Colors.white24),
                      const SizedBox(height: 8),
                      Text(
                        'Nenhum registro ainda.\nToque em + para começar!',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Column(
              children: list
                  .map(
                    (obs) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ObservationDetailScreen(observation: obs),
                          ),
                        ),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: obs.fotoUrl != null
                              ? SupabaseImage(
                                  url: obs.fotoUrl!,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  placeholder: _photoPlaceholder,
                                  errorWidget: _photoPlaceholder,
                                )
                              : _photoPlaceholder(),
                        ),
                        title: Text(obs.titulo,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(_fmtDate(obs.data)),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _photoPlaceholder() => Container(
        width: 48,
        height: 48,
        color: Colors.grey.shade800,
        child: const Icon(Icons.photo, color: Colors.white30),
      );

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        title: Container(
          height: 14,
          width: 120,
          decoration: BoxDecoration(
            color: Colors.grey.shade700,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            height: 10,
            width: 80,
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}
