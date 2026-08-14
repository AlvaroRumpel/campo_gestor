import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/current_property_provider.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/campo_app_bar.dart';
import '../../../core/widgets/ui.dart';
import '../../../features/auth/data/property_repository.dart';
import '../../../features/gastos/presentation/paddock_expense_summary_card.dart';
import '../../../features/lotes/data/lote_repository.dart';
import '../../../features/lotes/presentation/_lots_section.dart';
import '../../../features/lotes/presentation/lote_form_dialog.dart';
import '../data/piquete_model.dart';
import '../data/piquete_repository.dart';

class PaddockDetailScreen extends ConsumerWidget {
  const PaddockDetailScreen({super.key, required this.paddockId});
  final String paddockId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paddockAsync = ref.watch(paddockByIdProvider(paddockId));
    final currentPropAsync = ref.watch(currentPropertyProvider);
    final membersAsync = ref.watch(memberPropertiesProvider);

    final canEdit = _canEdit(
      currentPropAsync.asData?.value,
      membersAsync.asData?.value,
    );

    final propertyId = currentPropAsync.asData?.value?.id ?? '';

    return Scaffold(
      appBar: DetailAppBar(
        parentLabel: 'Piquetes',
        onBack: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AppRoutes.piquetes);
          }
        },
      ),
      body: paddockAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(
          child: ErrorRetry(
            message: 'Erro ao carregar piquete.',
            onRetry: () => ref.invalidate(paddockByIdProvider(paddockId)),
          ),
        ),
        data: (paddock) {
          if (paddock == null) {
            return const Center(child: Text('Piquete não encontrado.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _PaddockInfoCard(paddock: paddock),
              const SizedBox(height: 8),
              PaddockExpenseSummaryCard(paddockId: paddockId),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Lotes',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 4),
              LotsSection(
                paddockId: paddockId,
                canEdit: canEdit,
                propertyId: propertyId,
              ),
            ],
          );
        },
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              tooltip: 'Novo lote',
              onPressed: propertyId.isEmpty
                  ? null
                  : () async {
                      final ok = await showAdaptiveForm<bool>(
                        context: context,
                        builder: (_) => LoteFormDialog(
                          paddockId: paddockId,
                          propertyId: propertyId,
                        ),
                      );
                      if (ok == true) {
                        ref.invalidate(loteListByPaddockProvider(paddockId));
                      }
                    },
              icon: const Icon(Icons.add, size: 22),
              label: const Text('Lote'),
            )
          : null,
    );
  }

  /// Vet-only gate for the "Novo lote" FAB — unchanged by Phase 7. A second,
  /// broader gate (`canManageExpenses`, `lib/core/auth/role_gates.dart`)
  /// now also lives on this screen for the expense surface; the two are
  /// deliberately different and never merged (D-23).
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

class _PaddockInfoCard extends StatelessWidget {
  const _PaddockInfoCard({required this.paddock});
  final Paddock paddock;

  String _fmtDouble(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: const Text('Nome'),
            subtitle: Text(paddock.name),
          ),
          ListTile(
            title: const Text('Área'),
            subtitle: Text('${_fmtDouble(paddock.areaHa)} ha'),
          ),
          ListTile(
            title: const Text('Capacidade'),
            subtitle: Text('${_fmtDouble(paddock.uaCapacity)} UA'),
          ),
        ],
      ),
    );
  }
}
