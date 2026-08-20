import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'property_selector.dart';

/// App bar verde padrão das telas do shell: seletor de fazenda à esquerda,
/// título da tela à direita (spec 3.1).
class CampoAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CampoAppBar({super.key, required this.title, this.showBack = false});

  final String title;

  /// true nas telas root-level fora do shell (grade sanitária, import) —
  /// mostra a seta de voltar antes do seletor de propriedade.
  final bool showBack;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 14,
      title: Row(
        children: [
          if (showBack)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.onGreen),
              tooltip: 'Voltar',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          const Expanded(child: PropertySelector()),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.onGreen,
            ),
          ),
        ],
      ),
    );
  }
}

/// App bar verde de telas de detalhe: back + label da tela-mãe à esquerda,
/// pill de contexto (fazenda/status) opcional à direita (spec 3.1 variante).
class DetailAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DetailAppBar({
    super.key,
    required this.parentLabel,
    this.contextPill,
    this.onBack,
    this.actions,
  });

  final String parentLabel;
  final Widget? contextPill;
  final VoidCallback? onBack;

  /// Ações extras (ex.: recarregar) renderizadas à direita do contextPill.
  /// Opcional para não afetar os demais usos de [DetailAppBar] (G-10-03).
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 6,
      toolbarHeight: 48,
      title: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 24),
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            tooltip: 'Voltar',
          ),
          Expanded(
            child: Text(
              parentLabel,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.onGreenSecondary,
              ),
            ),
          ),
          ?contextPill,
          ...?actions,
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// Pill de contexto de fazenda para app bars de detalhe
/// (dot verde-claro + nome da fazenda).
class FarmContextPill extends StatelessWidget {
  const FarmContextPill({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.glassPill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.greenLight,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            name,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.onGreen,
            ),
          ),
        ],
      ),
    );
  }
}
