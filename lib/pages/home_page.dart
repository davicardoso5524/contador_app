// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'more_flavors_page.dart';
import 'report_range_page.dart';
import 'report_page.dart';
import 'stock_page.dart';
import '../widgets/app_header.dart';
import '../widgets/flavor_card.dart';
import '../widgets/footer_menu.dart';
import '../services/counter_service.dart';
import '../services/inventory_service.dart';
import '../models/counter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final CounterService _service = CounterService();
  final InventoryService _inventoryService = InventoryService();
  bool _loading = true;
  List<CounterModel> _counters = [];
  Map<String, int> _todayTotals = {};
  late PageController _pageController;
  final GlobalKey<State> _moreFlavorsKey = GlobalKey<State>();

  // Data atualmente exibida (pode ser hoje ou uma data do relatório)
  late DateTime _currentDisplayDate;
  late DateTime _previousDisplayDate;

  // Contadores dos novos sabores (Mais Sabores)
  int _churritos = 0;
  int _churrosDoceLeite = 0;
  int _chocolate = 0;
  int _kibes = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();
    _initService();
  }

  @override
  void dispose() {
    _pageController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Quando o app volta ao primeiro plano, verifica se mudou de dia
      _checkAndApplySalesIfNewDay();
    }
  }

  /// Verifica se mudou de dia e aplica vendas automaticamente
  Future<void> _checkAndApplySalesIfNewDay() async {
    final now = DateTime.now();

    // Se é um dia diferente de _currentDisplayDate, mostra o diálogo
    if (!_isSameDay(_currentDisplayDate, now)) {
      _previousDisplayDate = _currentDisplayDate;
      _currentDisplayDate = now;

      if (mounted) {
        await _showApplySalesDialog(_currentDisplayDate);
      }
    }

    // Sempre recarrega dados ao retomar
    _refresh();
  }

  /// Mostra diálogo para aplicar vendas manualmente (botão no header)
  Future<void> _applyTodaySales() async {
    await _showApplySalesDialog(DateTime.now());
  }

  Future<void> _initService() async {
    await _service.init();
    await _inventoryService.init();
    _currentDisplayDate = DateTime.now();
    _previousDisplayDate = DateTime.now();
    _todayTotals = _service.totalsForSingleDate(_currentDisplayDate);

    if (!mounted) return;
    setState(() {
      _counters = _service.counters;
      _loading = false;
    });

    // Após carregar a UI, verifica se há vendas pendentes de aplicar
    // Isso é feito assincronamente para não bloquear a inicialização
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingSalesAsync();
    });
  }

  /// Verifica assincronamente se há vendas pendentes de aplicar
  Future<void> _checkPendingSalesAsync() async {
    try {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayHasSales = _service
          .totalsForSingleDate(yesterday)
          .values
          .any((qty) => qty > 0);
      final yesterdayAlreadyApplied = await _inventoryService
          .isDailyDeductionApplied(yesterday);

      if (yesterdayHasSales && !yesterdayAlreadyApplied && mounted) {
        // Mostra diálogo para aplicar vendas de ontem
        await _showApplySalesDialog(yesterday);
      }
    } catch (e) {
      // Ignora erros nesta verificação
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _counters = _service.counters;
      // Mantém a data atual (pode ser hoje ou uma data selecionada no relatório)
      _todayTotals = _service.totalsForSingleDate(_currentDisplayDate);
    });
  }

  Future<void> _increment(String id) async {
    try {
      // Incrementa para a data atualmente exibida (não apenas hoje)
      await _service.applyDelta(id, 1, _currentDisplayDate);
      // Não chama _refresh() aqui - apenas atualiza o display sem I/O
      setState(() {
        _todayTotals = _service.totalsForSingleDate(_currentDisplayDate);
      });
    } catch (e) {
      // Erro ignorado
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
        displayDate: _currentDisplayDate,
        moreFlavorsData: {
          'churritos': _churritos,
          'doce-de-leite': _churrosDoceLeite,
          'chocolate': _chocolate,
          'kibes': _kibes,
        },
        onUpdateMoreFlavors: (Map<String, int> data) {
          setState(() {
            _churritos = data['churritos'] ?? 0;
            _churrosDoceLeite = data['doce-de-leite'] ?? 0;
            _chocolate = data['chocolate'] ?? 0;
            _kibes = data['kibes'] ?? 0;
          });
          // Atualiza o MoreFlavorsPage também
          final state = _moreFlavorsKey.currentState;
          if (state != null) {
            // Força rebuild do MoreFlavorsPage
            state.setState(() {});
          }
        },
      ),
    );
  }

  void _openReport() async {
    // → ReportPage (mostrar por dia + resumo) com todos os 10 sabores listados
    // Primeiro, abre a tela de seleção de intervalo
    final result = await Navigator.of(context).push<Map<String, DateTime>>(
      MaterialPageRoute(builder: (_) => const ReportRangePage()),
    );

    if (result == null) return;

    final startDate = result['startDate'] as DateTime;
    final endDate = result['endDate'] as DateTime;

    // Navega para o relatório com o intervalo selecionado
    if (!mounted) return;
    final reportResult = await Navigator.of(context).push<DateTime>(
      MaterialPageRoute(
        builder: (_) => ReportPage(
          startDate: startDate,
          endDate: endDate,
          moreFlavorsData: {
            'churritos': _churritos,
            'doce-de-leite': _churrosDoceLeite,
            'chocolate': _chocolate,
            'kibes': _kibes,
          },
        ),
      ),
    );

    // Se voltou com uma data selecionada, atualiza _currentDisplayDate
    if (reportResult != null) {
      _previousDisplayDate = _currentDisplayDate;
      _currentDisplayDate = reportResult;

      // Se a data foi diferente, mostra o diálogo de confirmação
      if (!_isSameDay(_previousDisplayDate, _currentDisplayDate)) {
        if (!mounted) return;
        await _showApplySalesDialog(_currentDisplayDate);
      }
    }
  }

  Future<void> _openStock() async {
    // Abre a tela de estoque
    final result = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const StockPage()));

    // Se algo foi alterado no estoque, atualiza o estado
    if (result == true) {
      _refresh();
    }
  }

  /// Mostra diálogo de confirmação para aplicar vendas ao estoque
  Future<void> _showApplySalesDialog(DateTime date) async {
    if (!mounted) return;

    final isToday = _isToday(date);
    final dateFormatted = _formatDate(date);

    final result = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Aplicar Vendas ao Estoque'),
        content: Text(
          'Aplicar as vendas de $dateFormatted ao estoque? '
          '(Isso vai subtrair as quantidades do estoque desta data).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 0), // Cancelar
            child: const Text('Cancelar'),
          ),
          if (!isToday)
            TextButton(
              onPressed: () => Navigator.pop(context, 1), // Aplicar sempre
              child: const Text('Aplicar Sempre'),
            ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 2), // Aplicar
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );

    if (result == null || result == 0) {
      return; // Cancelado
    }

    // Aplica as vendas ao estoque
    try {
      final movements = await _inventoryService.applyDailySalesToStock(date);

      // Conta quantos produtos foram efetivamente atualizados
      final updatedCount = movements
          .where((m) => m['unmatched'] != true)
          .length;

      if (!mounted) return;

      // Mostra feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updatedCount == 0
                ? 'Nenhum produto foi atualizado nesta data.'
                : '$updatedCount produto(s) atualizado(s) no estoque!',
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      // Recarrega o inventário
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao aplicar vendas: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Verifica se uma data é "hoje"
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Formata data como dd/MM/yyyy
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  /// Verifica se duas datas são o mesmo dia
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
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
            AppHeader(
              title: 'CONTADOR DE COXINHA',
              onApplySales: _applyTodaySales,
            ),
            const Divider(height: 1, thickness: 1),
            Expanded(
              child: PageView(
                controller: _pageController,
                children: [
                  // Página 1: Sabores de Coxinha
                  Padding(
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
                  // Página 2: Mais Sabores
                  MoreFlavorsPage(
                    key: _moreFlavorsKey,
                    churritos: _churritos,
                    doceDeLeite: _churrosDoceLeite,
                    chocolate: _chocolate,
                    kibes: _kibes,
                    counterService: _service,
                    currentDate: _currentDisplayDate,
                    onCountersChanged: (data) {
                      setState(() {
                        _churritos = data['churritos'] ?? 0;
                        _churrosDoceLeite = data['doce-de-leite'] ?? 0;
                        _chocolate = data['chocolate'] ?? 0;
                        _kibes = data['kibes'] ?? 0;
                      });
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),
            FooterMenu(
              onHome: () {
                // Vai para a primeira página (sabores de coxinha)
                _pageController.animateToPage(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              onMinus: () => _openAdjustSheet(false),
              onStock: _openStock,
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
  final DateTime displayDate;
  final Map<String, int>? moreFlavorsData;
  final Function(Map<String, int>)? onUpdateMoreFlavors;

  const _AdjustSheet({
    required this.service,
    required this.isIncrement,
    required this.onDone,
    required this.displayDate,
    this.moreFlavorsData,
    this.onUpdateMoreFlavors,
  });

  @override
  State<_AdjustSheet> createState() => _AdjustSheetState();
}

class _AdjustSheetState extends State<_AdjustSheet> {
  String? _selectedId;
  int _quantity = 1;
  List<CounterModel> _items = [];

  // Dados dos novos sabores
  late Map<String, int> _moreFlavorsData;
  bool _isMoreFlavor = false;

  @override
  void initState() {
    super.initState();
    _items = widget.service.counters;
    _moreFlavorsData = widget.moreFlavorsData ?? {};
    if (_items.isNotEmpty) _selectedId = _items.first.id;
  }

  Future<void> _apply() async {
    if (_selectedId == null) return;
    final delta = widget.isIncrement ? _quantity : -_quantity;

    // Se for um novo sabor (Mais Sabores)
    if (_isMoreFlavor) {
      final currentValue = _moreFlavorsData[_selectedId] ?? 0;
      final newValue = currentValue + delta;

      // Não permite valores negativos
      if (newValue < 0) return;

      _moreFlavorsData[_selectedId!] = newValue;
      if (mounted && widget.onUpdateMoreFlavors != null) {
        widget.onUpdateMoreFlavors!(_moreFlavorsData);

        // Atualiza o MoreFlavorsPage imediatamente
        // Precisamos acessar o widget de Home para conseguir a key
        if (context.mounted) {
          // Espera um frame para garantir a execução
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.pop(context);
            }
          });
          return;
        }
      }
      if (!mounted) return;
      Navigator.pop(context);
      return;
    }

    // Verifica se a operação vai resultar em valor negativo
    if (!widget.isIncrement) {
      final currentItem = _items.firstWhere((item) => item.id == _selectedId);
      if (currentItem.value < _quantity) {
        return;
      }
    }

    try {
      await widget.service.applyDelta(_selectedId!, delta, widget.displayDate);
      if (!mounted) return;
      Navigator.pop(context);
      if (widget.onDone != null) await widget.onDone!();
    } catch (e) {
      // Erro ignorado
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
                items: [
                  // Sabores de Coxinha
                  ..._items.map(
                    (c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(
                        c.name,
                        style: TextStyle(fontSize: screenWidth < 360 ? 14 : 16),
                      ),
                    ),
                  ),
                  // Divider visual
                  if (_moreFlavorsData.isNotEmpty)
                    DropdownMenuItem(
                      enabled: false,
                      child: Divider(color: Colors.grey[400], thickness: 1),
                    ),
                  // Novos Sabores (Mais Sabores)
                  if (_moreFlavorsData.isNotEmpty)
                    DropdownMenuItem(
                      value: 'churritos',
                      child: Text(
                        'Churritos',
                        style: TextStyle(fontSize: screenWidth < 360 ? 14 : 16),
                      ),
                    ),
                  if (_moreFlavorsData.isNotEmpty)
                    DropdownMenuItem(
                      value: 'doce-de-leite',
                      child: Text(
                        'Doce de Leite',
                        style: TextStyle(fontSize: screenWidth < 360 ? 14 : 16),
                      ),
                    ),
                  if (_moreFlavorsData.isNotEmpty)
                    DropdownMenuItem(
                      value: 'chocolate',
                      child: Text(
                        'Chocolate',
                        style: TextStyle(fontSize: screenWidth < 360 ? 14 : 16),
                      ),
                    ),
                  if (_moreFlavorsData.isNotEmpty)
                    DropdownMenuItem(
                      value: 'kibes',
                      child: Text(
                        'Kibes',
                        style: TextStyle(fontSize: screenWidth < 360 ? 14 : 16),
                      ),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _selectedId = v;
                      _isMoreFlavor = _moreFlavorsData.containsKey(v);
                    });
                  }
                },
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
                  itemCount:
                      _items.length +
                      (_moreFlavorsData.isEmpty
                          ? 0
                          : 1 + _moreFlavorsData.length),
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    // Sabores de Coxinha
                    if (i < _items.length) {
                      final it = _items[i];
                      // Mostra o valor do dia de hoje em vez do total acumulado
                      final todayTotals = widget.service.totalsForSingleDate(
                        DateTime.now(),
                      );
                      final todayValue = todayTotals[it.id] ?? 0;

                      return ListTile(
                        title: Text(
                          it.name,
                          style: TextStyle(
                            fontSize: screenWidth < 360 ? 14 : 16,
                          ),
                        ),
                        subtitle: Text(
                          'Hoje: $todayValue',
                          style: TextStyle(
                            fontSize: screenWidth < 360 ? 12 : 14,
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: screenWidth < 360 ? 8 : 16,
                          vertical: screenWidth < 360 ? 4 : 8,
                        ),
                        dense: screenWidth < 360,
                        onTap: () => setState(() {
                          _selectedId = it.id;
                          _isMoreFlavor = false;
                        }),
                      );
                    }

                    // Seção "Mais Sabores"
                    final moreFlavorIndex = i - _items.length;

                    if (moreFlavorIndex == 0) {
                      // Header para "Mais Sabores"
                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth < 360 ? 8 : 16,
                          vertical: 8,
                        ),
                        child: Text(
                          'MAIS SABORES',
                          style: TextStyle(
                            fontSize: screenWidth < 360 ? 12 : 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                      );
                    }

                    // Sabores de Mais Sabores
                    final flavorIndex = moreFlavorIndex - 1;
                    final flavorNames = [
                      'Churritos',
                      'Doce de Leite',
                      'Chocolate',
                      'Kibes',
                    ];
                    final flavorKeys = [
                      'churritos',
                      'doce-de-leite',
                      'chocolate',
                      'kibes',
                    ];

                    if (flavorIndex >= 0 && flavorIndex < flavorKeys.length) {
                      final key = flavorKeys[flavorIndex];
                      final value = _moreFlavorsData[key] ?? 0;

                      return ListTile(
                        title: Text(
                          flavorNames[flavorIndex],
                          style: TextStyle(
                            fontSize: screenWidth < 360 ? 14 : 16,
                          ),
                        ),
                        subtitle: Text(
                          'Total: $value',
                          style: TextStyle(
                            fontSize: screenWidth < 360 ? 12 : 14,
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: screenWidth < 360 ? 8 : 16,
                          vertical: screenWidth < 360 ? 4 : 8,
                        ),
                        dense: screenWidth < 360,
                        onTap: () => setState(() {
                          _selectedId = key;
                          _isMoreFlavor = true;
                        }),
                      );
                    }

                    return const SizedBox.shrink();
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
