import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/notification_service.dart';
import 'auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _issEnabled = true;
  bool _apodEnabled = true;
  bool _loadingPrefs = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final iss = await NotificationService.isIssEnabled();
    final apod = await NotificationService.isApodEnabled();
    if (mounted) {
      setState(() {
        _issEnabled = iss;
        _apodEnabled = apod;
        _loadingPrefs = false;
      });
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair'),
        content: const Text('Deseja encerrar a sessão?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
          (_) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? 'Usuário';

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: _loadingPrefs
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Avatar + email
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Text(
                          email.isNotEmpty ? email[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 32, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        email,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
                Text(
                  'NOTIFICAÇÕES',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white54,
                        letterSpacing: 1.2,
                      ),
                ),
                const SizedBox(height: 8),

                // Toggle ISS
                Card(
                  child: SwitchListTile(
                    secondary: const CircleAvatar(
                      backgroundColor: Colors.blueGrey,
                      child: Icon(Icons.rocket_launch_outlined, color: Colors.white, size: 20),
                    ),
                    title: const Text('Passagem da ISS'),
                    subtitle: const Text('Avisa 5 min antes da ISS passar'),
                    value: _issEnabled,
                    onChanged: (v) async {
                      setState(() => _issEnabled = v);
                      await NotificationService.setIssEnabled(v);
                    },
                  ),
                ),

                // Toggle APOD
                Card(
                  child: SwitchListTile(
                    secondary: const CircleAvatar(
                      backgroundColor: Colors.indigo,
                      child: Icon(Icons.photo_outlined, color: Colors.white, size: 20),
                    ),
                    title: const Text('Foto do Dia (APOD)'),
                    subtitle: const Text('Notificação diária às 9h'),
                    value: _apodEnabled,
                    onChanged: (v) async {
                      setState(() => _apodEnabled = v);
                      await NotificationService.setApodEnabled(v);
                    },
                  ),
                ),

                const SizedBox(height: 32),
                Text(
                  'CONTA',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white54,
                        letterSpacing: 1.2,
                      ),
                ),
                const SizedBox(height: 8),

                // Logout
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.redAccent,
                      child: Icon(Icons.logout, color: Colors.white, size: 20),
                    ),
                    title: const Text('Sair da conta'),
                    onTap: _logout,
                  ),
                ),
              ],
            ),
    );
  }
}
