// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import '../widgets/app_header.dart';
import '../widgets/flavor_card.dart';
import '../widgets/footer_menu.dart';
import '../services/counter_service.dart';
import '../models/counter.dart';
import 'report_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final CounterService _service = CounterService();
  bool _loading = true;
  List<CounterModel> _counters = [];
  Map<String, int> _todayTotals = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initService();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // app voltou ao foreground — recalcula totais do dia
      _refresh();
    }
  }

  Future<void> _initService() async {
    await _service.init();
    _todayTotals = _service.totalsForSingleDate(DateTime.now());
    if (!mounted) return;
    setState(() {
      _counters = _service.counters;
      _loading = false;
    });
  }

  Future<void> _refresh() async {
    // reload from service
    setState(() {
      _counters = _service.counters;
      _todayTotals = _service.totalsForSingleDate(DateTime.now());
    });
  }

  // incrementa +1 (tap direto em card)
  Future<void> _increment(String id) async {
    try {
      await _service.applyDelta(id, 1);
      await _refresh();
      if (!mounted) return;
      final name = _counters.firstWhere((c) => c.id == id).name;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('+1 -> $name'), duration: const Duration(milliseconds: 600)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  // abrir sheet para ajustar (delta positivo ou negativo)
  void _openAdjustSheet(bool isIncrement) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AdjustSheet(
        service: _service,
        isIncrement: isIncrement,
        onDone: _refresh, // agora _refresh retorna Future<void>
      ),
    );
  }

  void _openReport() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReportPage()));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final colors = [
      Colors.amber,
      Colors.deepOrange,
      const Color(0xFF8B5A2B),
      Colors.blue,
      Colors.red,
      Colors.green
    ];

    return Scaffold(
      body: Column(
        children: [
          const AppHeader(title: 'LOUCOS POR COXINHA'),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: GridView.builder(
                itemCount: _counters.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // suas 2 colunas
                  mainAxisSpacing: 18,
                  crossAxisSpacing: 18,
                  childAspectRatio: 0.95,
                ),
                itemBuilder: (context, index) {
                  final c = _counters[index];
                  return FlavorCard(
                    flavorName: c.name,
                    color: colors[index % colors.length],
                    // ANTES: value: c.value,
                    // AGORA: valor mostrado é o total do DIA (hoje)
                    value: _todayTotals[c.id] ?? 0,
                    onTap: () => _increment(c.id),
                  );
                },
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1),
          FooterMenu(
            onHome: () {
              // nada por enquanto
            },
            onMinus: () => _openAdjustSheet(false),
            onPlus: () => _openAdjustSheet(true),
            onReport: _openReport,
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet para ajustar contagens (increment/decrement em lote)
class _AdjustSheet extends StatefulWidget {
  final CounterService service;
  final bool isIncrement;
  final Future<void> Function()? onDone; // <-- changed to return Future<void>

  const _AdjustSheet({
    required this.service,
    required this.isIncrement,
    required this.onDone,
  });

  @override
  State<_AdjustSheet> createState() => _AdjustSheetState();
}

class _AdjustSheetState extends State<_AdjustSheet> {
  String? _selectedId;
  int _quantity = 1;
  List<CounterModel> _items = [];

  @override
  void initState() {
    super.initState();
    _items = widget.service.counters;
    if (_items.isNotEmpty) _selectedId = _items.first.id;
  }

  Future<void> _apply() async {
    if (_selectedId == null) return;
    final delta = widget.isIncrement ? _quantity : -_quantity;
    try {
      await widget.service.applyDelta(_selectedId!, delta);
      if (!mounted) return;
      Navigator.pop(context);
      if (widget.onDone != null) await widget.onDone!();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.isIncrement ? 'Adicionado' : 'Removido'} $_quantity'), duration: const Duration(milliseconds: 800)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isIncrement ? 'Adicionar' : 'Diminuir';
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 12, left: 16, right: 16, top: 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedId, // <- changed to initialValue (deprecated fix)
                items: _items.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                onChanged: (v) => setState(() => _selectedId = v),
                decoration: const InputDecoration(labelText: 'Sabor'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: () => setState(() {
                      if (_quantity > 1) _quantity--;
                    }),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text('$_quantity', style: const TextStyle(fontSize: 18)),
                  IconButton(
                    onPressed: () => setState(() => _quantity++),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  const Spacer(),
                  ElevatedButton(onPressed: _apply, child: const Text('Confirmar')),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final it = _items[i];
                    return ListTile(
                      title: Text(it.name),
                      subtitle: Text('Total atual: ${it.value}'),
                      onTap: () => setState(() => _selectedId = it.id),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
