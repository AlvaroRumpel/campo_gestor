import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/animais/data/animal_repository.dart';
import '../../features/gastos/data/expense_repository.dart';
import '../../features/lotes/data/lote_repository.dart';
import '../../features/piquetes/data/piquete_repository.dart';
import '../../features/reproducao/data/atf_repository.dart';
import '../../features/sanitario/data/dose_repository.dart';
import '../../features/sanitario/data/sanitary_application_repository.dart';

/// Invalida todo provider de leitura escopado à propriedade ativa.
///
/// Chamar após QUALQUER create/update/delete. Antes disso cada site de
/// mutação invalidava um subconjunto incompleto à mão, e listas irmãs
/// ficavam stale até um F5 (relatório de QA 2026-08-19, itens 2 e 3).
///
/// Custo: refetch das listas montadas no momento — os providers derivados
/// (dashboard) se atualizam sozinhos porque fazem `watch` destes.
/// ponytail: invalidação seletiva só se virar gargalo medido.
extension InvalidatePropertyData on WidgetRef {
  void invalidatePropertyData() {
    // Passar a family sem argumento invalida todos os seus membros.
    invalidate(paddockListProvider);
    invalidate(paddockByIdProvider);

    invalidate(loteListByPaddockProvider);
    invalidate(loteListByPropertyProvider);
    invalidate(loteWithPaddockListByPropertyProvider);
    invalidate(loteByIdProvider);
    invalidate(loteWithPaddockByIdProvider);

    invalidate(animalListByPropertyProvider);
    invalidate(animalListByLotProvider);
    invalidate(animalByIdProvider);

    invalidate(atfListByPropertyProvider);
    invalidate(atfByIdProvider);
    invalidate(atfMembershipsProvider);
    invalidate(atfActiveMembershipsProvider);
    invalidate(dgRecordsByAtfProvider);
    invalidate(reproductiveHistoryByAnimalProvider);
    invalidate(animalReproStatusByPropertyProvider);
    invalidate(eligibleAnimalsForAtfProvider);

    invalidate(doseListByPropertyProvider);
    invalidate(archivedDoseListByPropertyProvider);
    invalidate(sanitaryApplicationListByPropertyProvider);
    invalidate(sanitaryApplicationsByLotProvider);
    invalidate(sanitaryApplicationByIdProvider);
    invalidate(sanitaryHistoryByAnimalProvider);

    invalidate(unifiedExpenseListByPropertyProvider);
    invalidate(unifiedExpenseListByPaddockProvider);
    invalidate(unifiedExpenseListWithDeletedByPaddockProvider);
    invalidate(paddockMonthExpenseTotalProvider);
  }
}
