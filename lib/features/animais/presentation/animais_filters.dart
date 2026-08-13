import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Chip de filtro lote/piquete/categoria: "+ Lote" abre menu; selecionado
/// vira chip removível "Lote A ✕" (spec 3.5).
///
/// Extraído de `animais_screen.dart` (Task 3, quick task 260813-p10) para
/// ser compartilhado pela linha de filtros mobile e pela linha de filtros
/// desktop de `AnimaisTableView`.
class FilterMenuChip extends StatelessWidget {
  const FilterMenuChip({
    super.key,
    required this.addLabel,
    required this.selectedLabel,
    required this.entries,
    required this.onSelected,
    required this.onCleared,
  });

  final String addLabel;
  final String? selectedLabel;
  final Map<String, String> entries;
  final ValueChanged<String> onSelected;
  final VoidCallback onCleared;

  @override
  Widget build(BuildContext context) {
    final label = selectedLabel;
    if (label != null) {
      // Chip removível — tap remove o filtro.
      return InkWell(
        onTap: onCleared,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.positiveChipBg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryDarkText,
                ),
              ),
              const SizedBox(width: 5),
              const Icon(Icons.close,
                  size: 16, color: AppColors.primaryDarkText),
            ],
          ),
        ),
      );
    }
    return PopupMenuButton<String>(
      tooltip: addLabel,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final e in entries.entries)
          PopupMenuItem<String>(value: e.key, child: Text(e.value)),
      ],
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.chipBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              addLabel,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const Icon(Icons.expand_more,
                size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
