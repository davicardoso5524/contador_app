import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'pages/splash_page.dart';

void main() {
  runApp(const ContadorApp());
}

class ContadorApp extends StatelessWidget {
  const ContadorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Loucos por Coxinha',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
      ),
      home: const SplashPage(),
      routes: {'/home': (context) => const HomePage()},
    );
  }
}
