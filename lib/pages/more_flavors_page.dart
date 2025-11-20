import 'package:flutter/material.dart';

/// Página com sabores adicionais (Churritos, Churros Doce de Leite, Chocolate, Kibes)
/// Estado local com contadores independentes
class MoreFlavorsPage extends StatefulWidget {
  final Function(Map<String, int>)? onCountersChanged;
  final int churritos;
  final int doceDeLeite;
  final int chocolate;
  final int kibes;

  const MoreFlavorsPage({
    super.key,
    this.onCountersChanged,
    this.churritos = 0,
    this.doceDeLeite = 0,
    this.chocolate = 0,
    this.kibes = 0,
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

  // Cores para os cartões
  static const List<Color> _colors = [
    Colors.orange,
    Colors.red,
    Colors.brown,
    Colors.amber,
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
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 18,
                    crossAxisSpacing: 18,
                    childAspectRatio: 0.95,
                  ),
                  children: [
                    _buildFlavorCard('Churritos', _churritos, _colors[0], () {
                      setState(() => _churritos++);
                      _notifyCounters();
                    }),
                    _buildFlavorCard(
                      'Doce de Leite',
                      _churrosDoceLeite,
                      _colors[1],
                      () {
                        setState(() => _churrosDoceLeite++);
                        _notifyCounters();
                      },
                    ),
                    _buildFlavorCard('Chocolate', _chocolate, _colors[2], () {
                      setState(() => _chocolate++);
                      _notifyCounters();
                    }),
                    _buildFlavorCard('Kibes', _kibes, _colors[3], () {
                      setState(() => _kibes++);
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
  /// Usa o mesmo estilo do FlavorCard original
  Widget _buildFlavorCard(
    String flavorName,
    int count,
    Color color,
    VoidCallback onTap,
  ) {
    // Determina se a cor é clara ou escura
    final isLight =
        ThemeData.estimateBrightnessForColor(color) == Brightness.light;
    final textColor = isLight ? Colors.black : Colors.white;

    // Caixa interna com cor semi-transparente
    final innerBoxColor = isLight
        ? Colors.white.withAlpha((0.6 * 255).round())
        : Colors.black.withAlpha((0.18 * 255).round());

    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Nome do sabor
              Text(
                flavorName,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // Caixa com valor
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: innerBoxColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textColor,
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
