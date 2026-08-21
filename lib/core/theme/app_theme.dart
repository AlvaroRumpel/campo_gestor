import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Material 3 theme do redesign "musgo evoluído".
///
/// Identidade: Archivo (UI) + IBM Plex Mono (dados numéricos), verde musgo
/// #3D5435, fundo bone #F5F3EB, CTA laranja #E8833A, destrutivo #A32D14.
/// Cards brancos r16 sem sombra; separação por cor/borda.
abstract final class AppTheme {
  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.onGreen,
      primaryContainer: AppColors.positiveChipBg,
      onPrimaryContainer: AppColors.primaryDarkText,
      secondary: AppColors.accent,
      onSecondary: AppColors.onAccent,
      secondaryContainer: AppColors.accentContainer,
      onSecondaryContainer: AppColors.accentTextDark,
      tertiary: AppColors.greenMid,
      onTertiary: AppColors.onGreen,
      error: AppColors.danger,
      onError: AppColors.onDanger,
      errorContainer: AppColors.dangerContainer,
      onErrorContainer: AppColors.onDangerContainer,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      surfaceContainerHighest: AppColors.surfaceVariant,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.outlineBorder,
      outlineVariant: AppColors.divider,
      shadow: Colors.black,
      scrim: AppColors.scrim,
      inverseSurface: AppColors.ink,
      onInverseSurface: AppColors.onGreen,
      inversePrimary: AppColors.greenLight,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: AppFonts.ui,
      scaffoldBackgroundColor: AppColors.background,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onGreen,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.onGreen,
        ),
        iconTheme: IconThemeData(color: AppColors.onGreen, size: 24),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        height: 68,
        elevation: 0,
        indicatorColor: AppColors.navPillBg,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w400,
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.textSecondary,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onAccent,
        elevation: 4,
        extendedTextStyle: const TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 14,
          height: 1.45,
          color: AppColors.textSecondary,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        modalBackgroundColor: AppColors.surface,
        showDragHandle: true,
        dragHandleColor: Color(0x3323281E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onGreen,
          minimumSize: const Size(48, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onGreen,
          elevation: 0,
          minimumSize: const Size(48, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          backgroundColor: AppColors.surface,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: AppColors.outlineBorder),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accentDark,
          textStyle: const TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.ink,
          selectedBackgroundColor: AppColors.primary,
          selectedForegroundColor: AppColors.onGreen,
          side: const BorderSide(color: AppColors.chipBorder),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primary,
        checkmarkColor: AppColors.onGreen,
        side: const BorderSide(color: AppColors.chipBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        // Label resolve por estado: selecionado = onGreen sobre primary
        // (ink sobre primary reprova WCAG ~1.8:1 — VIS-02).
        labelStyle: TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 13,
          color: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.onGreen
                : AppColors.ink,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        labelStyle: const TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
        floatingLabelStyle: const TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryDarkText,
        ),
        hintStyle: const TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 14.5,
          color: AppColors.textTertiary,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: const BorderSide(color: Color(0x4D23281E), width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : const Color(0x2E23281E),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.track,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: const TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 14,
          color: AppColors.onGreen,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.onGreen,
        unselectedLabelColor: AppColors.onGreenSecondary,
        indicatorColor: AppColors.gold,
        labelStyle: TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: TextStyle(fontFamily: AppFonts.ui, fontSize: 14),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.ink,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 14.5,
          color: AppColors.ink,
        ),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base) => base
      .apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
        fontFamily: AppFonts.ui,
      )
      .copyWith(
        // Títulos de card / seção
        titleLarge: const TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        titleMedium: const TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        titleSmall: const TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        bodyLarge: const TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 15.5,
          color: AppColors.ink,
        ),
        bodyMedium: const TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 14,
          color: AppColors.ink,
        ),
        bodySmall: const TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 12.5,
          color: AppColors.textSecondary,
        ),
        labelSmall: const TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppColors.textSecondary,
        ),
      );
}
