import 'package:flutter/material.dart';

/// شعار العدسة/الكوب (assets/icon/logo.png، مولّد بـ tool/generate_icon.py).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 88});

  static const asset = 'assets/icon/logo.png';

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Image.asset(asset, width: size, height: size),
      );
}
