import 'dart:io';
import 'package:flutter/material.dart';

class ObservationFormScreen extends StatelessWidget {
  final File photoFile;

  const ObservationFormScreen({super.key, required this.photoFile});

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
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Foto capturada! Formulário em construção (issue #9).',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
