// lib/widgets/footer_menu.dart
import 'package:flutter/material.dart';

class FooterMenu extends StatelessWidget {
  final VoidCallback onHome;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onReport;

  const FooterMenu({
    super.key,
    required this.onHome,
    required this.onMinus,
    required this.onPlus,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [

          // HOME – área de toque maior
          InkWell(
            onTap: onHome,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,  // antes era ~6
                vertical: 14.0,     // antes era ~6
              ),
              child: Row(
                children: [
                  Icon(Icons.home_outlined, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 6),
                  Text('HOME', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                ],
              ),
            ),
          ),

          // Separador |
          Text('|', style: TextStyle(fontSize: 22, color: Colors.brown[700])),

          // Botões - e +
          Row(
            children: [
              IconButton(
                onPressed: onMinus,
                icon: const Icon(Icons.remove_circle_outline),
                tooltip: 'Diminuir',
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onPlus,
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Adicionar',
              ),
            ],
          ),

          // Separador |
          Text('|', style: TextStyle(fontSize: 22, color: Colors.brown[700])),

          // RELATÓRIO – área de toque maior
          InkWell(
            onTap: onReport,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0, // antes era ~6
                vertical: 14.0,   // antes era ~6
              ),
              child: Row(
                children: [
                  Icon(Icons.insert_chart_outlined, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 6),
                  Text('Relatório', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
