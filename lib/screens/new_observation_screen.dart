import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'observation_form_screen.dart';

class NewObservationScreen extends StatefulWidget {
  const NewObservationScreen({super.key});

  @override
  State<NewObservationScreen> createState() => _NewObservationScreenState();
}

class _NewObservationScreenState extends State<NewObservationScreen> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Abre a câmera automaticamente ao entrar na tela
    WidgetsBinding.instance.addPostFrameCallback((_) => _openCamera());
  }

  Future<void> _openCamera() async {
    setState(() => _loading = true);
    try {
      final picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (!mounted) return;

      if (photo == null) {
        // Usuário cancelou
        Navigator.of(context).pop();
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ObservationFormScreen(photoFile: File(photo.path)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao abrir câmera: $e'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _loading
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Abrindo câmera...'),
                ],
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
