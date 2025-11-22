import 'package:flutter/material.dart';
import '../shared/app_colors.dart';
import '../services/counter_service.dart';

/// Página com sabores adicionais (Churritos, Churros Doce de Leite, Chocolate, Kibes)
/// Estado local com contadores independentes
/// NOTA: Agora persiste alterações via CounterService para a data atual
class MoreFlavorsPage extends StatefulWidget {
  static const _gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    mainAxisSpacing: 18,
    crossAxisSpacing: 18,
    childAspectRatio: 0.95,
  );

  final Function(Map<String, int>)? onCountersChanged;
  final int churritos;
  final int doceDeLeite;
  final int chocolate;
  final int kibes;
  final CounterService? counterService; // Novo: para persistir alterações
  final DateTime? currentDate; // Novo: data para persistir

  const MoreFlavorsPage({
    super.key,
    this.onCountersChanged,
    this.churritos = 0,
    this.doceDeLeite = 0,
    this.chocolate = 0,
    this.kibes = 0,
    this.counterService,
    this.currentDate,
  });

  @override
  State<MoreFlavorsPage> createState() => _MoreFlavorPageState();
}

class _MoreFlavorPageState extends State<MoreFlavorsPage> {
  // Contadores locais para cada sabor
  late int _churritos;
  late int _churrosDoceLeite;
  late int _chocolate;
  late int _kibes;

  @override
  void initState() {
    super.initState();
    _churritos = widget.churritos;
    _churrosDoceLeite = widget.doceDeLeite;
    _chocolate = widget.chocolate;
    _kibes = widget.kibes;
  }

  @override
  void didUpdateWidget(MoreFlavorsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Atualiza quando os valores do widget mudarem (vindo do HomePage)
    if (oldWidget.churritos != widget.churritos ||
        oldWidget.doceDeLeite != widget.doceDeLeite ||
        oldWidget.chocolate != widget.chocolate ||
        oldWidget.kibes != widget.kibes) {
      setState(() {
        _churritos = widget.churritos;
        _churrosDoceLeite = widget.doceDeLeite;
        _chocolate = widget.chocolate;
        _kibes = widget.kibes;
      });
    }
  }

  // Cores para os cartões (usando AppColors para padronização)
  static const List<Color> _colors = [
    AppColors.churritosColor,
    AppColors.churrosDoceLeiteColor,
    AppColors.chocolateColor,
    AppColors.kibesColor,
  ];

  /// Atualiza os contadores com valores externos (vindo do menu de ajuste)
  void updateCounters(Map<String, int> data) {
    setState(() {
      _churritos = data['churritos'] ?? _churritos;
      _churrosDoceLeite = data['doce-de-leite'] ?? _churrosDoceLeite;
      _chocolate = data['chocolate'] ?? _chocolate;
      _kibes = data['kibes'] ?? _kibes;
    });
    _notifyCounters();
  }

  /// Notifica o parent sobre mudanças nos contadores
  void _notifyCounters() {
    widget.onCountersChanged?.call({
      'churritos': _churritos,
      'doce-de-leite': _churrosDoceLeite,
      'chocolate': _chocolate,
      'kibes': _kibes,
    });
  }

  /// Incrementa um sabor e persiste via CounterService
  Future<void> _incrementFlavor(String flavorId) async {
    final date = widget.currentDate ?? DateTime.now();
    final service = widget.counterService;

    if (service != null) {
      // Persiste a alteração via CounterService
      await service.applyMoreFlavorDelta(flavorId, 1, date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Calcula tamanho responsivo
    double horizontalPadding = 12.0;
    double verticalPadding = 16.0;

    if (screenWidth < 360) {
      horizontalPadding = 8.0;
      verticalPadding = 12.0;
    } else if (screenWidth < 400) {
      horizontalPadding = 10.0;
      verticalPadding = 14.0;
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: GridView(
                  gridDelegate: MoreFlavorsPage._gridDelegate,
                  children: [
                    _buildFlavorCard(
                      'Churritos',
                      _churritos,
                      _colors[0],
                      () async {
                        setState(() => _churritos++);
                        await _incrementFlavor('churritos');
                        _notifyCounters();
                      },
                    ),
                    _buildFlavorCard(
                      'Doce de Leite',
                      _churrosDoceLeite,
                      _colors[1],
                      () async {
                        setState(() => _churrosDoceLeite++);
                        await _incrementFlavor('doce-de-leite');
                        _notifyCounters();
                      },
                    ),
                    _buildFlavorCard(
                      'Chocolate',
                      _chocolate,
                      _colors[2],
                      () async {
                        setState(() => _chocolate++);
                        await _incrementFlavor('chocolate');
                        _notifyCounters();
                      },
                    ),
                    _buildFlavorCard('Kibes', _kibes, _colors[3], () async {
                      setState(() => _kibes++);
                      await _incrementFlavor('kibes');
                      _notifyCounters();
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Constrói um card individual de sabor com nome e contador
  /// Cores padronizadas: fundo = cor específica, texto = preto, caixa interior = 10% opacidade
  /// Usa AppColors para consistência visual (sem lógica condicional de cor)
  static const _borderRadius = BorderRadius.all(Radius.circular(12));
  static const _innerBorderRadius = BorderRadius.all(Radius.circular(8));

  Widget _buildFlavorCard(
    String flavorName,
    int count,
    Color color,
    Future<void> Function() onTap,
  ) {
    return Material(
      color: color,
      borderRadius: _borderRadius,
      child: InkWell(
        borderRadius: _borderRadius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                flavorName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Container(
                width: 70,
                height: 70,
                decoration: const BoxDecoration(
                  color: AppColors.innerBoxBackground,
                  borderRadius: _innerBorderRadius,
                ),
                child: Center(
                  child: Text(
                    count.toString(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
