import 'package:flutter/material.dart';

/// Design tokens do redesign "musgo evoluído" (Campo Gestor - Redesign.dc.html).
///
/// Fonte única de cor fora do ColorScheme. Regras transversais:
/// destrutivo = [danger] + confirmação; semáforo de lotação
/// verde → laranja (~90%) → vermelho (>=100%); todo número em IBM Plex Mono.
abstract final class AppColors {
  // Verdes
  static const Color primary = Color(0xFF3D5435); // verde musgo
  static const Color primaryDarkText = Color(0xFF2F4429);
  static const Color greenMid = Color(0xFF6D8B5C); // dataviz 2
  static const Color greenLight = Color(0xFFA8C08F); // accent claro

  // Laranja (CTA)
  static const Color accent = Color(0xFFE8833A);
  static const Color accentDark = Color(0xFFC96A28); // links, warnings
  static const Color onAccent = Color(0xFF2A1806);
  static const Color accentTextDark = Color(0xFF8A4413); // texto em fundo laranja claro
  static const Color accentContainer = Color(0xFFFFF3E6); // banners
  static const Color accentChipBg = Color(0x29E8833A); // rgba(232,131,58,0.16)
  static const Color accentBorder = Color(0x59E8833A); // rgba .35

  // Vermelho (danger)
  static const Color danger = Color(0xFFA32D14);
  static const Color dangerText = Color(0xFF8A2711);
  static const Color onDanger = Color(0xFFFFF6F3);
  static const Color dangerChipBg = Color(0x1FA32D14); // rgba .12
  static const Color dangerContainer = Color(0xFFFDECE7);
  static const Color onDangerContainer = Color(0xFF6E1F0C);

  // Superfícies
  static const Color background = Color(0xFFF5F3EB); // bone
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F4EC);
  static const Color surfaceSubtle = Color(0xFFFAFAF7);
  static const Color statsStrip = Color(0xFFE9EDE2);

  // Texto
  static const Color ink = Color(0xFF23281E);
  static const Color textSecondary = Color(0x9923281E); // ~0.6
  static const Color textTertiary = Color(0x7323281E); // ~0.45
  static const Color onGreen = Color(0xFFF5F3EB);
  static const Color onGreenSecondary = Color(0xB3F5F3EB); // ~0.7
  static const Color onGreenMuted = Color(0xCCF5F3EB); // ~0.8, item de nav inativo sobre verde
  static const Color gold = Color(0xFFE8CE9A); // destaque em header verde

  // Bordas / tracks
  static const Color divider = Color(0x1223281E); // ~0.07
  static const Color chipBorder = Color(0x2423281E); // ~0.14
  static const Color inputBorder = Color(0x2923281E); // ~0.16
  static const Color outlineBorder = Color(0x2E23281E); // ~0.18
  static const Color track = Color(0x1523281E); // ~0.08
  static const Color positiveChipBg = Color(0x1F3D5435); // rgba(61,84,53,0.12)
  static const Color navPillBg = Color(0x243D5435); // rgba .14
  static const Color neutralChipBg = Color(0x1423281E); // rgba .08

  // Glass (sobre header verde)
  static const Color glassCard = Color(0x1FF5F3EB); // .12
  static const Color glassPill = Color(0x24F5F3EB); // .14
  static const Color glassStrong = Color(0x2EF5F3EB); // .18
  static const Color scrim = Color(0x731F2A19); // rgba(31,42,25,0.45)

  /// Semáforo de lotação: [ratio] = UA atual / capacidade.
  static Color capacityColor(double ratio) {
    if (ratio >= 1.0) return danger;
    if (ratio >= 0.9) return accent;
    return primary;
  }
}

/// Famílias tipográficas do redesign.
abstract final class AppFonts {
  static const String ui = 'Archivo';
  static const String mono = 'IBMPlexMono';
}

/// Estilo mono para dados numéricos (números de animal, UA, datas, R$, %).
TextStyle monoStyle({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color color = AppColors.ink,
  double? letterSpacing,
  double? height,
}) =>
    TextStyle(
      fontFamily: AppFonts.mono,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
