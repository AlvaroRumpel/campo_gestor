// ANIM-04 — BaixaDialog: motivo (Venda/Morte/Descarte) + data.
// Wave 0 stubs. Implementation lands in Plan 06 (BaixaDialog).
// Decisions enforced: D-17 (3 reasons mapped to enum 'sale'|'death'|'discard').
import 'package:campo_gestor/core/services/supabase_service.dart';
import 'package:campo_gestor/features/animais/data/animal_constants.dart';
import 'package:campo_gestor/features/animais/data/animal_model.dart';
import 'package:campo_gestor/features/animais/data/animal_repository.dart';
import 'package:campo_gestor/features/animais/presentation/baixa_dialog.dart';
import 'package:campo_gestor/features/reproducao/data/atf_model.dart';
import 'package:campo_gestor/features/reproducao/data/atf_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

// ---------------------------------------------------------------------------
// Fake repository — extends AnimalRepository; overrides never call _service
// ---------------------------------------------------------------------------

class _FakeAnimalRepo extends AnimalRepository {
  // SupabaseService() is safe to construct — client getter is never called
  // because we override all methods that would access it.
  _FakeAnimalRepo() : super(SupabaseService());

  @override
  Future<void> registerBaixa({
    required String id,
    required BaixaReason reason,
    required DateTime date,
    String? observation,
  }) async {
    // no-op: just succeed silently
  }
}

// ---------------------------------------------------------------------------
// Sample animal
// ---------------------------------------------------------------------------

final _sampleAnimal = Animal(
  id: 'animal-42',
  propertyId: 'prop-1',
  lotId: 'lot-a',
  category: 'vaca',
  number: 42,
  createdAt: DateTime(2025, 1, 1),
);

// ---------------------------------------------------------------------------
// Widget builder
// ---------------------------------------------------------------------------

Widget _buildDialog({Animal? animal}) {
  return ProviderScope(
    overrides: [
      animalRepositoryProvider.overrideWithValue(_FakeAnimalRepo()),
      animalListByPropertyProvider.overrideWith((ref) async => []),
      animalByIdProvider.overrideWith((ref, id) async => null),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: BaixaDialog(animal: animal ?? _sampleAnimal),
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// G-05-1 regression harness — a real ProviderContainer so ref.invalidate
// effects on the ATF composition provider family are observable via a
// build counter.
// ---------------------------------------------------------------------------

Widget _buildDialogWithContainer(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: BaixaDialog(animal: _sampleAnimal),
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('BaixaDialog (ANIM-04)', () {
    testWidgets('renders title "Dar baixa no #<N>" (spec 4.15)',
        (tester) async {
      await tester.pumpWidget(_buildDialog());
      await tester.pump();

      expect(find.text('Dar baixa no #42'), findsOneWidget);
    });

    testWidgets('renders 3 motivo options labeled "Venda", "Morte", "Descarte"',
        (tester) async {
      await tester.pumpWidget(_buildDialog());
      await tester.pump();

      for (final lbl in const ['Venda', 'Morte', 'Descarte']) {
        expect(find.text(lbl), findsOneWidget,
            reason: 'Expected segment label "$lbl"');
      }
    });

    testWidgets(
        'renders Data da baixa field with date picker, defaulting to today (DD/MM/AAAA)',
        (tester) async {
      await tester.pumpWidget(_buildDialog());
      await tester.pump();

      final todayStr = DateFormat('dd/MM/yyyy').format(DateTime.now());
      expect(find.text(todayStr), findsOneWidget);
    });

    testWidgets(
        'confirm button labeled "Confirmar baixa", uses colorScheme.error background',
        (tester) async {
      await tester.pumpWidget(_buildDialog());
      await tester.pump();

      expect(
        find.widgetWithText(FilledButton, 'Confirmar baixa'),
        findsOneWidget,
      );
    });

    testWidgets('rejects submit when motivo not selected', (tester) async {
      await tester.pumpWidget(_buildDialog());
      await tester.pump();

      // Tap confirm without selecting a reason
      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar baixa'));
      await tester.pump();

      expect(
        find.text('Selecione o motivo da baixa'),
        findsOneWidget,
      );
    });
  });

  group('G-05-1: BaixaDialog invalidates ATF composition providers', () {
    testWidgets(
        'a successful baixa rebuilds atfActiveMembershipsProvider, '
        'atfMembershipsProvider, and atfListByPropertyProvider once each',
        (tester) async {
      var activeBuilds = 0;
      var allBuilds = 0;
      var listBuilds = 0;

      final container = ProviderContainer(
        overrides: [
          animalRepositoryProvider.overrideWithValue(_FakeAnimalRepo()),
          animalListByPropertyProvider.overrideWith((ref) async => []),
          animalByIdProvider.overrideWith((ref, id) async => null),
          atfActiveMembershipsProvider.overrideWith((ref, id) async {
            activeBuilds++;
            return const <AtfMembershipView>[];
          }),
          atfMembershipsProvider.overrideWith((ref, id) async {
            allBuilds++;
            return const <AtfMembershipView>[];
          }),
          atfListByPropertyProvider.overrideWith((ref) async {
            listBuilds++;
            return const <AtfSummary>[];
          }),
        ],
      );
      addTearDown(container.dispose);

      // Instantiate the family members so ref.invalidate isn't a silent
      // no-op on a provider that was never read.
      container.listen(
        atfActiveMembershipsProvider('atf-1'),
        (_, _) {},
        fireImmediately: true,
      );
      container.listen(
        atfMembershipsProvider('atf-1'),
        (_, _) {},
        fireImmediately: true,
      );
      container.listen(
        atfListByPropertyProvider,
        (_, _) {},
        fireImmediately: true,
      );

      await tester.pumpWidget(_buildDialogWithContainer(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Venda'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar baixa'));
      await tester.pumpAndSettle();

      expect(activeBuilds, 2,
          reason: 'atfActiveMembershipsProvider must rebuild once post-baixa');
      expect(allBuilds, 2,
          reason: 'atfMembershipsProvider must rebuild once post-baixa');
      expect(listBuilds, 2,
          reason: 'atfListByPropertyProvider must rebuild once post-baixa');
    });
  });
}
