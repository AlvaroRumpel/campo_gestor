// Quick task 260813-q69 — AnimalDetailScreen desktop layout (>=1024px):
// horizontal green header + two-column body (340px context / up to 760px
// timeline). Below 1024px the layout is untouched — proven by
// animal_detail_screen_test.dart staying byte-for-byte unedited (see this
// plan's Task 2 verify step).
import 'package:campo_gestor/core/providers/current_property_provider.dart';
import 'package:campo_gestor/core/widgets/ui.dart';
import 'package:campo_gestor/features/animais/data/animal_model.dart';
import 'package:campo_gestor/features/animais/data/animal_repository.dart';
import 'package:campo_gestor/features/animais/presentation/animal_detail_screen.dart';
import 'package:campo_gestor/features/auth/data/property_repository.dart';
import 'package:campo_gestor/features/lotes/data/lote_model.dart';
import 'package:campo_gestor/features/lotes/data/lote_repository.dart';
import 'package:campo_gestor/features/reproducao/data/atf_model.dart';
import 'package:campo_gestor/features/reproducao/data/atf_repository.dart';
import 'package:campo_gestor/features/reproducao/data/dg_record_model.dart';
import 'package:campo_gestor/features/reproducao/data/dg_summary.dart';
import 'package:campo_gestor/features/sanitario/data/sanitary_application_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _animal = Animal(
  id: 'animal-147',
  propertyId: 'prop-1',
  lotId: 'lot-a',
  category: 'vaca',
  number: 147,
  breed: 'Nelore',
  bodyCondition: 3,
  observation: 'Manso, fácil manejo.',
  createdAt: DateTime(2025, 1, 1),
);

final _archivedAnimal = _animal.copyWith(
  id: 'animal-148',
  number: 148,
  deletedAt: DateTime(2025, 6, 1),
  baixaReason: 'sale',
);

const _prop = SelectedProperty(id: 'prop-1', name: 'Fazenda Alpha');
const _vetMembership =
    PropertyMembership(property: _prop, role: 'veterinarian');
const _readerMembership = PropertyMembership(property: _prop, role: 'reader');

final _lotWithPaddock = LotWithPaddockName(
  lot: Lot(
    id: 'lot-a',
    propertyId: 'prop-1',
    paddockId: 'pad-1',
    name: 'Lote A',
    createdAt: DateTime(2025, 1, 1),
  ),
  paddockName: 'Piquete Norte',
);

final _atfPrimavera = ReproductiveHistoryEntry(
  atfBatchId: 'atf-1',
  atfName: 'ATF Primavera',
  inseminationDate: DateTime(2026, 9, 22),
  atfActive: true,
  lastDgResult: DgResult.pregnant,
  lastDgDate: DateTime(2026, 10, 20),
  dgRecords: const <DgRecord>[],
  implantationDate: DateTime(2026, 9, 15),
  bullName: 'Trovão',
);

// ---------------------------------------------------------------------------
// Widget builder — mirrors animal_detail_screen_test.dart's harness plus the
// two providers only the desktop branch observes.
// ---------------------------------------------------------------------------

Widget _buildScreen({
  required Animal animal,
  required String role,
  LotWithPaddockName? lotWithPaddock,
  List<ReproductiveHistoryEntry>? history,
}) {
  final membership =
      role == 'veterinarian' ? _vetMembership : _readerMembership;
  return ProviderScope(
    overrides: [
      animalByIdProvider.overrideWith((ref, id) async => animal),
      memberPropertiesProvider.overrideWith((ref) async => [membership]),
      reproductiveHistoryByAnimalProvider.overrideWith(
        (ref, id) async => history ?? const <ReproductiveHistoryEntry>[],
      ),
      sanitaryHistoryByAnimalProvider.overrideWith(
        (ref, id) async => const [],
      ),
      loteWithPaddockByIdProvider.overrideWith(
        (ref, id) async => lotWithPaddock,
      ),
      animalReproStatusByPropertyProvider.overrideWith(
        (ref) async => {animal.id: AnimalReproStatus.prenhe},
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      home: AnimalDetailScreen(animalId: animal.id),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required Animal animal,
  required String role,
  LotWithPaddockName? lotWithPaddock,
  List<ReproductiveHistoryEntry>? history,
}) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(_buildScreen(
    animal: animal,
    role: role,
    lotWithPaddock: lotWithPaddock,
    history: history,
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR', null);
  });

  group('AnimalDetailScreen desktop (>=1024px, quick task 260813-q69)', () {
    testWidgets(
        '1440x900: two-column body — context left (340px), timeline right, Reprodução card populated',
        (tester) async {
      await _pump(
        tester,
        size: const Size(1440, 900),
        animal: _animal,
        role: 'veterinarian',
        lotWithPaddock: _lotWithPaddock,
        history: [_atfPrimavera],
      );

      expect(find.byKey(const Key('ficha-desktop')), findsOneWidget);
      expect(find.text('ESTADO CORPORAL'), findsOneWidget);
      expect(find.widgetWithText(SectionCard, 'Reprodução'), findsOneWidget);
      expect(find.text('Cadastrado no rebanho'), findsOneWidget);

      // Geometria: contexto à esquerda da timeline.
      final contextX = tester.getTopLeft(find.text('ESTADO CORPORAL')).dx;
      final timelineX =
          tester.getTopLeft(find.text('Cadastrado no rebanho')).dx;
      expect(contextX, lessThan(timelineX));

      // Coluna de contexto mede 340 de largura.
      final contextColumn = find.ancestor(
        of: find.text('ESTADO CORPORAL'),
        matching:
            find.byWidgetPredicate((w) => w is SizedBox && w.width == 340),
      );
      expect(contextColumn, findsOneWidget);

      // Card de reprodução reusa o mesmo provider da timeline — conteúdo do
      // entry ativo aparece sem request extra. "ATF ATF Primavera · ciclo
      // ativo" e "última DG dd/MM/yyyy" só existem no card (a timeline usa
      // outro formato de detalhe), então dão asserts exatos e não ambíguos.
      expect(find.textContaining('ATF Primavera'), findsWidgets);
      expect(find.text('ATF ATF Primavera · ciclo ativo'), findsOneWidget);
      expect(find.textContaining('touro: Trovão'), findsWidgets);
      expect(find.textContaining('última DG'), findsOneWidget);
    });

    testWidgets(
        '1440x900: horizontal header — #147, badge repro, UA, Editar à direita',
        (tester) async {
      await _pump(
        tester,
        size: const Size(1440, 900),
        animal: _animal,
        role: 'veterinarian',
        lotWithPaddock: _lotWithPaddock,
      );

      expect(find.text('#147'), findsOneWidget);
      expect(find.text('Prenhe'), findsWidgets);
      expect(find.text('1,0'), findsOneWidget);
      final editButton = find.widgetWithText(FilledButton, 'Editar');
      expect(editButton, findsOneWidget);

      // Header horizontal: "Editar" fica à direita de "#147" (dx maior) com
      // sobreposição vertical entre os dois retângulos — distingue do
      // header empilhado do mobile.
      final numberTop = tester.getTopLeft(find.text('#147'));
      final numberBottom = tester.getBottomLeft(find.text('#147')).dy;
      final editTop = tester.getTopLeft(editButton);
      final editBottom = tester.getBottomLeft(editButton).dy;

      expect(editTop.dx, greaterThan(numberTop.dx));
      expect(editTop.dy, lessThan(numberBottom));
      expect(editBottom, greaterThan(numberTop.dy));
    });

    testWidgets(
        '1440x900: veterinarian + ativo — Editar/Mover/baixa presentes',
        (tester) async {
      await _pump(
        tester,
        size: const Size(1440, 900),
        animal: _animal,
        role: 'veterinarian',
        lotWithPaddock: _lotWithPaddock,
      );
      expect(find.widgetWithText(FilledButton, 'Editar'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Mover'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    });

    testWidgets('1440x900: reader — nenhuma ação presente', (tester) async {
      await _pump(
        tester,
        size: const Size(1440, 900),
        animal: _animal,
        role: 'reader',
        lotWithPaddock: _lotWithPaddock,
      );
      expect(find.widgetWithText(FilledButton, 'Editar'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'Mover'), findsNothing);
      expect(find.byIcon(Icons.arrow_downward), findsNothing);
    });

    testWidgets(
        '1440x900: veterinarian + arquivado — só Editar, banner de baixa visível',
        (tester) async {
      await _pump(
        tester,
        size: const Size(1440, 900),
        animal: _archivedAnimal,
        role: 'veterinarian',
        lotWithPaddock: _lotWithPaddock,
      );
      expect(find.widgetWithText(FilledButton, 'Editar'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Mover'), findsNothing);
      expect(find.byIcon(Icons.arrow_downward), findsNothing);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('800x600: layout mobile intacto, sem árvore desktop',
        (tester) async {
      await _pump(
        tester,
        size: const Size(800, 600),
        animal: _animal,
        role: 'veterinarian',
        lotWithPaddock: _lotWithPaddock,
      );

      expect(find.byKey(const Key('ficha-desktop')), findsNothing);
      expect(find.byType(GlassTile), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '1024x800 e 1440x900: sem overflow no corte exato com nomes longos',
        (tester) async {
      final longLot = LotWithPaddockName(
        lot: Lot(
          id: 'lot-a',
          propertyId: 'prop-1',
          paddockId: 'pad-1',
          name: 'Lote Fundo de Vale Extremamente Comprido do Setor Norte',
          createdAt: DateTime(2025, 1, 1),
        ),
        paddockName: 'Piquete Extremamente Comprido do Fundo do Setor Sul',
      );
      final animal = _animal.copyWith(
        observation: 'Observação bem longa para testar quebra de linha na '
            'coluna de contexto de 340px sem estourar o layout do card.',
      );

      await _pump(
        tester,
        size: const Size(1024, 800),
        animal: animal,
        role: 'veterinarian',
        lotWithPaddock: longLot,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('#147'), findsOneWidget);

      await _pump(
        tester,
        size: const Size(1440, 900),
        animal: animal,
        role: 'veterinarian',
        lotWithPaddock: longLot,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('#147'), findsOneWidget);
    });
  });
}
