import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF0B4F3F);
  static const Color primaryDark = Color(0xFF06332A);
  static const Color primaryDeeper = Color(0xFF042019);
  static const Color primaryLight = Color(0xFF3FA98A);
  static const Color primarySoft = Color(0xFFDCEDE6);

  static const Color accent = Color(0xFFC9A15A);
  static const Color accentDark = Color(0xFF966710);
  static const Color accentLight = Color(0xFFE1C689);
  static const Color accentSoft = Color(0xFFF6ECD8);
  static const Color grey900 = Color(0xFF1C1B19);
  static const Color grey700 = Color(0xFF433F3A);
  static const Color grey500 = Color(0xFF77726B);
  static const Color grey300 = Color(0xFFC9C3BA);
  static const Color grey100 = Color(0xFFEDEAE4);
  static const Color grey50 = Color(0xFFF7F5F1);
  static const Color success = Color(0xFF2F9E68);
  static const Color successSoft = Color(0xFFE1F3E9);
  static const Color error = Color(0xFFC1432E);
  static const Color errorSoft = Color(0xFFF8E3DF);
  static const Color warning = accent;
  static const Color warningSoft = accentSoft;
  static const Color info = Color(0xFF2E6E9E);
  static const Color infoSoft = Color(0xFFE1EBF3);
  static const Color secondaryMarker = Color(0xFF433F3A);
  static const Color background = Color(0xFFFAF8F5);
  static const Color surface = Colors.white;
  static const Color surfaceRaised = Colors.white;
  static const Color surfaceTint = Color(0xFFF3F0EA);
  static const Color border = grey100;
  static const Color borderStrong = grey300;
  static const Color divider = grey100;

  static const Color textPrimary = grey900;
  static const Color textSecondary = grey500;
  static const Color textDisabled = grey300;
  static const Color textOnPrimary = Colors.white;
  static const Color textOnDark = Color(0xFFF2F0EC);

  static const Color shimmerBase = grey100;
  static const Color shimmerHighlight = grey50;

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark, accentDark],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentLight, accent, accentDark],
  );

  static const RadialGradient ambientGlow = RadialGradient(
    center: Alignment(-0.6, -0.8),
    radius: 1.2,
    colors: [Color(0x333FA98A), Colors.transparent],
  );

  static Color scrimFor(Color base) => base.withValues(alpha: 0.78);

  static Color onSoft(Color base) => base;

  static Color softOf(Color base, {double alpha = 0.12}) =>
      base.withValues(alpha: alpha);
}
