import 'dart:io';
import 'package:flutter/material.dart';

class ObservationFormScreen extends StatelessWidget {
  final File photoFile;
  final double? latitude;
  final double? longitude;

  const ObservationFormScreen({
    super.key,
    required this.photoFile,
    this.latitude,
    this.longitude,
  });

  String get _locationLabel {
    if (latitude == null || longitude == null) return 'Localização não disponível';
    return '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo Registro')),
      body: Column(
        children: [
          Expanded(
            child: Image.file(
              photoFile,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.location_on, size: 18, color: Colors.white54),
                const SizedBox(width: 6),
                Text(
                  _locationLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white54,
                      ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 24),
            child: Text(
              'Formulário em construção (issue #9).',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
