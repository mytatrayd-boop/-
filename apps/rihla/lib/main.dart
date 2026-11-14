import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart';

/// هيكل أدنى (F0أ). الواجهة الحقيقية في F1/F5؛ لا نصوص هنا عمداً.
void main() {
  runApp(const RihlaApp());
}

class RihlaApp extends StatelessWidget {
  const RihlaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: Scaffold(body: SizedBox.expand()));
  }
}
