import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui.dart';
import '../../animais/data/animal_constants.dart';
import '../../animais/data/animal_model.dart';
import '../../animais/data/animal_repository.dart';
import '../data/lote_repository.dart';

String _fmtUa(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

/// Lista de todos os lotes da propriedade — o destino "Lotes" do segmented
/// control em /piquetes (spec 4.6). Cada card: nome + piquete + UA total à
/// direita + chips de composição por categoria. Tap → /lotes/:id.
class LotesListView extends ConsumerWidget {
  const LotesListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lotsAsync = ref.watch(loteWithPaddockListByPropertyProvider);
    final animalsAsync = ref.watch(animalListByPropertyProvider);

    return lotsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Center(child: Text('Erro ao carregar lotes.')),
      data: (lots) {
        if (lots.isEmpty) {
          return const EmptyState(
            icon: Icons.group_work_outlined,
            title: 'Nenhum lote cadastrado',
            message:
                'Crie lotes dentro de um piquete para organizar os animais.',
          );
        }
        // Active animals grouped by lot for composition chips + UA.
        final byLot = <String, List<Animal>>{};
        for (final ctx in animalsAsync.asData?.value ??
            const <AnimalWithContext>[]) {
          if (ctx.animal.deletedAt != null) continue;
          (byLot[ctx.animal.lotId] ??= []).add(ctx.animal);
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 96),
          itemCount: lots.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _LoteCard(
            item: lots[i],
            animals: byLot[lots[i].lot.id] ?? const [],
          ),
        );
      },
    );
  }
}

class _LoteCard extends StatelessWidget {
  const _LoteCard({required this.item, required this.animals});

  final LotWithPaddockCount item;
  final List<Animal> animals;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final a in animals) {
      counts[a.category] = (counts[a.category] ?? 0) + 1;
    }
    final totalUa = calcTotalUa(animals);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(AppRoutes.loteDetail(item.lot.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.lot.name,
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.paddockName,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${_fmtUa(totalUa)} UA',
                    style: monoStyle(size: 15, weight: FontWeight.w700),
                  ),
                ],
              ),
              if (counts.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final cat
                        in kCategories.where((c) => (counts[c] ?? 0) > 0))
                      _CompositionChip(
                        count: counts[cat]!,
                        label: counts[cat] == 1
                            ? kCategoryLabels[cat]!
                            : kCategoryLabelsPlural[cat]!,
                        ua: counts[cat]! * (kUaWeights[cat] ?? 0),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip de composição "3 Vacas 3,0" — bg #F1F4EC r8, números em mono.
class _CompositionChip extends StatelessWidget {
  const _CompositionChip({
    required this.count,
    required this.label,
    required this.ua,
  });

  final int count;
  final String label;
  final double ua;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$count ',
              style: monoStyle(size: 12.5, weight: FontWeight.w600),
            ),
            TextSpan(
              text: '$label ',
              style: const TextStyle(fontSize: 12.5, color: AppColors.ink),
            ),
            TextSpan(
              text: _fmtUa(ua),
              style: monoStyle(size: 12.5, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
