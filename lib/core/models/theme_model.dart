// lib/core/models/theme_model.dart
import 'package:flutter/material.dart';

class MazeTheme {
  final String id;
  final String name;
  final String emoji;
  final Color primary;
  final Color pathColor;
  final Color cellEmpty;
  final Color cellWall;
  final Color cellStart;
  final Color cellEnd;
  final Color background;
  final bool isPremium;

  const MazeTheme({
    required this.id, required this.name, required this.emoji,
    required this.primary, required this.pathColor, required this.cellEmpty,
    required this.cellWall, required this.cellStart, required this.cellEnd,
    required this.background, this.isPremium = false,
  });
}

class AppThemes {
  static const classic = MazeTheme(
    id: 'classic', name: 'Klasik', emoji: '🟣',
    primary: Color(0xFF7C3AED), pathColor: Color(0xFF7C3AED),
    cellEmpty: Color(0xFFEFEDEA), cellWall: Color(0xFFDDDAD3),
    cellStart: Color(0xFFD1FAE5), cellEnd: Color(0xFFDBEAFE),
    background: Color(0xFFF8F8F6),
  );
  static const ocean = MazeTheme(
    id: 'ocean', name: 'Okyanus', emoji: '🌊',
    primary: Color(0xFF0EA5E9), pathColor: Color(0xFF0284C7),
    cellEmpty: Color(0xFFE0F2FE), cellWall: Color(0xFFBAE6FD),
    cellStart: Color(0xFFD1FAE5), cellEnd: Color(0xFFFEF3C7),
    background: Color(0xFFF0F9FF),
  );
  static const forest = MazeTheme(
    id: 'forest', name: 'Orman', emoji: '🌲', isPremium: true,
    primary: Color(0xFF16A34A), pathColor: Color(0xFF15803D),
    cellEmpty: Color(0xFFDCFCE7), cellWall: Color(0xFFBBF7D0),
    cellStart: Color(0xFFFEF9C3), cellEnd: Color(0xFFFFEDD5),
    background: Color(0xFFF0FDF4),
  );
  static const midnight = MazeTheme(
    id: 'midnight', name: 'Gece Yarısı', emoji: '🌙', isPremium: true,
    primary: Color(0xFFA78BFA), pathColor: Color(0xFF8B5CF6),
    cellEmpty: Color(0xFF1E1B2E), cellWall: Color(0xFF13111F),
    cellStart: Color(0xFF1A3A28), cellEnd: Color(0xFF1A2540),
    background: Color(0xFF0F0D1A),
  );
  static const sunset = MazeTheme(
    id: 'sunset', name: 'Gün Batımı', emoji: '🌅', isPremium: true,
    primary: Color(0xFFEA580C), pathColor: Color(0xFFDC2626),
    cellEmpty: Color(0xFFFFF7ED), cellWall: Color(0xFFFED7AA),
    cellStart: Color(0xFFDCFCE7), cellEnd: Color(0xFFFCE7F3),
    background: Color(0xFFFFFBEB),
  );
  static const neon = MazeTheme(
    id: 'neon', name: 'Neon', emoji: '⚡', isPremium: true,
    primary: Color(0xFF22D3EE), pathColor: Color(0xFF06B6D4),
    cellEmpty: Color(0xFF0F172A), cellWall: Color(0xFF1E293B),
    cellStart: Color(0xFF042F2E), cellEnd: Color(0xFF1A1042),
    background: Color(0xFF020617),
  );

  static const List<MazeTheme> all = [classic, ocean, forest, midnight, sunset, neon];
}
