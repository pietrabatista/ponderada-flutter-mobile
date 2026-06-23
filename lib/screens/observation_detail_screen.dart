import 'package:flutter/material.dart';
import '../models/observation_model.dart';

class ObservationDetailScreen extends StatelessWidget {
  final ObservationModel observation;
  const ObservationDetailScreen({super.key, required this.observation});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(observation.titulo)),
      body: const Center(child: Text('Detalhe em construção (issue #11).')),
    );
  }
}
