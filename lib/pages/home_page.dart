// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'more_flavors_page.dart';
import 'report_range_page.dart';
import 'report_page.dart';
import 'expiry_product_page.dart';
import '../widgets/app_header.dart';
import '../widgets/flavor_card.dart';
import '../widgets/footer_menu.dart';
import '../services/counter_service.dart';
import '../services/notification_service.dart';
import '../services/expiry_service.dart';
import '../models/counter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final CounterService _service = CounterService();
  final NotificationService _notificationService = NotificationService();
  final ExpiryService _expiryService = ExpiryService();
  
  bool _loading = true;
  List<CounterModel> _counters = [];
  Map<String, int> _todayTotals = {};
  late PageController _pageController;
  final GlobalKey<State> _moreFlavorsKey = GlobalKey<State>();

  late DateTime _currentDisplayDate;
  int _churritos = 0;
  int _churrosDoceLeite = 0;
  int _chocolate = 0;
  int _kibes = 0;
  int _charque = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();
    _initAllServices();
  }

  Future<void> _initAllServices() async {
    await _service.init();
    _currentDisplayDate = DateTime.now();
    await _checkNewDayAndReset();
    await _loadMoreFlavors();
    
    try {
      await _notificationService.init();
      await _expiryService.checkAndNotify();
    } catch (e) {
      debugPrint('Erro nas notificações: $e');
    }

    if (!mounted) return;
    setState(() {
      _counters = _service.counters;
      _loading = false;
    });

    _checkAlarmPermission();
  }

  Future<void> _checkAlarmPermission() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('asked_alarm_permission') ?? false) return;
    
    final canSchedule = await _notificationService.canScheduleExactAlarms();
    if (!canSchedule && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Permissão Necessária'),
          content: const Text(
            'Para que os alertas de validade funcionem na hora exata, '
            'é necessário permitir o agendamento de alarmes e lembretes.'
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await prefs.setBool('asked_alarm_permission', true);
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Não perguntar novamente'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Pular'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _notificationService.requestExactAlarmsPermission();
              },
              child: const Text('Permitir'),
            ),
          ],
        ),
      );
    }
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
      _checkNewDayAndReset();
      _expiryService.checkAndNotify();
    }
  }

  Future<void> _loadMoreFlavors() async {
    final c = await _service.getMoreFlavorCountForDate('churritos', _currentDisplayDate);
    final d = await _service.getMoreFlavorCountForDate('doce-de-leite', _currentDisplayDate);
    final ch = await _service.getMoreFlavorCountForDate('chocolate', _currentDisplayDate);
    final k = await _service.getMoreFlavorCountForDate('kibes', _currentDisplayDate);
    final cq = await _service.getMoreFlavorCountForDate('charque', _currentDisplayDate);
    
    if (!mounted) return;
    setState(() {
      _churritos = c;
      _churrosDoceLeite = d;
      _chocolate = ch;
      _kibes = k;
      _charque = cq;
      _todayTotals = _service.totalsForSingleDate(_currentDisplayDate);
    });
  }

  Future<void> _checkNewDayAndReset() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final lastOpenStr = prefs.getString('last_open_date');
    final todayStr = "${now.year}-${now.month}-${now.day}";

    if (lastOpenStr != todayStr) {
      await prefs.setString('last_open_date', todayStr);
      await _service.resetAll();
      _currentDisplayDate = now;
      await _loadMoreFlavors();
    } else {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _counters = _service.counters;
      _todayTotals = _service.totalsForSingleDate(_currentDisplayDate);
    });
  }

  Future<void> _increment(String id) async {
    try {
      await _service.applyDelta(id, 1, _currentDisplayDate);
      setState(() {
        _todayTotals = _service.totalsForSingleDate(_currentDisplayDate);
      });
    } catch (e) {}
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
          'charque': _charque,
        },
        onUpdateMoreFlavors: (Map<String, int> data) {
          setState(() {
            _churritos = data['churritos'] ?? 0;
            _churrosDoceLeite = data['doce-de-leite'] ?? 0;
            _chocolate = data['chocolate'] ?? 0;
            _kibes = data['kibes'] ?? 0;
            _charque = data['charque'] ?? 0;
          });
          final state = _moreFlavorsKey.currentState;
          if (state != null) {
            state.setState(() {});
          }
        },
      ),
    );
  }

  void _openReport() async {
    final result = await Navigator.of(context).push<Map<String, DateTime>>(
      MaterialPageRoute(builder: (_) => const ReportRangePage()),
    );
    if (result == null) return;
    final startDate = result['startDate'] as DateTime;
    final endDate = result['endDate'] as DateTime;
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
            'charque': _charque,
          },
        ),
      ),
    );
    if (reportResult != null) {
      setState(() {
        _currentDisplayDate = reportResult;
        _todayTotals = _service.totalsForSingleDate(_currentDisplayDate);
      });
      _loadMoreFlavors();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = screenWidth > 600 ? 3 : 2;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(title: 'CONTADOR DE COXINHA'),
            const Divider(height: 1, thickness: 1),
            Expanded(
              child: PageView(
                controller: _pageController,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: GridView.builder(
                      itemCount: _counters.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 18,
                        crossAxisSpacing: 18,
                        childAspectRatio: 0.95,
                      ),
                      itemBuilder: (context, index) {
                        final c = _counters[index];
                        final colors = [Colors.amber, Colors.deepOrange, const Color(0xFF8B5A2B), Colors.blue, Colors.red, Colors.green];
                        return FlavorCard(
                          flavorName: c.name,
                          color: colors[index % colors.length],
                          value: _todayTotals[c.id] ?? 0,
                          onTap: () => _increment(c.id),
                        );
                      },
                    ),
                  ),
                  MoreFlavorsPage(
                    key: _moreFlavorsKey,
                    churritos: _churritos,
                    doceDeLeite: _churrosDoceLeite,
                    chocolate: _chocolate,
                    kibes: _kibes,
                    charque: _charque,
                    counterService: _service,
                    currentDate: _currentDisplayDate,
                    onCountersChanged: (data) {
                      setState(() {
                        _churritos = data['churritos'] ?? 0;
                        _churrosDoceLeite = data['doce-de-leite'] ?? 0;
                        _chocolate = data['chocolate'] ?? 0;
                        _kibes = data['kibes'] ?? 0;
                        _charque = data['charque'] ?? 0;
                      });
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),
            FooterMenu(
              onMinus: () => _openAdjustSheet(false),
              onReport: _openReport,
              onInventory: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExpiryProductPage())),
            ),
          ],
        ),
      ),
    );
  }
}

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

    if (_isMoreFlavor) {
      final currentValue = _moreFlavorsData[_selectedId] ?? 0;
      final newValue = currentValue + delta;

      if (newValue < 0) return;

      _moreFlavorsData[_selectedId!] = newValue;
      if (mounted && widget.onUpdateMoreFlavors != null) {
        widget.onUpdateMoreFlavors!(_moreFlavorsData);

        if (context.mounted) {
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
                  ..._items.map(
                    (c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(
                        c.name,
                        style: TextStyle(fontSize: screenWidth < 360 ? 14 : 16),
                      ),
                    ),
                  ),
                  if (_moreFlavorsData.isNotEmpty)
                    DropdownMenuItem(
                      enabled: false,
                      child: Divider(color: Colors.grey[400], thickness: 1),
                    ),
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
                  if (_moreFlavorsData.isNotEmpty)
                    DropdownMenuItem(
                      value: 'charque',
                      child: Text(
                        'Charque',
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
                    if (i < _items.length) {
                      final it = _items[i];
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

                    final moreFlavorIndex = i - _items.length;

                    if (moreFlavorIndex == 0) {
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

                    final flavorIndex = moreFlavorIndex - 1;
                    final flavorNames = [
                      'Churritos',
                      'Doce de Leite',
                      'Chocolate',
                      'Kibes',
                      'Charque',
                    ];
                    final flavorKeys = [
                      'churritos',
                      'doce-de-leite',
                      'chocolate',
                      'kibes',
                      'charque',
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
