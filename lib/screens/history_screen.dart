import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/observation_model.dart';
import '../services/observation_service.dart';
import 'observation_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<ObservationModel> _all = [];
  List<ObservationModel> _filtered = [];
  bool _loading = true;
  String _search = '';
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  String? _error;

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await Supabase.instance.client
          .from('observations')
          .select()
          .order('data', ascending: false);
      final list = (data as List)
          .map((e) => ObservationModel.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          _all = list;
          _applyFilters();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    _filtered = _all.where((o) {
      final matchSearch = _search.isEmpty ||
          o.titulo.toLowerCase().contains(_search.toLowerCase());
      final matchDate = _dateRange == null ||
          (o.data.isAfter(_dateRange!.start.subtract(const Duration(days: 1))) &&
              o.data.isBefore(_dateRange!.end.add(const Duration(days: 1))));
      return matchSearch && matchDate;
    }).toList();
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (range != null) {
      setState(() {
        _dateRange = range;
        _applyFilters();
      });
    }
  }

  Future<bool?> _confirmDelete(ObservationModel obs) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir registro?'),
        content: Text(
            'Tem certeza que deseja excluir "${obs.titulo}"? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteObservation(ObservationModel obs) async {
    try {
      await ObservationService.delete(obs.id, obs.fotoUrl);
      setState(() {
        _all.removeWhere((o) => o.id == obs.id);
        _applyFilters();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registro excluído.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao excluir: $e'),
              backgroundColor: Colors.red),
        );
        // Recarrega para restaurar estado consistente
        _fetch();
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _search = '';
      _dateRange = null;
      _applyFilters();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: 'Filtrar por data',
            onPressed: _pickDateRange,
          ),
          if (_dateRange != null || _search.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              tooltip: 'Limpar filtros',
              onPressed: _clearFilters,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar por objeto observado...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() {
                _search = v;
                _applyFilters();
              }),
            ),
          ),
          if (_dateRange != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.date_range, size: 16, color: Colors.amber),
                  const SizedBox(width: 6),
                  Text(
                    '${_fmt(_dateRange!.start)} → ${_fmt(_dateRange!.end)}',
                    style: const TextStyle(color: Colors.amber, fontSize: 12),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.cloud_off_outlined,
                                  size: 56, color: Colors.white30),
                              const SizedBox(height: 16),
                              Text(
                                'Erro ao carregar registros',
                                style: Theme.of(context).textTheme.titleMedium,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                style: const TextStyle(color: Colors.white38, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              FilledButton.icon(
                                onPressed: _fetch,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Tentar novamente'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _filtered.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.nightlight_round,
                                      size: 56, color: Colors.white24),
                                  const SizedBox(height: 16),
                                  Text(
                                    _search.isNotEmpty || _dateRange != null
                                        ? 'Nenhum registro\ncorresponde ao filtro.'
                                        : 'Nenhum registro ainda.\nComece observando o céu! ✨',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(color: Colors.white54),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetch,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _filtered.length,
                              itemBuilder: (_, i) {
                                final obs = _filtered[i];
                                return Dismissible(
                                  key: ValueKey(obs.id),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    margin: const EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade700,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.delete_outline,
                                        color: Colors.white, size: 28),
                                  ),
                                  confirmDismiss: (_) => _confirmDelete(obs),
                                  onDismissed: (_) => _deleteObservation(obs),
                                  child: _ObservationTile(
                                    observation: obs,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ObservationDetailScreen(
                                          observation: obs,
                                        ),
                                      ),
                                    ),
                                    onDelete: () => _confirmDelete(obs).then(
                                      (confirmed) {
                                        if (confirmed == true) {
                                          _deleteObservation(obs);
                                        }
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _ObservationTile extends StatelessWidget {
  final ObservationModel observation;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _ObservationTile({
    required this.observation,
    required this.onTap,
    this.onDelete,
  });

  Map<String, String> get _authHeaders {
    final token =
        Supabase.instance.client.auth.currentSession?.accessToken ?? '';
    return {'Authorization': 'Bearer $token'};
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: observation.fotoUrl != null
              ? Image.network(
                  observation.fotoUrl!,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  headers: _authHeaders,
                  errorBuilder: (_, __, ___) => _placeholder(),
                )
              : _placeholder(),
        ),
        title: Text(observation.titulo,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(_fmt(observation.data)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chevron_right),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.redAccent, size: 20),
                tooltip: 'Excluir',
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 56,
        height: 56,
        color: Colors.grey.shade800,
        child: const Icon(Icons.photo, color: Colors.white30),
      );

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
