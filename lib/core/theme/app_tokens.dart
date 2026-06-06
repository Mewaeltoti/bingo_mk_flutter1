import 'package:flutter/material.dart';
import '../../presentation/blocs/settings_cubit.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppTokens — single source of truth for design tokens.
//
// Previously each page/widget had its own local `_C` class with identical
// color definitions. Any theme change required touching every file.
// Use this class everywhere instead:
//
//   import 'package:your_app/core/theme/app_tokens.dart';
//   color: AppTokens.gold
//   color: AppTokens.bg          // reactive to light/dark mode
//
// ─────────────────────────────────────────────────────────────────────────────
class AppTokens {
  AppTokens._();

  // ── Light/dark reactive colours ──────────────────────────────────────────
  static bool get _l => SettingsCubit.isLightModeGlobal;

  static Color get bg          => _l ? const Color(0xFFF2F4F7) : const Color(0xFF0E1321);
  static Color get bgDeep      => _l ? const Color(0xFFE4E7EC) : const Color(0xFF090E1C);
  static Color get surface     => _l ? const Color(0xFFFFFFFF) : const Color(0xFF161B2A);
  static Color get surfaceHigh => _l ? const Color(0xFFF9FAFB) : const Color(0xFF1A1F2E);
  static Color get surfaceTop  => _l ? const Color(0xFFF0F2F5) : const Color(0xFF252A39);
  static Color get divider     => _l ? const Color(0xFFEAECF0) : const Color(0xFF303444);

  static Color get textHigh    => _l ? const Color(0xFF101828) : const Color(0xFFDEE2F6);
  static Color get textMid     => _l ? const Color(0xFF475467) : const Color(0xFFD1C5AB);
  static Color get textLow     => _l ? const Color(0xFF667085) : const Color(0xFF9A9078);

  // ── Static brand colours ─────────────────────────────────────────────────
  // Game page gold (bright yellow)
  static const Color gold        = Color(0xFFF1C100);
  static const Color goldLight   = Color(0xFFFFE8AE);
  static const Color goldFill    = Color(0x1AF1C100);
  static const Color goldBorder  = Color(0x40F1C100);

  // Payment/profile page gold (classic amber)
  static const Color goldAlt       = Color(0xFFD4AF37);
  static const Color goldAltDim    = Color(0xFFA07C1E);
  static const Color goldAltFill   = Color(0x1AD4AF37);
  static const Color goldAltBorder = Color(0x40D4AF37);

  static const Color blue        = Color(0xFF006BE3);
  static const Color blueLight   = Color(0xFFADC6FF);
  static const Color blueFill    = Color(0x1A006BE3);
  static const Color blueBorder  = Color(0x40006BE3);

  // Payment page deep navy
  static const Color blueDeep   = Color(0xFF1A237E);
  static const Color blueMid    = Color(0xFF283593);
  static const Color blueAccent = Color(0xFF42A5F5);

  static const Color success      = Color(0xFF2A9D8F);
  static const Color danger       = Color(0xFFE63946);
  static const Color dangerFill   = Color(0x1AE63946);
  static const Color dangerBorder = Color(0x40E63946);
  static const Color warning      = Color(0xFFF59E0B);
  static const Color pink         = Color(0xFFFFB2B8);

  // Reactive surface aliases used by payment/profile pages
  static Color get card     => _l ? const Color(0xFFFFFFFF)  : const Color(0xFF0D1B2A);
  static Color get cardHigh => _l ? const Color(0xFFF9FAFB)  : const Color(0xFF112236);
}

// ─────────────────────────────────────────────────────────────────────────────
// AppText — shared text style factory (mirrors the old per-file _T class)
// ─────────────────────────────────────────────────────────────────────────────
class AppText {
  AppText._();

  static TextStyle get display => const TextStyle(
    fontFamily: 'Orbitron',
    letterSpacing: 0.05,
  ).copyWith(color: AppTokens.textHigh);

  static TextStyle label({
    double size = 11,
    Color? color,
    double spacing = 0.8,
    FontWeight weight = FontWeight.w700,
  }) => TextStyle(
    fontFamily: 'Outfit',
    fontSize: size,
    fontWeight: weight,
    letterSpacing: spacing,
    color: color ?? AppTokens.textMid,
  );

  static TextStyle body({
    double size = 13,
    Color? color,
    FontWeight weight = FontWeight.w400,
  }) => TextStyle(
    fontFamily: 'Outfit',
    fontSize: size,
    fontWeight: weight,
    color: color ?? AppTokens.textHigh,
  );

  static TextStyle number({double size = 20, Color? color}) => TextStyle(
    fontFamily: 'Orbitron',
    fontSize: size,
    fontWeight: FontWeight.w800,
    color: color ?? AppTokens.textHigh,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared decoration helper (mirrors the old per-file _glassDeco function)
// ─────────────────────────────────────────────────────────────────────────────
BoxDecoration glassDeco({
  Color? bg,
  Color? border,
  double radius = 16,
  List<BoxShadow>? shadows,
}) => BoxDecoration(
  color: bg ?? AppTokens.surface,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(
    color: border ?? Colors.white.withOpacity(0.08),
    width: 1,
  ),
  boxShadow: shadows,
);