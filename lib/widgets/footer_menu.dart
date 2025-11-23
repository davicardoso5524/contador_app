// lib/widgets/footer_menu.dart
import 'package:flutter/material.dart';

class FooterMenu extends StatelessWidget {
  final VoidCallback onHome;
  final VoidCallback onMinus;
  final VoidCallback onStock;
  final VoidCallback onReport;

  const FooterMenu({
    super.key,
    required this.onHome,
    required this.onMinus,
    required this.onStock,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    const double baseHeight = 56.0;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 360;

    // tamanho mínimo dos botões circulares
    final buttonMinSize = Size(isCompact ? 44 : 52, isCompact ? 44 : 52);

    return SafeArea(
      top: false,
      child: Material(
        elevation: 8,
        color: Theme.of(context).colorScheme.surface,
        child: Container(
          height: baseHeight + bottomInset,
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // HOME
              IconButton(
                onPressed: onHome,
                icon: const Icon(Icons.home_outlined),
                splashRadius: 24,
              ),

              // DIMINUIR — AGORA IGUAL AO “+”
              ElevatedButton(
                onPressed: onMinus,
                style: ElevatedButton.styleFrom(
                  shape: const CircleBorder(),
                  minimumSize: buttonMinSize,
                  padding: const EdgeInsets.all(10),
                  elevation: 2,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
                child: const Icon(Icons.remove, size: 28),
              ),

              // ESTOQUE (substituiu "ADICIONAR")
              ElevatedButton(
                onPressed: onStock,
                style: ElevatedButton.styleFrom(
                  shape: const CircleBorder(),
                  minimumSize: buttonMinSize,
                  padding: const EdgeInsets.all(10),
                  elevation: 2,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
                child: const Icon(Icons.storefront, size: 28),
              ),

              // RELATÓRIO
              IconButton(
                onPressed: onReport,
                icon: const Icon(Icons.bar_chart_outlined),
                splashRadius: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
