import 'package:flutter/material.dart';
import 'ui/connect_page.dart';

void main() {
  runApp(const SwiftShareApp());
}

class SwiftShareApp extends StatelessWidget {
  const SwiftShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SwiftShare',
      theme: ThemeData.dark(),
      home: const ConnectPage(),
    );
  }
}
