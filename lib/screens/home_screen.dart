import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'observation_detail_screen.dart';
import '../models/apod_model.dart';
import '../models/observation_model.dart';
import '../services/nasa_service.dart';
import '../services/iss_service.dart';
import '../services/notification_service.dart';
import '../services/apod_cache_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diário do Céu'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _ApodCard(),
          SizedBox(height: 16),
          _IssCard(),
          SizedBox(height: 16),
          _RecentObservations(),
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
              _buildMedia(snapshot),
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
      return _mediaBox(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.play_circle_outline, size: 64, color: Colors.white54),
            SizedBox(height: 8),
            Text('Vídeo disponível', style: TextStyle(color: Colors.white38)),
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

  @override
  void initState() {
    super.initState();
    _future = _fetchAndSchedule();
  }

  Future<IssPassTime> _fetchAndSchedule() async {
    try {
      final pass = await IssService.nextPass();
      NotificationService.scheduleIssPass(pass.time).catchError((_) {});
      return pass;
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.contains('Connection reset') || msg.contains('SocketException') || msg.contains('Failed host')) {
        throw Exception('Sem conexão. Verifique sua internet.');
      }
      rethrow;
    }
  }

  void _retry() {
    setState(() {
      _future = _fetchAndSchedule();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<IssPassTime>(
      future: _future,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final hasError = snapshot.hasError;

        return Card(
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.blueGrey,
              child: Icon(Icons.rocket_launch_outlined, color: Colors.white),
            ),
            title: const Text('Estação Espacial Internacional'),
            subtitle: Text(
              isLoading
                  ? 'Calculando próxima passagem...'
                  : hasError
                      ? snapshot.error
                          .toString()
                          .replaceAll('Exception: ', '')
                      : snapshot.data!.label,
              style: hasError
                  ? const TextStyle(color: Colors.redAccent, fontSize: 12)
                  : null,
              maxLines: 2,
            ),
            trailing: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : hasError
                    ? IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _retry,
                        tooltip: 'Tentar novamente',
                      )
                    : Chip(
                        label: const Text('ISS'),
                        backgroundColor: Colors.blueGrey.shade800,
                      ),
          ),
        );
      },
    );
  }
}

// ─── Recent Observations ─────────────────────────────────────────────────────

class _RecentObservations extends StatefulWidget {
  const _RecentObservations();

  @override
  State<_RecentObservations> createState() => _RecentObservationsState();
}

class _RecentObservationsState extends State<_RecentObservations> {
  late Future<List<ObservationModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
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
                              ? Image.network(
                                  obs.fotoUrl!,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  headers: {
                                    'Authorization':
                                        'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken ?? ''}',
                                  },
                                  errorBuilder: (_, __, ___) => _photoPlaceholder(),
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
