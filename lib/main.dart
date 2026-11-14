import 'package:flutter/material.dart';

import 'features/pets/screens/my_livings_screen.dart';

void main() {
  runApp(const PawMateApp());
}

class PawMateApp extends StatelessWidget {
  const PawMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PawMate',
      theme: ThemeData(useMaterial3: true, fontFamily: 'Roboto'),
      home: const MyLivingsScreen(),
    );
  }
}
