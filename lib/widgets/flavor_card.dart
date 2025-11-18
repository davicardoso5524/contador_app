import 'package:flutter/material.dart';

class FlavorCard extends StatelessWidget {
  final String flavorName;
  final Color color;
  final int value;
  final VoidCallback? onTap;
  final VoidCallback? onReset;

  const FlavorCard({
    super.key,
    required this.flavorName,
    required this.color,
    this.value = 0,
    this.onTap,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = ThemeData.estimateBrightnessForColor(color) == Brightness.light;
    final textColor = isLight ? Colors.black : Colors.white;

    final innerBoxColor = isLight
        ? Colors.white.withAlpha((0.6 * 255).round())
        : Colors.black.withAlpha((0.18 * 255).round());

    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap ?? () {},
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Nome do sabor (sem botões)
              Text(
                flavorName,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor),
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
                    '$value',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // Botão de reset (se não quiser também removo)
              if (onReset != null)
                IconButton(
                  tooltip: 'Resetar',
                  onPressed: onReset,
                  icon: Icon(Icons.restore, color: textColor),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
