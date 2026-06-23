import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'new_observation_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  /// Incrementado sempre que uma observação é criada ou excluída.
  /// Tanto HistoryScreen quanto HomeScreen (registros recentes) ouvem este notifier.
  final _observationsRefresh = ValueNotifier<int>(0);

  void _onObservationsChanged() => _observationsRefresh.value++;

  void _onTap(int index) {
    if (index == 1) _onObservationsChanged(); // aba Histórico: sempre recarrega
    setState(() => _currentIndex = index);
  }

  @override
  void dispose() {
    _observationsRefresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(refreshTrigger: _observationsRefresh),
          HistoryScreen(
            refreshTrigger: _observationsRefresh,
            onObservationChanged: _onObservationsChanged,
          ),
          const ProfileScreen(),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const NewObservationScreen()),
                );
                _onObservationsChanged(); // atualiza após criar
              },
              tooltip: 'Novo registro',
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTap,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Histórico',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
