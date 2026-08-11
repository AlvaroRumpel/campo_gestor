// MOV-01, SC-3 — AnimalDetailScreen: "Mover animal" button gate.
// Wave 0 stubs. AnimalInfoCard.onMover parameter lands in Plan 04-02.
// Asserts: button absent when canEdit=false; present when isActive && canEdit.
import 'dart:async';

import 'package:campo_gestor/features/animais/data/animal_model.dart';
import 'package:campo_gestor/features/animais/data/animal_repository.dart';
import 'package:campo_gestor/features/animais/presentation/animal_detail_screen.dart';
import 'package:campo_gestor/features/auth/data/property_repository.dart';
import 'package:campo_gestor/core/providers/current_property_provider.dart';
import 'package:campo_gestor/features/reproducao/data/atf_model.dart';
import 'package:campo_gestor/features/reproducao/data/atf_repository.dart';
import 'package:campo_gestor/features/reproducao/data/dg_record_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

// ---------------------------------------------------------------------------
// Sample data
// ---------------------------------------------------------------------------

final _activeAnimal = Animal(
  id: 'animal-9',
  propertyId: 'prop-1',
  lotId: 'lot-A',
  category: 'vaca',
  number: 9,
  createdAt: DateTime(2025, 1, 1),
);
final _archivedAnimal = Animal(
  id: 'animal-10',
  propertyId: 'prop-1',
  lotId: 'lot-A',
  category: 'vaca',
  number: 10,
  createdAt: DateTime(2025, 1, 1),
  deletedAt: DateTime(2025, 6, 1),
  baixaReason: 'sale',
);
const _prop = SelectedProperty(id: 'prop-1', name: 'Fazenda Alpha');
const _vetMembership = PropertyMembership(property: _prop, role: 'veterinarian');
const _readerMembership = PropertyMembership(property: _prop, role: 'reader');

// ---------------------------------------------------------------------------
// Sample reproductive history entries (REPR-05, D-14)
// ---------------------------------------------------------------------------

final _atfPrimavera = ReproductiveHistoryEntry(
  atfBatchId: 'atf-1',
  atfName: 'ATF Primavera',
  inseminationDate: DateTime(2026, 9, 22),
  atfActive: true,
  lastDgResult: DgResult.pregnant,
  lastDgDate: DateTime(2026, 10, 20),
  dgRecords: const [],
  implantationDate: DateTime(2026, 9, 15),
);
final _atfOutono = ReproductiveHistoryEntry(
  atfBatchId: 'atf-2',
  atfName: 'ATF Outono',
  inseminationDate: DateTime(2026, 4, 10),
  atfActive: false,
  lastDgResult: DgResult.notPregnant,
  lastDgDate: DateTime(2026, 5, 12),
  dgRecords: const [],
  implantationDate: DateTime(2026, 4, 3),
);
final _atfInverno = ReproductiveHistoryEntry(
  atfBatchId: 'atf-3',
  atfName: 'ATF Inverno',
  inseminationDate: DateTime(2026, 7, 1),
  atfActive: true,
  lastDgResult: null,
  lastDgDate: null,
  dgRecords: const [],
  implantationDate: DateTime(2026, 6, 24),
);

// ---------------------------------------------------------------------------
// Widget builder
// ---------------------------------------------------------------------------
//
// NOTE: currentPropertyProvider is NOT overridden directly — it is an
// AsyncNotifierProvider whose build() resolves the active property from
// memberPropertiesProvider when there's a single membership. Overriding
// memberPropertiesProvider alone is sufficient and matches production logic.

Widget _buildScreen({
  required Animal animal,
  required String role,
  Future<List<ReproductiveHistoryEntry>> Function(String animalId)?
      historyBuilder,
}) {
  final membership = role == 'veterinarian' ? _vetMembership : _readerMembership;
  return ProviderScope(
    overrides: [
      animalByIdProvider.overrideWith((ref, id) async => animal),
      memberPropertiesProvider.overrideWith((ref) async => [membership]),
      if (historyBuilder != null)
        reproductiveHistoryByAnimalProvider
            .overrideWith((ref, id) => historyBuilder(id)),
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

// ---------------------------------------------------------------------------
// Router harness (A-NAV-TEST) — asserts the reproductive history row tap
// navigates to the /atf/:atfId path, mirroring lote_detail_screen_test.dart's
// GoRouter harness for the back-button navigation assertion.
// ---------------------------------------------------------------------------

Widget _buildRoutedScreen({
  required Animal animal,
  required Future<List<ReproductiveHistoryEntry>> Function(String animalId)
      historyBuilder,
}) {
  final router = GoRouter(
    initialLocation: '/animais/${animal.id}',
    routes: [
      GoRoute(
        path: '/animais/:id',
        builder: (context, state) =>
            AnimalDetailScreen(animalId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/atf/:atfId',
        builder: (context, state) => Scaffold(
          body: Text('atf-detail-${state.pathParameters['atfId']}'),
        ),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      animalByIdProvider.overrideWith((ref, id) async => animal),
      memberPropertiesProvider.overrideWith((ref) async => [_vetMembership]),
      reproductiveHistoryByAnimalProvider
          .overrideWith((ref, id) => historyBuilder(id)),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // AnimalInfoCard formats dates with DateFormat(..., 'pt_BR'); locale data
  // must be initialized once before pumping any widget that reaches it.
  setUpAll(() async {
    await initializeDateFormatting('pt_BR', null);
  });

  group('AnimalDetailScreen — Mover animal button (MOV-01, SC-3)', () {
    testWidgets('shows Mover animal button when active && canEdit',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(animal: _activeAnimal, role: 'veterinarian'),
      );
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(OutlinedButton, 'Mover animal'),
        findsOneWidget,
      );
    });

    testWidgets('hides Mover animal button when role is reader',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(animal: _activeAnimal, role: 'reader'),
      );
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(OutlinedButton, 'Mover animal'),
        findsNothing,
      );
    });

    testWidgets('hides Mover animal button when animal is archived',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(animal: _archivedAnimal, role: 'veterinarian'),
      );
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(OutlinedButton, 'Mover animal'),
        findsNothing,
      );
    });
  });

  group('AnimalDetailScreen — Histórico Reprodutivo (REPR-05, D-14, 05-UI-SPEC E8)', () {
    testWidgets('empty: renders "Nenhum ATF registrado para este animal."',
        (tester) async {
      await tester.pumpWidget(_buildScreen(
        animal: _activeAnimal,
        role: 'veterinarian',
        historyBuilder: (id) async => const [],
      ));
      await tester.pumpAndSettle();

      expect(
        find.text('Nenhum ATF registrado para este animal.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'loading: renders a section-local spinner while the rest of the ficha still renders',
        (tester) async {
      await tester.pumpWidget(_buildScreen(
        animal: _activeAnimal,
        role: 'veterinarian',
        historyBuilder: (id) => Completer<List<ReproductiveHistoryEntry>>().future,
      ));
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Número'), findsOneWidget);
      expect(find.text('Histórico Sanitário'), findsOneWidget);
    });

    testWidgets(
        'error: renders "Erro ao carregar histórico reprodutivo." and the info card stays present',
        (tester) async {
      await tester.pumpWidget(_buildScreen(
        animal: _activeAnimal,
        role: 'veterinarian',
        historyBuilder: (id) async => throw Exception('boom'),
      ));
      await tester.pumpAndSettle();

      expect(
        find.text('Erro ao carregar histórico reprodutivo.'),
        findsOneWidget,
      );
      expect(find.text('Número'), findsOneWidget);
    });

    testWidgets(
        'populated: renders one row per entry, in the order supplied (insemination date descending)',
        (tester) async {
      await tester.pumpWidget(_buildScreen(
        animal: _activeAnimal,
        role: 'veterinarian',
        historyBuilder: (id) async => [_atfPrimavera, _atfInverno, _atfOutono],
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('ATF Primavera'), findsOneWidget);
      expect(find.textContaining('ATF Inverno'), findsOneWidget);
      expect(find.textContaining('ATF Outono'), findsOneWidget);

      final primaveraY = tester.getTopLeft(find.textContaining('ATF Primavera')).dy;
      final invernoY = tester.getTopLeft(find.textContaining('ATF Inverno')).dy;
      final outonoY = tester.getTopLeft(find.textContaining('ATF Outono')).dy;
      expect(primaveraY, lessThan(invernoY));
      expect(invernoY, lessThan(outonoY));
    });

    testWidgets(
        'partial: an entry with no DG yet renders "aguardando DG" and no result Chip',
        (tester) async {
      await tester.pumpWidget(_buildScreen(
        animal: _activeAnimal,
        role: 'veterinarian',
        historyBuilder: (id) async => [_atfInverno],
      ));
      await tester.pumpAndSettle();

      expect(find.text('aguardando DG'), findsOneWidget);
    });

    testWidgets(
        'read-only: the section renders no ChoiceChip and no button (D-13)',
        (tester) async {
      await tester.pumpWidget(_buildScreen(
        animal: _activeAnimal,
        role: 'veterinarian',
        historyBuilder: (id) async => [_atfPrimavera, _atfOutono, _atfInverno],
      ));
      await tester.pumpAndSettle();

      final sectionCard = find.ancestor(
        of: find.text('Histórico Reprodutivo'),
        matching: find.byType(Card),
      );
      expect(sectionCard, findsOneWidget);
      expect(
        find.descendant(
          of: sectionCard,
          matching: find.byWidgetPredicate(
            (w) => w is ChoiceChip || w is ButtonStyleButton || w is IconButton,
          ),
        ),
        findsNothing,
      );
    });

    testWidgets('navigation: tapping a row navigates to /atf/:atfId',
        (tester) async {
      await tester.pumpWidget(_buildRoutedScreen(
        animal: _activeAnimal,
        historyBuilder: (id) async => [_atfPrimavera],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('ATF Primavera'));
      await tester.pumpAndSettle();

      expect(find.text('atf-detail-atf-1'), findsOneWidget);
    });
  });

  group('AnimalDetailScreen — Observação display', () {
    testWidgets('shows Observação label and text when observation is set',
        (tester) async {
      final animal = _activeAnimal.copyWith(observation: 'Manso, fácil manejo.');
      await tester.pumpWidget(_buildScreen(animal: animal, role: 'veterinarian'));
      await tester.pumpAndSettle();

      expect(find.text('Observação'), findsOneWidget);
      expect(find.text('Manso, fácil manejo.'), findsOneWidget);
    });

    testWidgets('hides Observação label when observation is null',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(animal: _activeAnimal, role: 'veterinarian'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Observação'), findsNothing);
    });

    testWidgets('hides Observação label when observation is blank string',
        (tester) async {
      final animal = _activeAnimal.copyWith(observation: '');
      await tester.pumpWidget(_buildScreen(animal: animal, role: 'veterinarian'));
      await tester.pumpAndSettle();

      expect(find.text('Observação'), findsNothing);
    });

    testWidgets('renders full multi-line observation text, not just first line',
        (tester) async {
      final animal = _activeAnimal.copyWith(
        observation: 'Tratamento inicial em 10/01.\nBaixa em 20/03: vendido.',
      );
      await tester.pumpWidget(_buildScreen(animal: animal, role: 'veterinarian'));
      await tester.pumpAndSettle();

      expect(find.text('Observação'), findsOneWidget);
      expect(find.textContaining('Baixa em 20/03: vendido.'), findsOneWidget);
    });
  });
}
