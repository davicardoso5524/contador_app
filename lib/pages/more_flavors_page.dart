import 'package:flutter/material.dart';
import '../shared/app_colors.dart';
import '../services/counter_service.dart';
import '../widgets/flavor_card.dart';

/// Página com sabores adicionais (Churritos, Churros Doce de Leite, Chocolate, Kibes, Charque)
class MoreFlavorsPage extends StatefulWidget {
  final Function(Map<String, int>)? onCountersChanged;
  final int churritos;
  final int doceDeLeite;
  final int chocolate;
  final int kibes;
  final int charque;
  final CounterService? counterService;
  final DateTime? currentDate;

  const MoreFlavorsPage({
    super.key,
    this.onCountersChanged,
    this.churritos = 0,
    this.doceDeLeite = 0,
    this.chocolate = 0,
    this.kibes = 0,
    this.charque = 0,
    this.counterService,
    this.currentDate,
  });

  @override
  State<MoreFlavorsPage> createState() => _MoreFlavorPageState();
}

class _MoreFlavorPageState extends State<MoreFlavorsPage> {
  late int _churritos;
  late int _churrosDoceLeite;
  late int _chocolate;
  late int _kibes;
  late int _charque;

  @override
  void initState() {
    super.initState();
    _churritos = widget.churritos;
    _churrosDoceLeite = widget.doceDeLeite;
    _chocolate = widget.chocolate;
    _kibes = widget.kibes;
    _charque = widget.charque;
  }

  @override
  void didUpdateWidget(MoreFlavorsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.churritos != widget.churritos ||
        oldWidget.doceDeLeite != widget.doceDeLeite ||
        oldWidget.chocolate != widget.chocolate ||
        oldWidget.kibes != widget.kibes ||
        oldWidget.charque != widget.charque) {
      setState(() {
        _churritos = widget.churritos;
        _churrosDoceLeite = widget.doceDeLeite;
        _chocolate = widget.chocolate;
        _kibes = widget.kibes;
        _charque = widget.charque;
      });
    }
  }

  void _notifyCounters() {
    widget.onCountersChanged?.call({
      'churritos': _churritos,
      'doce-de-leite': _churrosDoceLeite,
      'chocolate': _chocolate,
      'kibes': _kibes,
      'charque': _charque,
    });
  }

  Future<void> _incrementFlavor(String flavorId) async {
    final date = widget.currentDate ?? DateTime.now();
    final service = widget.counterService;

    if (service != null) {
      await service.applyMoreFlavorDelta(flavorId, 1, date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    double spacing = 18.0;
    if (screenWidth < 360) {
      spacing = 12.0;
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(spacing),
          child: GridView(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              childAspectRatio: 0.95,
            ),
            children: [
              FlavorCard(
                flavorName: 'Churritos',
                value: _churritos,
                color: AppColors.churritosColor,
                onTap: () async {
                  setState(() => _churritos++);
                  await _incrementFlavor('churritos');
                  _notifyCounters();
                },
              ),
              FlavorCard(
                flavorName: 'Doce de Leite',
                value: _churrosDoceLeite,
                color: AppColors.churrosDoceLeiteColor,
                onTap: () async {
                  setState(() => _churrosDoceLeite++);
                  await _incrementFlavor('doce-de-leite');
                  _notifyCounters();
                },
              ),
              FlavorCard(
                flavorName: 'Chocolate',
                value: _chocolate,
                color: AppColors.chocolateColor,
                onTap: () async {
                  setState(() => _chocolate++);
                  await _incrementFlavor('chocolate');
                  _notifyCounters();
                },
              ),
              FlavorCard(
                flavorName: 'Kibes',
                value: _kibes,
                color: AppColors.kibesColor,
                onTap: () async {
                  setState(() => _kibes++);
                  await _incrementFlavor('kibes');
                  _notifyCounters();
                },
              ),
              FlavorCard(
                flavorName: 'Charque',
                value: _charque,
                color: AppColors.charqueColor,
                onTap: () async {
                  setState(() => _charque++);
                  await _incrementFlavor('charque');
                  _notifyCounters();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
