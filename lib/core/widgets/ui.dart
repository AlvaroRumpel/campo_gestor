import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/breakpoints.dart';

/// Primitivas visuais do redesign, compartilhadas entre features.
/// Anatomias vêm do spec "musgo evoluído" (seções 3.x).

// ─── Chips de status ───

enum StatusKind { positive, warning, danger, neutral }

class StatusChip extends StatelessWidget {
  const StatusChip(
    this.label, {
    super.key,
    required this.kind,
    this.solid = false,
  });

  final String label;
  final StatusKind kind;

  /// Variante sólida (ex.: "Prenhe" na timeline).
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = solid
        ? (AppColors.primary, AppColors.onGreen)
        : switch (kind) {
            StatusKind.positive =>
              (AppColors.positiveChipBg, AppColors.primaryDarkText),
            StatusKind.warning =>
              (AppColors.accentChipBg, AppColors.accentTextDark),
            StatusKind.danger => (AppColors.dangerChipBg, AppColors.dangerText),
            StatusKind.neutral => (AppColors.neutralChipBg, AppColors.ink),
          };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

// ─── Label overline (seções, labels de input) ───

class OverlineLabel extends StatelessWidget {
  const OverlineLabel(this.text, {super.key, this.color, this.mono = false});

  final String text;
  final Color? color;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: mono ? AppFonts.mono : AppFonts.ui,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: color ?? AppColors.textSecondary,
      ),
    );
  }
}

// ─── Card padrão de seção (branco r16, sem sombra) ───

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.title,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

// ─── Empty state ───

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: AppColors.primaryDarkText),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

// ─── Barra de lotação (semáforo) ───

class CapacityBar extends StatelessWidget {
  const CapacityBar({
    super.key,
    required this.current,
    required this.capacity,
    this.height = 8,
  });

  final double current;
  final double capacity;
  final double height;

  @override
  Widget build(BuildContext context) {
    final ratio = capacity > 0 ? current / capacity : 0.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: ratio.clamp(0.0, 1.0),
        minHeight: height,
        color: AppColors.capacityColor(ratio),
        backgroundColor: AppColors.track,
      ),
    );
  }
}

// ─── Barra empilhada (composição / categorias) ───

class StackedBarSegment {
  const StackedBarSegment(this.fraction, this.color);
  final double fraction;
  final Color color;
}

class StackedBar extends StatelessWidget {
  const StackedBar({super.key, required this.segments, this.height = 12});

  final List<StackedBarSegment> segments;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            for (final s in segments)
              if (s.fraction > 0)
                Expanded(
                  flex: (s.fraction * 1000).round(),
                  child: ColoredBox(color: s.color),
                ),
            if (segments.fold<double>(0, (a, s) => a + s.fraction) < 1)
              Expanded(
                flex: ((1 -
                            segments.fold<double>(
                                0, (a, s) => a + s.fraction)) *
                        1000)
                    .round(),
                child: const ColoredBox(color: AppColors.track),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Tile glass (sobre header verde) ───

class GlassTile extends StatelessWidget {
  const GlassTile({
    super.key,
    required this.label,
    required this.value,
    this.mono = false,
    this.onTap,
  });

  final String label;
  final String value;
  final bool mono;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.glassCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
              color: Color(0xA6F5F3EB),
            ),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: mono ? AppFonts.mono : AppFonts.ui,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onGreen,
                  ),
                ),
              ),
              if (onTap != null)
                const Icon(Icons.expand_more,
                    size: 18, color: AppColors.onGreenSecondary),
            ],
          ),
        ],
      ),
    );
    if (onTap == null) return tile;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: tile,
    );
  }
}

// ─── Medidor de estado corporal (EC n/5) ───

class EcMeter extends StatelessWidget {
  const EcMeter({super.key, required this.score, this.max = 5});

  final int score;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < max; i++) ...[
          Container(
            width: 18,
            height: 6,
            decoration: BoxDecoration(
              color: i < score ? AppColors.primary : AppColors.chipBorder,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 3),
        ],
        const SizedBox(width: 5),
        Text('$score/$max',
            style: monoStyle(size: 14, weight: FontWeight.w600)),
      ],
    );
  }
}

// ─── Faixa de totais (bg #E9EDE2) ───

class StatsStrip extends StatelessWidget {
  const StatsStrip({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.statsStrip,
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: child,
    );
  }
}

// ─── Avatar da fazenda (iniciais, quadrado arredondado) ───

class FarmAvatar extends StatelessWidget {
  const FarmAvatar({
    super.key,
    required this.name,
    this.size = 30,
    this.background = AppColors.glassStrong,
    this.foreground = AppColors.onGreen,
  });

  final String name;
  final double size;
  final Color background;
  final Color foreground;

  static String initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size >= 36 ? 10 : 8),
      ),
      child: Text(
        initials(name),
        style: monoStyle(
          size: size * 0.4,
          weight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

// ─── Aviso de imutabilidade (lock) ───

class ImmutabilityNotice extends StatelessWidget {
  const ImmutabilityNotice({super.key, this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.lock_outline, size: 19, color: AppColors.accentTextDark),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text ??
                'Registro permanente: depois de salvo só pode ser estornado, '
                    'nunca editado ou apagado.',
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: Color(0xB323281E),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Erro de rede com retry ───

/// Mensagem de erro + botão "Tentar novamente". Sem `Center` embutido —
/// vários call sites já ficam dentro de um `Center`/`Column` próprio.
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Tentar novamente'),
        ),
      ],
    );
  }
}

// ─── Banner laranja "precisa de você" / avisos ───

class WarningBanner extends StatelessWidget {
  const WarningBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.accentContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accentBorder),
      ),
      child: child,
    );
  }
}

// ─── Formulário adaptativo: bottom sheet (<600px) ou dialog de largura
// configurável (>=600px). [FormWidth] dá as três larguras contratadas:
// confirmação destrutiva curta, formulário padrão de uma coluna e
// formulário largo com campos lado a lado. ───

abstract final class FormWidth {
  static const double confirm = 440;
  static const double form = 560;
  static const double wide = 680;
}

Future<T?> showAdaptiveForm<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double width = FormWidth.form,
}) {
  final isWide = MediaQuery.sizeOf(context).width >= Breakpoints.mobile;
  if (isWide) {
    return showDialog<T>(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width),
          child: builder(ctx),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: builder(ctx),
    ),
  );
}
