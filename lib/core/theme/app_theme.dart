import 'package:flutter/material.dart';

/// Material 3 theme for Campo Gestor.
///
/// Per D-12 (CONTEXT.md), seedColor comes from a "verde-musgo / terra" palette
/// reflecting the agrarian/livestock domain. Exact hex (#4A6741, sage/moss
/// green) is Claude's discretion. Dark mode is deferred (CONTEXT.md Deferred
/// Ideas).
abstract final class AppTheme {
  static const Color _seedColor = Color(0xFF4A6741);

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.light,
        ),
      );
}
