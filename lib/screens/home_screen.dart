import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_screen.dart';

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

class _ApodCard extends StatelessWidget {
  const _ApodCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 200,
            width: double.infinity,
            color: Colors.indigo.shade900,
            child: const Center(
              child: Icon(Icons.image_outlined, size: 64, color: Colors.white30),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Foto do Dia',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.amber,
                        letterSpacing: 1.2,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Carregando NASA APOD...',
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
  }
}

class _IssCard extends StatelessWidget {
  const _IssCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.blueGrey,
          child: Icon(Icons.rocket_launch_outlined, color: Colors.white),
        ),
        title: const Text('Estação Espacial Internacional'),
        subtitle: const Text('Calculando próxima passagem...'),
        trailing: Chip(
          label: const Text('ISS'),
          backgroundColor: Colors.blueGrey.shade800,
        ),
      ),
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
