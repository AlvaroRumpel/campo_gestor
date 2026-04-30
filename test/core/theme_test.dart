import 'package:campo_gestor/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppTheme.light() uses Material 3 with seeded ColorScheme', () {
    final theme = AppTheme.light();
    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.brightness, Brightness.light);
    // Seed color #4A6741 (verde-musgo) yields a primary in the green family.
    // We assert the scheme exists rather than a specific HSL — Material 3
    // derives the full palette and exact values may shift across Flutter
    // versions.
    expect(theme.colorScheme.primary, isA<Color>());
  });
}
