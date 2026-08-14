import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../animais/data/animal_constants.dart';
import '../../animais/data/animal_model.dart';
import '../../reproducao/presentation/reproducao_table_view.dart'
    show AtfScopeChip;
import '../data/piquete_model.dart';

String _fmt1(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

/// Header compartilhado das duas abas desktop de `/piquetes` (quadro e
/// tabela): título + agregados mono + segmented Piquetes/Lotes. Extraído de
/// `LotesTableView` (quick task 260813-v19) para não duplicar ~55 linhas no
/// quadro. `action` é opcional — `LotesTableView` passa "Novo lote",
/// `PiquetesBoardView` passa `null` (o quadro cria piquete pelo FAB da tela).
class PiquetesLotesHeader extends StatelessWidget {
  const PiquetesLotesHeader({
    super.key,
    required this.paddocks,
    required this.animalsByLot,
    required this.paddockCount,
    required this.lotCount,
    required this.showLots,
    required this.onShowLotsChanged,
    this.action,
  });

  final List<Paddock> paddocks;
  final Map<String, List<Animal>> animalsByLot;
  final int paddockCount;
  final int lotCount;
  final bool showLots;
  final ValueChanged<bool> onShowLotsChanged;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final uaOcupada = animalsByLot.values
        .fold<double>(0, (sum, animals) => sum + calcTotalUa(animals));
    final capacidadeTotal =
        paddocks.fold<double>(0, (sum, p) => sum + p.uaCapacity);
    final haTotal = paddocks.fold<double>(0, (sum, p) => sum + p.areaHa);
    final uaPorHa = haTotal > 0 ? uaOcupada / haTotal : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Piquetes e lotes',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_fmt1(uaOcupada)} / ${_fmt1(capacidadeTotal)} UA · '
                      '${_fmt1(haTotal)} ha · ${_fmt1(uaPorHa)} UA/ha',
                      style: monoStyle(
                        size: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: 12),
                action!,
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(
            children: [
              AtfScopeChip(
                label: 'Piquetes',
                count: paddockCount,
                selected: !showLots,
                onTap: () => onShowLotsChanged(false),
              ),
              const SizedBox(width: 8),
              AtfScopeChip(
                label: 'Lotes',
                count: lotCount,
                selected: showLots,
                onTap: () => onShowLotsChanged(true),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
