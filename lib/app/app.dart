import 'package:flutter/material.dart';

import '../core/theme/theme.dart';
import '../features/home/presentation/home_screen.dart';
import '../global/constants/constants.dart';

class TodosApp extends StatelessWidget {
  const TodosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Config.title,
      theme: AppTheme.light(),
      home: const HomeScreen(),
    );
  }
}
