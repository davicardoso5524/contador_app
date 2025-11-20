import 'package:flutter/material.dart';

/// Centraliza todas as cores da aplicação.
///
/// Benefícios:
/// - Uma única fonte de verdade para cores (DRY - Don't Repeat Yourself)
/// - Facilita mudanças globais (ex: tema claro/escuro)
/// - Evita inconsistências de cor no app
/// - Permite fácil integração com temas dinâmicos (Material Design 3)
class AppColors {
  // Cores dos cartões (backgrounds)
  static const Color cardBackground = Colors.white;

  // Cores do texto principal
  static const Color textPrimary = Colors.white;

  // Cor do texto secundário (para informações menos importantes)
  static const Color textSecondary = Colors.grey;

  // Cor da caixa interior dos cartões (opacidade 10% de preto)
  static const Color innerBoxBackground = Color.fromARGB(
    26,
    0,
    0,
    0,
  ); // 10% opacity

  // Cores dos sabores de coxinha (originais)
  static const Color coxinhaRomeu = Colors.purple;
  static const Color coxinhaCapuleta = Colors.pink;
  static const Color coxinhaAmor = Colors.red;
  static const Color coxinhaModerno = Colors.orange;

  // Cores dos sabores adicionais (Mais Sabores)
  static const Color churritosColor = Colors.orange;
  static const Color churrosDoceLeiteColor = Colors.red;
  static const Color chocolateColor = Colors.brown;
  static const Color kibesColor = Colors.amber;

  // Cores da interface
  static const Color primaryAccent = Colors.blue;
  static const Color borderDark = Colors.black;

  /// Retorna a cor de texto com base no contexto
  ///
  /// Nota: Agora é uma cor fixa (textPrimary) por padronização.
  /// Se quiser voltar a usar cores baseadas em brightness no futuro,
  /// você pode descomentar e usar novamente.
  static Color getTextColor(Color backgroundColor) {
    // Versão anterior (comentada) que detectava brightness:
    // final isLight = ThemeData.estimateBrightnessForColor(backgroundColor) == Brightness.light;
    // return isLight ? Colors.black : Colors.white;

    // Versão padronizada: sempre retorna preto
    return textPrimary;
  }

  /// Mapa com nomes amigáveis para cores de sabores
  /// Útil para seleção dinâmica de cores
  static const Map<String, Color> flavorColors = {
    'romeu': coxinhaRomeu,
    'capuleta': coxinhaCapuleta,
    'amor': coxinhaAmor,
    'moderno': coxinhaModerno,
    'churritos': churritosColor,
    'doce-de-leite': churrosDoceLeiteColor,
    'chocolate': chocolateColor,
    'kibes': kibesColor,
  };
}
