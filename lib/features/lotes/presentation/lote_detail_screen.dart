import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/current_property_provider.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/campo_app_bar.dart';
import '../../../core/widgets/ui.dart';
import '../../../features/animais/data/animal_constants.dart';
import '../../../features/animais/data/animal_model.dart';
import '../../../features/animais/data/animal_repository.dart';
import '../../../features/animais/presentation/animal_form_dialog.dart';
import '../../../features/auth/data/property_repository.dart';
import '../../../features/piquetes/data/piquete_repository.dart';
import '../../sanitario/data/sanitary_application_repository.dart';
import '../../sanitario/presentation/aplicacao_form_dialog.dart';
import '../../sanitario/presentation/sanitary_history_section.dart';
import '../data/lote_model.dart';
import '../data/lote_repository.dart';
import 'mover_lote_dialog.dart';

String _fmtUa(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

/// Cores das barras de composição por linha (spec 4.7).
const _compositionColors = [
  AppColors.primary,
  AppColors.greenMid,
  AppColors.greenLight,
];

class LoteDetailScreen extends ConsumerWidget {
  const LoteDetailScreen({super.key, required this.loteId});
  final String loteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lotAsync = ref.watch(loteByIdProvider(loteId));
    final animalsAsync = ref.watch(animalListByLotProvider(loteId));
    final currentPropAsync = ref.watch(currentPropertyProvider);
    final membersAsync = ref.watch(memberPropertiesProvider);
    final canEdit = _canEdit(
      currentPropAsync.asData?.value,
      membersAsync.asData?.value,
    );

    return Scaffold(
      appBar: DetailAppBar(
        parentLabel: 'Lotes',
        onBack: () {
          if (context.canPop()) {
            context.pop();
            return;
          }
          final paddockId = lotAsync.asData?.value?.paddockId;
          if (paddockId != null) {
            context.go('/piquetes/$paddockId');
          } else {
            context.go(AppRoutes.piquetes);
          }
        },
      ),
      body: lotAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Erro ao carregar lote.')),
        data: (lot) {
          if (lot == null) {
            return const Center(child: Text('Lote não encontrado.'));
          }
          final activeAnimals = (animalsAsync.asData?.value ?? const <Animal>[])
              .where((a) => a.deletedAt == null)
              .toList();
          final showActions =
              canEdit && lot.deletedAt == null && activeAnimals.isNotEmpty;
          return Column(
            children: [
              _LoteHeader(lot: lot, activeAnimals: activeAnimals),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 96),
                  children: [
                    // MOV-02/SANI-02: ações gated por canEdit + lote ativo +
                    // ao menos 1 animal ativo (D-18: espelho exato do gate de mover)
                    if (showActions) ...[
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _onRegistrar(context, ref),
                              icon: const Icon(
                                Icons.medical_services_outlined,
                                size: 20,
                              ),
                              label: const Text('Aplicação'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _onMover(
                                context,
                                ref,
                                lot,
                                activeAnimals.length,
                              ),
                              icon: const Icon(Icons.swap_horiz, size: 20),
                              label: const Text('Mover lote'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    _ComposicaoCard(animals: activeAnimals),
                    const SizedBox(height: 12),
                    _AnimaisCard(animalsAsync: animalsAsync),
                    const SizedBox(height: 12),
                    LoteSanitaryHistorySection(lotId: loteId),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () async {
                final lot = lotAsync.asData?.value;
                if (lot == null) return;
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AnimalFormDialog(
                    lotId: loteId,
                    propertyId: lot.propertyId,
                  ),
                );
                if (ok == true) {
                  ref.invalidate(animalListByLotProvider(loteId));
                  ref.invalidate(animalListByPropertyProvider);
                }
              },
              icon: const Icon(Icons.add, size: 22),
              label: const Text('Animal'),
            )
          : null,
    );
  }

  Future<void> _onMover(
    BuildContext context,
    WidgetRef ref,
    Lot lot,
    int activeCount,
  ) async {
    final result = await showAdaptiveForm<Map<String, String>>(
      context: context,
      builder: (_) => MoverLoteDialog(
        lot: lot,
        activeAnimalCount: activeCount,
      ),
    );
    if (result != null && context.mounted) {
      final paddockName = result['paddockName'] ?? '';
      ref.invalidate(loteByIdProvider(loteId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lote movido para $paddockName')),
      );
    }
  }

  Future<void> _onRegistrar(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AplicacaoFormDialog(
        lotId: loteId,
        onRegistered: (count) {
          if (!context.mounted) return;
          ref.invalidate(animalListByLotProvider(loteId));
          ref.invalidate(sanitaryApplicationsByLotProvider(loteId));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(sanitaryRegisteredMessage(count))),
          );
        },
      ),
    );
  }

  bool _canEdit(
    SelectedProperty? current,
    List<PropertyMembership>? members,
  ) {
    if (current == null || members == null) return false;
    final role = members
        .where((m) => m.property.id == current.id)
        .map((m) => m.role)
        .firstOrNull;
    return role == 'veterinarian';
  }
}

/// Header verde (spec 4.7): nome 26/700 + "Piquete X · N animais ativos" +
/// badge laranja retangular com a UA total do lote.
class _LoteHeader extends ConsumerWidget {
  const _LoteHeader({required this.lot, required this.activeAnimals});

  final Lot lot;
  final List<Animal> activeAnimals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paddockAsync = ref.watch(paddockByIdProvider(lot.paddockId));
    final paddockName = paddockAsync.asData?.value?.name ?? '—';
    final count = activeAnimals.length;
    final ua = calcTotalUa(activeAnimals);

    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lot.name,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onGreen,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$paddockName · $count ${count == 1 ? 'animal ativo' : 'animais ativos'}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.onGreenSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${_fmtUa(ua)} UA',
              style: monoStyle(
                size: 15,
                weight: FontWeight.w700,
                color: AppColors.onAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card Composição: linhas categoria + barra proporcional + "3 · 3,0" mono.
class _ComposicaoCard extends StatelessWidget {
  const _ComposicaoCard({required this.animals});

  final List<Animal> animals;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final a in animals) {
      counts[a.category] = (counts[a.category] ?? 0) + 1;
    }
    final present =
        kCategories.where((c) => (counts[c] ?? 0) > 0).toList();
    final total = animals.length;

    return SectionCard(
      title: 'Composição',
      child: present.isEmpty
          ? const Text(
              'Sem animais ativos.',
              style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
            )
          : Column(
              children: [
                for (final (i, cat) in present.indexed) ...[
                  if (i > 0) const SizedBox(height: 10),
                  Row(
                    children: [
                      SizedBox(
                        width: 88,
                        child: Text(
                          kCategoryLabelsPlural[cat]!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: StackedBar(
                          height: 10,
                          segments: [
                            StackedBarSegment(
                              total > 0 ? counts[cat]! / total : 0,
                              _compositionColors[i % _compositionColors.length],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 62,
                        child: Text(
                          '${counts[cat]} · ${_fmtUa(counts[cat]! * (kUaWeights[cat] ?? 0))}',
                          textAlign: TextAlign.right,
                          style: monoStyle(size: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}

/// Card Animais: linhas 48h — nº mono + categoria·raça + EC.
class _AnimaisCard extends StatelessWidget {
  const _AnimaisCard({required this.animalsAsync});

  final AsyncValue<List<Animal>> animalsAsync;

  @override
  Widget build(BuildContext context) {
    return animalsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Erro ao carregar animais.'),
        ),
      ),
      data: (animals) {
        final active = animals.where((a) => a.deletedAt == null).toList()
          ..sort((a, b) => a.number.compareTo(b.number));
        if (active.isEmpty) {
          return const Card(
            child: EmptyState(
              icon: Icons.pets_outlined,
              title: 'Nenhum animal neste lote',
              message: 'Use o botão + para adicionar animais individualmente.',
            ),
          );
        }
        return SectionCard(
          title: 'Animais',
          trailing: Text(
            '${active.length}',
            style: monoStyle(size: 12, color: AppColors.textSecondary),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            children: [
              for (final (i, a) in active.indexed)
                InkWell(
                  onTap: () => context.go(AppRoutes.animalDetail(a.id)),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    decoration: i > 0
                        ? const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: AppColors.divider),
                            ),
                          )
                        : null,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 42,
                          child: Text(
                            '${a.number}',
                            style: monoStyle(
                              size: 16,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            [
                              kCategoryLabels[a.category] ?? a.category,
                              if (a.breed != null && a.breed!.isNotEmpty)
                                a.breed!,
                            ].join(' · '),
                            style: const TextStyle(fontSize: 14.5),
                          ),
                        ),
                        if (a.bodyCondition != null)
                          Text(
                            'EC ${a.bodyCondition}',
                            style: monoStyle(
                              size: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
