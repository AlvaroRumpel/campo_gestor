import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/invalidate_property_data.dart';
import '../../../core/widgets/ui.dart';
import '../../animais/data/animal_repository.dart';
import '../data/lote_model.dart';
import '../data/lote_repository.dart';
import 'lote_form_dialog.dart';

/// Ações compartilhadas de lote (renomear/arquivar) — extraídas de
/// `_lots_section.dart` para ficarem alcançáveis também em
/// `LoteDetailScreen` e `LoteDetailPanel` (ACES-03).

/// Abre o `LoteFormDialog` em modo edição (só o nome, D-12).
/// Retorna true se salvou.
Future<bool> editLotName(
  BuildContext context,
  WidgetRef ref,
  Lot lot,
) async {
  final ok = await showAdaptiveForm<bool>(
    context: context,
    builder: (_) => LoteFormDialog(
      paddockId: lot.paddockId,
      propertyId: lot.propertyId,
      existing: lot,
    ),
  );
  if (ok == true) {
    ref.invalidatePropertyData();
    return true;
  }
  return false;
}

/// Arquivar lote — único caminho de UI para softDeleteLot, exigido para
/// esvaziar um piquete antes de removê-lo (QA 2026-08-19, item 1).
/// trg_lots_archive_guard (20260814_10) bloqueia no banco; aqui a checagem
/// serve para explicar antes, e o catch de 23514 cobre a corrida.
/// Retorna true se o lote foi arquivado.
Future<bool> archiveLot(
  BuildContext context,
  WidgetRef ref,
  Lot lot,
) async {
  final animals = await ref.read(animalListByLotProvider(lot.id).future);
  if (!context.mounted) return false;
  final active = animals.where((a) => a.deletedAt == null).length;
  final messenger = ScaffoldMessenger.of(context);
  if (active > 0) {
    messenger
        .showSnackBar(SnackBar(content: Text(_blockedMessage(active))));
    return false;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Arquivar "${lot.name}"?'),
      content: const Text(
        'O lote sai das listas da propriedade. O piquete fica livre para '
        'ser removido.',
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Arquivar'),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;

  try {
    await ref.read(loteRepositoryProvider).softDeleteLot(lot.id);
    ref.invalidatePropertyData();
    return true;
  } on PostgrestException catch (e) {
    ref.invalidatePropertyData();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          e.code == '23514'
              ? _blockedMessage(1)
              : 'Não foi possível arquivar o lote. Tente novamente.',
        ),
      ),
    );
    return false;
  }
}

String _blockedMessage(int count) => Intl.plural(
      count,
      one: 'Lote tem 1 animal ativo. Mova ou dê baixa antes de arquivar.',
      other: 'Lote tem $count animais ativos. Mova ou dê baixa antes de '
          'arquivar.',
      locale: 'pt_BR',
    );
