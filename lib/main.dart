import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? initError;
  try {
    await dotenv.load();
    await SupabaseService.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );
  } catch (e) {
    initError = e.toString();
  }

  runApp(DiarioDoCeuApp(initError: initError));
}

class DiarioDoCeuApp extends StatelessWidget {
  final String? initError;
  const DiarioDoCeuApp({super.key, this.initError});

  @override
  Widget build(BuildContext context) {
    Widget home;
    if (initError != null) {
      home = Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Erro ao inicializar o app',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(initError!, textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54)),
              ],
            ),
          ),
        ),
      );
    } else {
      final session = Supabase.instance.client.auth.currentSession;
      home = session != null ? const HomeScreen() : const AuthScreen();
    }

    return MaterialApp(
      title: 'Diário do Céu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D1B2A),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: home,
    );
  }
}
