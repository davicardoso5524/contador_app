import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:contador_app/main.dart';

void main() {
  testWidgets('Home opens and footer + opens Add sheet', (WidgetTester tester) async {
    // Build appa
    await tester.pumpWidget(const ContadorApp());
    await tester.pumpAndSettle();

    // Verifica header
    expect(find.text('LOUCOS POR COXINHA'), findsOneWidget);

    // Verifica se existe o ícone de adicionar no footer
    expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);

    // Toca no ícone de adicionar
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();

    // Agora o bottom sheet placeholder tem o título 'Adicionar'
    expect(find.text('Adicionar'), findsOneWidget);

    // Não tentamos clicar em 'Confirmar (placeholder)' aqui para evitar problemas de área visível.
    // Apenas asseguramos que o sheet abriu com o título correto.
  });
}
