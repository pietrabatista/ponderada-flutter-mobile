import 'dart:io';
import 'package:flutter/material.dart';
import '../services/observation_service.dart';

const _suggestions = [
  'Lua',
  'Marte',
  'Vênus',
  'Júpiter',
  'Saturno',
  'ISS',
  'Cruzeiro do Sul',
  'Via Láctea',
  'Meteoro',
  'Cometa',
  'Eclipse',
  'Aurora',
];

class ObservationFormScreen extends StatefulWidget {
  final File photoFile;
  final double? latitude;
  final double? longitude;

  const ObservationFormScreen({
    super.key,
    required this.photoFile,
    this.latitude,
    this.longitude,
  });

  @override
  State<ObservationFormScreen> createState() => _ObservationFormScreenState();
}

class _ObservationFormScreenState extends State<ObservationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descricaoController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  String get _locationLabel {
    if (widget.latitude == null || widget.longitude == null) {
      return 'Localização não disponível';
    }
    return '${widget.latitude!.toStringAsFixed(5)}, ${widget.longitude!.toStringAsFixed(5)}';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ObservationService.save(
        photoFile: widget.photoFile,
        titulo: _tituloController.text.trim(),
        lat: widget.latitude,
        long: widget.longitude,
        descricao: _descricaoController.text.trim().isEmpty
            ? null
            : _descricaoController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registro salvo!'),
            backgroundColor: Colors.green,
          ),
        );
        // Volta até a Home
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('O que você viu?')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Miniatura da foto
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  widget.photoFile,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 8),
              // Localização
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.white54),
                  const SizedBox(width: 4),
                  Text(
                    _locationLabel,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.white54),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Autocomplete de título
              Autocomplete<String>(
                optionsBuilder: (textEditingValue) {
                  if (textEditingValue.text.isEmpty) return _suggestions;
                  return _suggestions.where((s) => s
                      .toLowerCase()
                      .contains(textEditingValue.text.toLowerCase()));
                },
                onSelected: (value) => _tituloController.text = value,
                fieldViewBuilder: (_, controller, focusNode, onSubmitted) {
                  // Sincroniza com nosso controller
                  controller.addListener(() {
                    _tituloController.text = controller.text;
                  });
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'O que você viu?',
                      hintText: 'Ex: Lua, Marte, ISS...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    validator: (_) => _tituloController.text.trim().isEmpty
                        ? 'Informe o que você viu'
                        : null,
                  );
                },
              ),
              const SizedBox(height: 16),
              // Descrição opcional
              TextFormField(
                controller: _descricaoController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descrição (opcional)',
                  hintText: 'Conte mais sobre o que observou...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_saving ? 'Salvando...' : 'Salvar registro'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
