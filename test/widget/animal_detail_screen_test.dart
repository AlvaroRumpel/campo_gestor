// MOV-01, SC-3 — AnimalDetailScreen: "Mover animal" button gate.
// Wave 0 stubs. AnimalInfoCard.onMover parameter lands in Plan 04-02.
// Asserts: button absent when canEdit=false; present when isActive && canEdit.
import 'dart:async';

import 'package:campo_gestor/features/animais/data/animal_model.dart';
import 'package:campo_gestor/features/animais/data/animal_repository.dart';
import 'package:campo_gestor/features/animais/presentation/animal_detail_screen.dart';
import 'package:campo_gestor/features/auth/data/property_repository.dart';
import 'package:campo_gestor/core/providers/current_property_provider.dart';
import 'package:campo_gestor/features/lotes/data/lote_model.dart';
import 'package:campo_gestor/features/lotes/data/lote_repository.dart';
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
  Future<LotWithPaddockName?> Function(String lotId)? lotWithPaddockBuilder,
}) {
  final membership = role == 'veterinarian' ? _vetMembership : _readerMembership;
  return ProviderScope(
    overrides: [
      animalByIdProvider.overrideWith((ref, id) async => animal),
      memberPropertiesProvider.overrideWith((ref) async => [membership]),
      if (historyBuilder != null)
        reproductiveHistoryByAnimalProvider
            .overrideWith((ref, id) => historyBuilder(id)),
      if (lotWithPaddockBuilder != null)
        loteWithPaddockByIdProvider
            .overrideWith((ref, id) => lotWithPaddockBuilder(id)),
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

/// AnimalInfoCard mounted directly, inside the same ListView(padding: 16)
/// shell the real ficha uses — not the whole AnimalDetailScreen.
///
/// Used only by the width-breakpoint tests (D-21, SC-5). Isolating
/// AnimalInfoCard keeps those tests scoped to what this plan's Task 2
/// actually changed (_KvRow + the lote/piquete rows) and away from
/// `sanitary_history_section.dart`'s header row, which has its own
/// pre-existing RenderFlex overflow at narrow widths (D-37 locks that file
/// — this plan cannot touch it; see SUMMARY "Known Issues").
Widget _buildInfoCard({
  required Animal animal,
  bool canEdit = true,
  Future<LotWithPaddockName?> Function(String lotId)? lotWithPaddockBuilder,
}) {
  return ProviderScope(
    overrides: [
      if (lotWithPaddockBuilder != null)
        loteWithPaddockByIdProvider
            .overrideWith((ref, id) => lotWithPaddockBuilder(id)),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AnimalInfoCard(
              animal: animal,
              canEdit: canEdit,
              onEdit: () {},
              onBaixa: () {},
              onMover: () {},
            ),
          ],
        ),
      ),
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

  // ---------------------------------------------------------------------
  // 360px width harness (D-23) — first width-constrained widget test in
  // this repo. Set inside individual testWidgets bodies (not the shared
  // builder) so it never leaks into the tests above. Copy these three
  // lines for any future width-constrained test:
  //
  //   addTearDown(tester.view.resetPhysicalSize);
  //   tester.view.physicalSize = const Size(360, 800);
  //   tester.view.devicePixelRatio = 1.0;
  // ---------------------------------------------------------------------

  group('AnimalDetailScreen — Banner de baixa (D-12..D-15, SC-4)', () {
    testWidgets('active animal: no banner, no Status label (D-15 guard)',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(animal: _activeAnimal, role: 'veterinarian'),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.info_outline), findsNothing);
      expect(find.text('Status'), findsNothing);
    });

    testWidgets('sold animal with date and observation: banner shows reason, date and observation',
        (tester) async {
      final animal = _archivedAnimal.copyWith(
        baixaDate: DateTime(2025, 6, 1),
        observation: 'Vendido em leilão da região.',
      );
      await tester.pumpWidget(
        _buildScreen(animal: animal, role: 'veterinarian'),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      expect(
        find.textContaining('Vendido em 01/06/2025 — Vendido em leilão da região.'),
        findsOneWidget,
      );
    });

    testWidgets('sold animal without observation: banner shows reason and date, no dangling dash',
        (tester) async {
      final animal = _archivedAnimal.copyWith(baixaDate: DateTime(2025, 6, 1));
      await tester.pumpWidget(
        _buildScreen(animal: animal, role: 'veterinarian'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Vendido em 01/06/2025'), findsOneWidget);
      // No dangling em-dash after the date (AppBar title already contains an
      // unrelated "—", so scope the guard to the banner's own text pattern).
      expect(find.textContaining('01/06/2025 —'), findsNothing);
    });

    testWidgets('unknown/null baixa reason falls back to "Arquivado"',
        (tester) async {
      final animal = _archivedAnimal.copyWith(baixaReason: 'unknown-reason');
      await tester.pumpWidget(
        _buildScreen(animal: animal, role: 'veterinarian'),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Arquivado'), findsOneWidget);
    });

    testWidgets('banner renders above AnimalInfoCard (D-12 order)',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(animal: _archivedAnimal, role: 'veterinarian'),
      );
      await tester.pumpAndSettle();

      final bannerY = tester.getTopLeft(find.byIcon(Icons.info_outline)).dy;
      final cardY = tester.getTopLeft(find.text('Número')).dy;
      expect(bannerY, lessThan(cardY));
    });

    testWidgets('archived animal: reproductive and sanitary blocks stay reachable (D-16)',
        (tester) async {
      // Neither history provider is overridden with resolved data here
      // (mirrors the existing "hides Mover animal button when animal is
      // archived" test above) — this test only asserts both section
      // headers render for an archived animal, not on their row content.
      //
      // Tall physicalSize: the banner adds height above AnimalInfoCard, and
      // ListView's default cacheExtent only builds Elements within/near the
      // viewport — at the default 600px-tall test window the sanitary card
      // falls outside that window and is never built without a scroll. A
      // tall viewport sidesteps needing to scroll to prove it's reachable.
      addTearDown(tester.view.resetPhysicalSize);
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        _buildScreen(animal: _archivedAnimal, role: 'veterinarian'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Histórico Reprodutivo'), findsOneWidget);
      expect(find.text('Histórico Sanitário'), findsOneWidget);
    });
  });

  group('AnimalDetailScreen — Layout adaptativo a 360px (D-21, SC-5)', () {
    // These tests mount AnimalInfoCard directly via _buildInfoCard (not the
    // whole AnimalDetailScreen) — see that builder's dartdoc for why:
    // sanitary_history_section.dart (D-37-locked) has its own pre-existing
    // narrow-width overflow unrelated to this plan's changes.
    testWidgets('360px: no layout overflow is reported', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(_buildInfoCard(animal: _activeAnimal));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('360px: label stacks above value in the same row',
        (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(_buildInfoCard(animal: _activeAnimal));
      await tester.pumpAndSettle();

      final labelY = tester.getTopLeft(find.text('Número')).dy;
      final valueY = tester.getTopLeft(find.text('#9')).dy;
      expect(valueY, greaterThan(labelY));
    });

    testWidgets('800px: label stays beside value, unchanged layout',
        (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      tester.view.physicalSize = const Size(800, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(_buildInfoCard(animal: _activeAnimal));
      await tester.pumpAndSettle();

      final labelTopLeft = tester.getTopLeft(find.text('Número'));
      final valueTopLeft = tester.getTopLeft(find.text('#9'));
      expect(valueTopLeft.dy, equals(labelTopLeft.dy));
      expect(valueTopLeft.dx, greaterThan(labelTopLeft.dx));
    });

    testWidgets('360px: a long lot/paddock name does not overflow',
        (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;

      final longLot = Lot(
        id: 'lot-A',
        propertyId: 'prop-1',
        paddockId: 'paddock-1',
        name: 'Lote Fundo de Vale Extremamente Comprido do Setor Norte',
        createdAt: DateTime(2025, 1, 1),
      );
      await tester.pumpWidget(
        _buildInfoCard(
          animal: _activeAnimal,
          lotWithPaddockBuilder: (id) async => LotWithPaddockName(
            lot: longLot,
            paddockName: 'Piquete Extremamente Comprido do Fundo do Setor Sul',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('360px: a long baixa observation wraps without overflowing',
        (tester) async {
      // The banner (_BaixaBanner, private to animal_detail_screen.dart) is
      // only reachable by pumping the whole AnimalDetailScreen, so this one
      // test (unlike the others in this group) cannot use _buildInfoCard.
      // It therefore also cannot assert tester.takeException() is null:
      // sanitary_history_section.dart's header row has its own pre-existing
      // RenderFlex overflow at this width, unrelated to the banner and
      // outside this plan's D-37 boundary — see SUMMARY "Known Issues".
      // What this test proves instead: the banner's own Text (no maxLines,
      // no overflow set) renders the full observation with no truncation —
      // the observation shows up verbatim both in the banner and in the
      // card's own "Observação" row (unchanged pre-existing behavior).
      addTearDown(tester.view.resetPhysicalSize);
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;

      final longObservation =
          'Animal vendido no leilão regional após tratamento prolongado, '
          'com acompanhamento veterinário contínuo e nota detalhada sobre '
          'o histórico completo de manejo antes da saída do rebanho.';
      final animal = _archivedAnimal.copyWith(
        baixaDate: DateTime(2025, 6, 1),
        observation: longObservation,
      );
      await tester.pumpWidget(
        _buildScreen(animal: animal, role: 'veterinarian'),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining(longObservation), findsNWidgets(2));
    });
  });

  group('AnimalDetailScreen — Degradação parcial do card (UI-SPEC partial/animal-info-card)', () {
    testWidgets(
        'lote+piquete read failing does not hide the animal\'s own fields',
        (tester) async {
      // breed/bodyCondition set so the two "—" fallbacks asserted below can
      // only come from the failed lote/piquete rows, not from these fields.
      final animal = _activeAnimal.copyWith(breed: 'Nelore', bodyCondition: 3);
      await tester.pumpWidget(
        _buildScreen(
          animal: animal,
          role: 'veterinarian',
          lotWithPaddockBuilder: (id) async => throw Exception('boom'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Número'), findsOneWidget);
      expect(find.text('#9'), findsOneWidget);
      expect(find.text('Lote atual'), findsOneWidget);
      expect(find.text('Piquete atual'), findsOneWidget);
      expect(find.text('—'), findsNWidgets(2));
    });
  });
}
