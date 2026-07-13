import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showWordmark;

  const AppLogo({
    super.key,
    this.size = 56,
    this.showWordmark = false,
  });

  @override
  Widget build(BuildContext context) {
    final mark = SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/images/ecotrack.png',
        fit: BoxFit.contain,
      ),
    );

    if (!showWordmark) {
      return mark;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(height: size * 0.18),
        SizedBox(
          width: size * 2.8,
          child: Image.asset(
            'assets/images/ecotrack.png',
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }
}