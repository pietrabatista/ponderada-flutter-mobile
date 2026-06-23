import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/observation_model.dart';
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

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final data = await Supabase.instance.client
          .from('observations')
          .select()
          .order('data', ascending: false);
      final list = (data as List)
          .map((e) => ObservationModel.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _all = list;
        _applyFilters();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar: $e'), backgroundColor: Colors.red),
        );
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
                : _filtered.isEmpty
                    ? const Center(child: Text('Nenhum registro encontrado.'))
                    : RefreshIndicator(
                        onRefresh: _fetch,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) => _ObservationTile(
                            observation: _filtered[i],
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ObservationDetailScreen(
                                  observation: _filtered[i],
                                ),
                              ),
                            ),
                          ),
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

  const _ObservationTile({required this.observation, required this.onTap});

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
                  errorBuilder: (_, __, ___) => _placeholder(),
                )
              : _placeholder(),
        ),
        title: Text(observation.titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(_fmt(observation.data)),
        trailing: const Icon(Icons.chevron_right),
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
