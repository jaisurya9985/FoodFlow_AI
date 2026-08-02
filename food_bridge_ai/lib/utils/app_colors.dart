import 'package:flutter/material.dart';

class AppColors {
  // ── Dark Background Palette ──────────────────────────────────────────────
  static const Color darkBg       = Color(0xFF08110E); // deep dark canvas
  static const Color darkSurface  = Color(0xFF0F1F18); // slightly lighter
  static const Color darkCard     = Color(0xFF162820); // glassmorphism card bg
  static const Color darkCardAlt  = Color(0xFF1D3526); // alternate card

  // ── Primary (Legacy names kept for compatibility) ─────────────────────────
  static const Color forestGreen  = Color(0xFF00C97B); // vibrant mint
  static const Color mossGreen    = Color(0xFF00E5A0); // bright accent mint
  static const Color lightGreen   = Color(0xFF66FFD0); // light neon mint

  // ── Accent ────────────────────────────────────────────────────────────────
  static const Color amber        = Color(0xFFFF7043); // vivid orange-coral
  static const Color amberLight   = Color(0xFFFFAB76); // soft coral
  static const Color gold         = Color(0xFFFFD700); // gold for badges

  // ── Background (Light, legacy) ───────────────────────────────────────────
  static const Color cream        = Color(0xFF08110E); // remapped to dark bg
  static const Color cardWhite    = Color(0xFF162820); // remapped to dark card
  static const Color surfaceGrey  = Color(0xFF1D3526); // remapped to dark alt

  // ── Risk ──────────────────────────────────────────────────────────────────
  static const Color riskHigh     = Color(0xFFFF4C6A);
  static const Color riskMedium   = Color(0xFFFFB300);
  static const Color riskLow      = Color(0xFF00E5A0);

  // ── Status ────────────────────────────────────────────────────────────────
  static const Color teal         = Color(0xFF00BCD4);
  static const Color purple       = Color(0xFF9C6FFF);
  static const Color pink         = Color(0xFFFF4B9B);

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textDark     = Color(0xFFF0FFF8); // near-white on dark
  static const Color textMedium   = Color(0xFFA8C5B5); // muted green-grey
  static const Color textLight    = Color(0xFF5A8070); // dim
  static const Color textWhite    = Color(0xFFFFFFFF);

  // ── Shadows & Glows ───────────────────────────────────────────────────────
  static const Color shadowColor  = Color(0x33000000);
  static const Color shadowDark   = Color(0x55000000);
  static const Color glowGreen    = Color(0x3300E5A0);
  static const Color glowAmber    = Color(0x33FF7043);

  // ── Gradient helpers ─────────────────────────────────────────────────────
  static const List<Color> heroGradient = [Color(0xFF001A11), Color(0xFF08110E)];
  static const List<Color> mintGradient = [Color(0xFF00C97B), Color(0xFF00E5A0)];
  static const List<Color> amberGradient = [Color(0xFFFF7043), Color(0xFFFF4B9B)];
  static const List<Color> purpleGradient = [Color(0xFF6C3FD6), Color(0xFF9C6FFF)];
}
