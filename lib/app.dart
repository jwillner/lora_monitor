import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

class HeltecApp extends StatelessWidget {
  const HeltecApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Heltec Master',
      theme: ThemeData(useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}
