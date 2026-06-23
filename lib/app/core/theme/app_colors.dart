import 'package:flutter/material.dart';

/// "Bharat Transport" design system — energetic saffron + deep charcoal.
/// Warm, bold and desi-premium: built to feel made-in-India for truck owners
/// while still looking polished enough to impress a client.
class AppColors {
  AppColors._();

  // Primary — Saffron (the brand colour: highways, energy, action)
  static const Color primary = Color(0xFFF97316); // saffron 500
  static const Color primaryLight = Color(0xFFFFEDD5); // saffron 100
  static const Color primaryDark = Color(0xFFEA580C); // saffron 600

  // Secondary — Warm charcoal/stone (text, headers, depth)
  static const Color secondary = Color(0xFF44403C); // stone 700
  static const Color secondaryLight = Color(0xFFF5F0E8); // warm sand
  static const Color secondaryDark = Color(0xFF1C1917); // stone 900

  // Tertiary — Gold/amber (accents, earnings, highlights)
  static const Color tertiary = Color(0xFFF5A623);
  static const Color tertiaryLight = Color(0xFFFEF3C7);
  static const Color tertiaryDark = Color(0xFFD97706);

  // Neutrals — warm, not cold grey (premium feel)
  static const Color background = Color(0xFFFAF6F0); // warm cream
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFECE6DD);
  static const Color cardBg = Colors.white;

  static const Color textPrimary = Color(0xFF1C1917); // charcoal
  static const Color textSecondary = Color(0xFF78716C); // warm grey
  static const Color textHint = Color(0xFFA8A29E);

  // Charcoal surfaces (dark hero cards / command areas)
  static const Color charcoal = Color(0xFF1C1917);
  static const Color charcoalLight = Color(0xFF292524);

  static const Color accentGold = Color(0xFFF5A623);

  // Semantic
  static const Color success = Color(0xFF16A34A);
  static const Color error = Color(0xFFDC2626);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF0EA5E9);

  // Gradients for hero banners, buttons and badges
  static const List<Color> saffronGradient = [
    Color(0xFFFB923C),
    Color(0xFFF97316),
    Color(0xFFEA580C),
  ];
  static const List<Color> charcoalGradient = [
    Color(0xFF292524),
    Color(0xFF1C1917),
  ];
  static const List<Color> goldGradient = [
    Color(0xFFFBBF24),
    Color(0xFFF59E0B),
  ];
}
