import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/invalidate_property_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui.dart';
import '../../lotes/data/lote_repository.dart';
import '../data/piquete_model.dart';
import '../data/piquete_repository.dart';
import 'paddock_form_dialog.dart';

/// Ações compartilhadas de piquete (editar/remover) — extraídas de
/// `piquetes_screen.dart` para ficarem alcançáveis também no board desktop
/// e em `PaddockDetailScreen` (ACES-01/ACES-02).

/// Abre o `PaddockFormDialog` (criar quando `paddock == null`).
/// Retorna true se salvou.
Future<bool> editPaddock(
  BuildContext context,
  WidgetRef ref, {
  Paddock? paddock,
}) async {
  final result = await showAdaptiveForm<bool>(
    context: context,
    builder: (_) => PaddockFormDialog(existing: paddock),
  );
  if (result == true) {
    ref.invalidatePropertyData();
    return true;
  }
  return false;
}

/// Mensagem única do bloqueio (UI e corrida no banco convergem aqui).
String _blockedMessage(int lotCount) => Intl.plural(
      lotCount,
      one: 'Não é possível remover: o piquete tem 1 lote. Mova ou '
          'arquive o lote antes.',
      other: 'Não é possível remover: o piquete tem $lotCount lotes. '
          'Mova ou arquive os lotes antes.',
      locale: 'pt_BR',
    );

/// Remover (soft delete) piquete, com pré-checagem de lotes ativos.
/// trg_paddocks_archive_guard bloqueia no banco; aqui a UI explica antes.
/// Retorna true se o piquete foi removido.
Future<bool> confirmDeletePaddock(
  BuildContext context,
  WidgetRef ref,
  Paddock paddock,
) async {
  // Piquete com lote ativo deixaria lote e animais órfãos (QA 2026-08-19,
  // item 1).
  final lots = await ref.read(loteWithPaddockListByPropertyProvider.future);
  if (!context.mounted) return false;
  final activeLots = lots
      .where((l) => l.lot.paddockId == paddock.id && l.lot.deletedAt == null)
      .length;
  if (activeLots > 0) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover piquete'),
        content: Text(_blockedMessage(activeLots)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
    return false;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Remover piquete'),
      content: Text(
        'Tem certeza que deseja remover "${paddock.name}"?',
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: AppColors.onDanger,
          ),
          child: const Text('Remover'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  try {
    await ref.read(paddockRepositoryProvider).softDeletePaddock(paddock.id);
    ref.invalidatePropertyData();
    return true;
  } on PostgrestException catch (e) {
    // 23514 = trg_paddocks_archive_guard. Só chega aqui numa corrida (um
    // lote criado entre a checagem acima e o UPDATE).
    if (!context.mounted) return false;
    ref.invalidatePropertyData();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          e.code == '23514'
              ? _blockedMessage(1)
              : 'Não foi possível remover o piquete. Tente novamente.',
        ),
      ),
    );
    return false;
  }
}
