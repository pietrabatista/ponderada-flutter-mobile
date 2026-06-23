import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_screen.dart';
import '../models/apod_model.dart';
import '../services/nasa_service.dart';
import '../services/iss_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diário do Céu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                );
              }
            },
          ),
        ],
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        tooltip: 'Novo registro',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ApodCard extends StatefulWidget {
  const _ApodCard();

  @override
  State<_ApodCard> createState() => _ApodCardState();
}

class _ApodCardState extends State<_ApodCard> {
  late Future<ApodModel> _future;

  @override
  void initState() {
    super.initState();
    _future = NasaService.fetchApod();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ApodModel>(
      future: _future,
      builder: (context, snapshot) {
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImage(snapshot),
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
                          ? snapshot.data!.title
                          : snapshot.hasError
                              ? 'Erro ao carregar'
                              : 'Carregando...',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImage(AsyncSnapshot<ApodModel> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return Container(
        height: 200,
        width: double.infinity,
        color: Colors.indigo.shade900,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (snapshot.hasError || !snapshot.hasData) {
      return Container(
        height: 200,
        width: double.infinity,
        color: Colors.indigo.shade900,
        child: const Center(
          child: Icon(Icons.broken_image_outlined, size: 64, color: Colors.white30),
        ),
      );
    }
    final apod = snapshot.data!;
    if (apod.mediaType == 'image') {
      return Image.network(
        apod.url,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : Container(
                height: 200,
                color: Colors.indigo.shade900,
                child: const Center(child: CircularProgressIndicator()),
              ),
        errorBuilder: (_, __, ___) => Container(
          height: 200,
          color: Colors.indigo.shade900,
          child: const Center(
            child: Icon(Icons.broken_image_outlined, size: 64, color: Colors.white30),
          ),
        ),
      );
    }
    // vídeo (ex: YouTube) — exibe ícone
    return Container(
      height: 200,
      width: double.infinity,
      color: Colors.indigo.shade900,
      child: const Center(
        child: Icon(Icons.play_circle_outline, size: 64, color: Colors.white54),
      ),
    );
  }
}

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
    _future = IssService.nextPass();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<IssPassTime>(
      future: _future,
      builder: (context, snapshot) {
        final subtitle = snapshot.connectionState == ConnectionState.waiting
            ? 'Calculando próxima passagem...'
            : snapshot.hasError
                ? snapshot.error.toString().replaceFirst('Exception: ', '')
                : snapshot.data!.label;

        return Card(
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.blueGrey,
              child: Icon(Icons.rocket_launch_outlined, color: Colors.white),
            ),
            title: const Text('Estação Espacial Internacional'),
            subtitle: Text(subtitle),
            trailing: snapshot.connectionState == ConnectionState.waiting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
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

class _RecentObservations extends StatelessWidget {
  const _RecentObservations();

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
        ...List.generate(3, (i) => _ObservationPlaceholder(index: i)),
      ],
    );
  }
}

class _ObservationPlaceholder extends StatelessWidget {
  final int index;
  const _ObservationPlaceholder({required this.index});

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
          child: const Icon(Icons.photo, color: Colors.white30),
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
