import 'package:flutter/material.dart';

import '../views/random_image_page.dart';

class AuroraApp extends StatelessWidget {
  const AuroraApp({super.key});

  @override
  Widget build(BuildContext context) {
    final seedColor = const Color(0xFF5A67D8);

    return MaterialApp(
      title: 'Aurora',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const RandomImagePage(),
    );
  }
}

