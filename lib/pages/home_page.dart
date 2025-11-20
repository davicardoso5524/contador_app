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
    setState(() {
      _counters = _service.counters;
      _todayTotals = _service.totalsForSingleDate(DateTime.now());
    });
  }

  Future<void> _increment(String id) async {
    try {
      await _service.applyDelta(id, 1);
      await _refresh();
      if (!mounted) return;
      final name = _counters.firstWhere((c) => c.id == id).name;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('+1 -> $name'),
          duration: const Duration(milliseconds: 600),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  void _openAdjustSheet(bool isIncrement) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AdjustSheet(
        service: _service,
        isIncrement: isIncrement,
        onDone: _refresh,
      ),
    );
  }

  void _openReport() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ReportPage()));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Pega o tamanho da tela para calcular responsividade
    final screenWidth = MediaQuery.of(context).size.width;
    // final screenHeight = MediaQuery.of(context).size.height;

    // Define número de colunas baseado na largura da tela
    int crossAxisCount = 2;
    double childAspectRatio = 0.95;
    double horizontalPadding = 12.0;
    double verticalPadding = 16.0;
    double spacing = 18.0;

    // Ajustes para telas pequenas (como A06)
    if (screenWidth < 360) {
      // Telas muito pequenas
      crossAxisCount = 2;
      childAspectRatio = 0.85;
      horizontalPadding = 8.0;
      verticalPadding = 12.0;
      spacing = 12.0;
    } else if (screenWidth < 400) {
      // Telas pequenas
      crossAxisCount = 2;
      childAspectRatio = 0.90;
      horizontalPadding = 10.0;
      verticalPadding = 14.0;
      spacing = 14.0;
    } else if (screenWidth > 600) {
      // Tablets
      crossAxisCount = 3;
      childAspectRatio = 1.0;
    }

    final colors = [
      Colors.amber,
      Colors.deepOrange,
      const Color(0xFF8B5A2B),
      Colors.blue,
      Colors.red,
      Colors.green,
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(title: 'LOUCOS POR COXINHA'),
            const Divider(height: 1, thickness: 1),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: GridView.builder(
                  itemCount: _counters.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: spacing,
                    crossAxisSpacing: spacing,
                    childAspectRatio: childAspectRatio,
                  ),
                  itemBuilder: (context, index) {
                    final c = _counters[index];
                    return FlavorCard(
                      flavorName: c.name,
                      color: colors[index % colors.length],
                      value: _todayTotals[c.id] ?? 0,
                      onTap: () => _increment(c.id),
                    );
                  },
                ),
              ),
            ),
            const Divider(height: 1, thickness: 1),
            FooterMenu(
              onHome: () {},
              onMinus: () => _openAdjustSheet(false),
              onPlus: () => _openAdjustSheet(true),
              onReport: _openReport,
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet para ajustar contagens (increment/decrement em lote)
class _AdjustSheet extends StatefulWidget {
  final CounterService service;
  final bool isIncrement;
  final Future<void> Function()? onDone;

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

    // Verifica se a operação vai resultar em valor negativo
    if (!widget.isIncrement) {
      final currentItem = _items.firstWhere((item) => item.id == _selectedId);
      if (currentItem.value < _quantity) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Não é possível remover $_quantity. Valor atual: ${currentItem.value}',
            ),
            duration: const Duration(milliseconds: 1500),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    try {
      await widget.service.applyDelta(_selectedId!, delta);
      if (!mounted) return;
      Navigator.pop(context);
      if (widget.onDone != null) await widget.onDone!();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.isIncrement ? 'Adicionado' : 'Removido'} $_quantity',
          ),
          duration: const Duration(milliseconds: 800),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isIncrement ? 'Adicionar' : 'Diminuir';
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Ajusta padding para telas menores
    final horizontalPadding = screenWidth < 360 ? 12.0 : 16.0;
    final topPadding = screenWidth < 360 ? 8.0 : 12.0;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + topPadding,
          left: horizontalPadding,
          right: horizontalPadding,
          top: topPadding,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: screenHeight * 0.75,
            minHeight: screenHeight * 0.3,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: screenWidth < 360 ? 18 : null,
                ),
              ),
              SizedBox(height: screenWidth < 360 ? 6 : 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedId,
                items: _items
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(
                          c.name,
                          style: TextStyle(
                            fontSize: screenWidth < 360 ? 14 : 16,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedId = v),
                decoration: const InputDecoration(
                  labelText: 'Sabor',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                isDense: screenWidth < 360,
              ),
              SizedBox(height: screenWidth < 360 ? 6 : 8),
              Row(
                children: [
                  IconButton(
                    onPressed: () => setState(() {
                      if (_quantity > 1) _quantity--;
                    }),
                    icon: Icon(
                      Icons.remove_circle_outline,
                      size: screenWidth < 360 ? 28 : 32,
                    ),
                    padding: EdgeInsets.all(screenWidth < 360 ? 4 : 8),
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$_quantity',
                    style: TextStyle(
                      fontSize: screenWidth < 360 ? 16 : 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => setState(() => _quantity++),
                    icon: Icon(
                      Icons.add_circle_outline,
                      size: screenWidth < 360 ? 28 : 32,
                    ),
                    padding: EdgeInsets.all(screenWidth < 360 ? 4 : 8),
                    constraints: const BoxConstraints(),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _apply,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth < 360 ? 12 : 16,
                        vertical: screenWidth < 360 ? 8 : 12,
                      ),
                    ),
                    child: Text(
                      'Confirmar',
                      style: TextStyle(fontSize: screenWidth < 360 ? 13 : 14),
                    ),
                  ),
                ],
              ),
              SizedBox(height: screenWidth < 360 ? 6 : 8),
              Expanded(
                child: ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final it = _items[i];
                    // Mostra o valor do dia de hoje em vez do total acumulado
                    final todayTotals = widget.service.totalsForSingleDate(
                      DateTime.now(),
                    );
                    final todayValue = todayTotals[it.id] ?? 0;

                    return ListTile(
                      title: Text(
                        it.name,
                        style: TextStyle(fontSize: screenWidth < 360 ? 14 : 16),
                      ),
                      subtitle: Text(
                        'Hoje: $todayValue',
                        style: TextStyle(fontSize: screenWidth < 360 ? 12 : 14),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: screenWidth < 360 ? 8 : 16,
                        vertical: screenWidth < 360 ? 4 : 8,
                      ),
                      dense: screenWidth < 360,
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
