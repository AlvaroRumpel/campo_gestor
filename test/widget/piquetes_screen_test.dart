// PROP-02 UI — PiquetesScreen redesign (spec 4.5/4.6): segmented control
// Piquetes/Lotes, cards de piquete com semáforo de lotação e empty states.
import 'package:campo_gestor/features/animais/data/animal_model.dart';
import 'package:campo_gestor/features/animais/data/animal_repository.dart';
import 'package:campo_gestor/features/gastos/data/expense_repository.dart';
import 'package:campo_gestor/features/lotes/data/lote_model.dart';
import 'package:campo_gestor/features/lotes/data/lote_repository.dart';
import 'package:campo_gestor/features/piquetes/data/piquete_model.dart';
import 'package:campo_gestor/features/piquetes/data/piquete_repository.dart';
import 'package:campo_gestor/features/piquetes/presentation/piquetes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:riverpod/misc.dart' show Override;

final _paddock = Paddock(
  id: 'pad-1',
  propertyId: 'prop-1',
  name: 'Piquete 1',
  areaHa: 8.5,
  uaCapacity: 12,
  createdAt: DateTime(2026, 1, 1),
);

final _lot = Lot(
  id: 'lot-1',
  propertyId: 'prop-1',
  paddockId: 'pad-1',
  name: 'Lote A',
  createdAt: DateTime(2026, 1, 1),
);

AnimalWithContext _vaca(String id) => AnimalWithContext(
      animal: Animal(
        id: id,
        propertyId: 'prop-1',
        lotId: 'lot-1',
        category: 'vaca',
        number: int.parse(id),
        createdAt: DateTime(2026, 1, 1),
      ),
      lotName: 'Lote A',
      paddockId: 'pad-1',
      paddockName: 'Piquete 1',
    );

Widget _buildScreen({
  List<Paddock> paddocks = const [],
  List<LotWithPaddockCount> lots = const [],
  List<AnimalWithContext> animals = const [],
  List<Override> extra = const [],
}) {
  return ProviderScope(
    overrides: [
      paddockListProvider.overrideWith((ref) async => paddocks),
      loteWithPaddockListByPropertyProvider.overrideWith((ref) async => lots),
      animalListByPropertyProvider.overrideWith((ref) async => animals),
      paddockMonthExpenseTotalProvider.overrideWith((ref, id) async => 980.0),
      ...extra,
    ],
    child: const MaterialApp(home: PiquetesScreen()),
  );
}

void main() {
  testWidgets('PiquetesScreen shows empty state copy when list is empty',
      (tester) async {
    await tester.pumpWidget(_buildScreen());
    await tester.pumpAndSettle();
    expect(find.text('Nenhum piquete cadastrado'), findsOneWidget);
    expect(
      find.text(
          'Adicione piquetes para começar a organizar os lotes da fazenda.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'paddock card renders stats, Folga chip and lots/animals footer '
      '(spec 4.5)', (tester) async {
    await tester.pumpWidget(_buildScreen(
      paddocks: [_paddock],
      lots: [
        LotWithPaddockCount(
          lot: _lot,
          paddockName: 'Piquete 1',
          activeAnimalCount: 2,
        ),
      ],
      animals: [_vaca('1'), _vaca('2')],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Piquete 1'), findsOneWidget);
    // 2 vacas = 2,0 UA de 12,0 → folga
    expect(find.text('Folga'), findsOneWidget);
    expect(find.text('8,5'), findsOneWidget); // hectares
    expect(find.text('2,0'), findsOneWidget); // UA atual
    expect(find.text('12,0'), findsOneWidget); // capacidade
    expect(find.text('1 lote · 2 animais'), findsOneWidget);
    expect(find.textContaining('980'), findsOneWidget); // gasto do mês
    expect(find.text(' no mês'), findsOneWidget);
  });

  testWidgets('paddock card shows Superlotado chip when UA >= capacity',
      (tester) async {
    final tight = Paddock(
      id: 'pad-1',
      propertyId: 'prop-1',
      name: 'Piquete 1',
      areaHa: 8.5,
      uaCapacity: 1,
      createdAt: DateTime(2026, 1, 1),
    );
    await tester.pumpWidget(_buildScreen(
      paddocks: [tight],
      animals: [_vaca('1'), _vaca('2')],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Superlotado'), findsOneWidget);
  });

  testWidgets(
      'segmented control switches to the Lotes list and back (spec 4.6)',
      (tester) async {
    await tester.pumpWidget(_buildScreen());
    await tester.pumpAndSettle();

    // Both segments present ('Piquetes' also appears in the CampoAppBar
    // title, so scope the segment finders to their InkWell buttons)
    expect(find.widgetWithText(InkWell, 'Piquetes'), findsOneWidget);
    expect(find.widgetWithText(InkWell, 'Lotes'), findsOneWidget);

    await tester.tap(find.widgetWithText(InkWell, 'Lotes'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum lote cadastrado'), findsOneWidget);

    await tester.tap(find.widgetWithText(InkWell, 'Piquetes'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum piquete cadastrado'), findsOneWidget);
  });

  testWidgets('Lotes segment lists lots with paddock, UA and composition',
      (tester) async {
    await tester.pumpWidget(_buildScreen(
      paddocks: [_paddock],
      lots: [
        LotWithPaddockCount(
          lot: _lot,
          paddockName: 'Piquete 1',
          activeAnimalCount: 2,
        ),
      ],
      animals: [_vaca('1'), _vaca('2')],
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lotes'));
    await tester.pumpAndSettle();

    expect(find.text('Lote A'), findsOneWidget);
    expect(find.text('Piquete 1'), findsOneWidget);
    expect(find.text('2,0 UA'), findsOneWidget); // 2 vacas
    expect(find.textContaining('Vacas'), findsOneWidget); // chip composição
  });
}
