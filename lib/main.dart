import 'package:flutter/material.dart';
import 'pages/home_page.dart';

void main() {
  // Inicialização mínima para o app abrir o mais rápido possível
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ContadorApp());
}

class ContadorApp extends StatelessWidget {
  const ContadorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Loucos por Contagem',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
      ),
      home: const HomePage(),
    );
  }
}
