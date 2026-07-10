import 'package:flutter/material.dart';

/// "Transport Help" design system — clean green + deep forest (reference UI).
/// A single source of colour tokens: switching this palette re-skins the whole
/// app (screens must never hardcode hex).
class AppColors {
  AppColors._();

  // Primary — Green (actions, active states, brand)
  static const Color primary = Color(0xFF16A34A); // green 600
  static const Color primaryLight = Color(0xFFDCFCE7); // green 100
  static const Color primaryDark = Color(0xFF15803D); // green 700

  // Secondary — neutral slate (text, headers, depth)
  static const Color secondary = Color(0xFF475569);
  static const Color secondaryLight = Color(0xFFF1F5F9);
  static const Color secondaryDark = Color(0xFF0F172A);

  // Tertiary — amber (pending states, warnings, highlights)
  static const Color tertiary = Color(0xFFF59E0B);
  static const Color tertiaryLight = Color(0xFFFEF3C7);
  static const Color tertiaryDark = Color(0xFFD97706);

  // Neutrals
  static const Color background = Color(0xFFF6F8F7); // soft green-tinted white
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE5EAE7);
  static const Color cardBg = Colors.white;

  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);

  // Dark brand surfaces (sidebar / hero cards) — deep forest green
  static const Color charcoal = Color(0xFF0B1F14);
  static const Color charcoalLight = Color(0xFF14311F);

  static const Color accentGold = Color(0xFFF5A623);

  // Semantic
  static const Color success = Color(0xFF16A34A);
  static const Color error = Color(0xFFDC2626);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF0EA5E9);

  // Gradients for hero banners, buttons and badges.
  // (Name kept for compatibility — values are the brand green.)
  static const List<Color> saffronGradient = [
    Color(0xFF22C55E),
    Color(0xFF16A34A),
    Color(0xFF15803D),
  ];
  static const List<Color> charcoalGradient = [
    Color(0xFF14311F),
    Color(0xFF0B1F14),
  ];
  static const List<Color> goldGradient = [
    Color(0xFFFBBF24),
    Color(0xFFF59E0B),
  ];
}
