import 'package:flutter/material.dart';

import 'screens/lists/lists_screen.dart';
import 'screens/main_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const LakwatsaApp());
}

class LakwatsaApp extends StatelessWidget {
  const LakwatsaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lakwatsa',
      theme: AppTheme.light,
      home: const MainScreen(),
    );
  }
}
