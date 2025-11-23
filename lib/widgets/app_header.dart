import 'package:flutter/material.dart';

class AppHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onApplySales;
  const AppHeader({super.key, required this.title, this.onApplySales});

  @override
  Widget build(BuildContext context) {
    // header com logo/nome centralizado e uma linha abaixo (a linha é desenhada no parent também)
    return SafeArea(
      bottom: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
          children: [
            // Linha com título e botão de aplicar vendas
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // aqui pode trocar por Image.asset(...) se tiver logo
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                      letterSpacing: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                // Botão para aplicar vendas (se callback fornecido)
                if (onApplySales != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: IconButton(
                        icon: const Icon(Icons.receipt),
                        tooltip: 'Aplicar Vendas ao Estoque',
                        onPressed: onApplySales,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            // linha decorativa menor abaixo do nome
            Container(
              width: 160,
              height: 3,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
