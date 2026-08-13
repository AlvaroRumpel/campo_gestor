// MOV-01, SC-3, REPR-05, SANI-05 — AnimalDetailScreen (ficha timeline).
// Redesign spec 4.4: green header + action bar (vet only) + state card +
// merged reproductive/sanitary timeline (spec 3.11).
// Asserts: action gating by role/archived state; timeline merge, ordering,
// estorno strikethrough, navigation; baixa banner content.
import 'dart:async';

import 'package:campo_gestor/core/providers/current_property_provider.dart';
import 'package:campo_gestor/features/animais/data/animal_model.dart';
import 'package:campo_gestor/features/animais/data/animal_repository.dart';
import 'package:campo_gestor/features/animais/presentation/animal_detail_screen.dart';
import 'package:campo_gestor/features/auth/data/property_repository.dart';
import 'package:campo_gestor/features/lotes/data/lote_model.dart';
import 'package:campo_gestor/features/lotes/data/lote_repository.dart';
import 'package:campo_gestor/features/reproducao/data/atf_model.dart';
import 'package:campo_gestor/features/reproducao/data/atf_repository.dart';
import 'package:campo_gestor/features/reproducao/data/dg_record_model.dart';
import 'package:campo_gestor/features/sanitario/data/sanitary_application_model.dart';
import 'package:campo_gestor/features/sanitario/data/sanitary_application_repository.dart';
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
// Sample sanitary applications (SANI-05, D-25)
// ---------------------------------------------------------------------------

SanitaryApplication _app({
  required String id,
  required String doseName,
  required DateTime appliedAt,
  String? reversesApplicationId,
  String? notes,
}) =>
    SanitaryApplication(
      id: id,
      propertyId: 'prop-1',
      lotId: 'lot-A',
      lotName: 'Lote A',
      paddockId: 'pad-1',
      paddockName: 'Piquete 3',
      doseId: 'dose-1',
      doseName: doseName,
      dosagePerKg: 1,
      dosagePerUa: 400,
      appliedAt: appliedAt,
      appliedBy: 'user-1',
      animalCount: 12,
      totalUa: 10,
      totalVolume: 4000,
      skippedCount: 0,
      reversesApplicationId: reversesApplicationId,
      notes: notes,
      createdAt: appliedAt,
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
  Future<List<SanitaryApplication>> Function(String animalId)?
      sanitaryBuilder,
  Future<LotWithPaddockName?> Function(String lotId)? lotWithPaddockBuilder,
}) {
  final membership = role == 'veterinarian' ? _vetMembership : _readerMembership;
  return ProviderScope(
    overrides: [
      animalByIdProvider.overrideWith((ref, id) async => animal),
      memberPropertiesProvider.overrideWith((ref) async => [membership]),
      reproductiveHistoryByAnimalProvider.overrideWith(
        (ref, id) => historyBuilder == null
            ? Future.value(const <ReproductiveHistoryEntry>[])
            : historyBuilder(id),
      ),
      sanitaryHistoryByAnimalProvider.overrideWith(
        (ref, id) => sanitaryBuilder == null
            ? Future.value(const <SanitaryApplication>[])
            : sanitaryBuilder(id),
      ),
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

// ---------------------------------------------------------------------------
// Router harness (A-NAV-TEST) — asserts timeline event taps navigate to
// /atf/:atfId and /aplicacoes/:id.
// ---------------------------------------------------------------------------

Widget _buildRoutedScreen({
  required Animal animal,
  Future<List<ReproductiveHistoryEntry>> Function(String animalId)?
      historyBuilder,
  Future<List<SanitaryApplication>> Function(String animalId)?
      sanitaryBuilder,
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
      GoRoute(
        path: '/aplicacoes/:id',
        builder: (context, state) => Scaffold(
          body: Text('aplicacao-detail-${state.pathParameters['id']}'),
        ),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      animalByIdProvider.overrideWith((ref, id) async => animal),
      memberPropertiesProvider.overrideWith((ref) async => [_vetMembership]),
      reproductiveHistoryByAnimalProvider.overrideWith(
        (ref, id) => historyBuilder == null
            ? Future.value(const <ReproductiveHistoryEntry>[])
            : historyBuilder(id),
      ),
      sanitaryHistoryByAnimalProvider.overrideWith(
        (ref, id) => sanitaryBuilder == null
            ? Future.value(const <SanitaryApplication>[])
            : sanitaryBuilder(id),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // Dates are formatted with pt-BR pickers downstream; locale data must be
  // initialized once before pumping any widget that reaches it.
  setUpAll(() async {
    await initializeDateFormatting('pt_BR', null);
  });

  group('AnimalDetailScreen — ações (MOV-01, SC-3, T-3-21/22)', () {
    testWidgets('shows Editar/Mover/dar baixa when active && vet',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(animal: _activeAnimal, role: 'veterinarian'),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Editar'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Mover'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    });

    testWidgets('hides all action buttons when role is reader',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(animal: _activeAnimal, role: 'reader'),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Editar'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'Mover'), findsNothing);
      expect(find.byIcon(Icons.arrow_downward), findsNothing);
    });

    testWidgets('hides Mover and dar baixa when animal is archived',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(animal: _archivedAnimal, role: 'veterinarian'),
      );
      await tester.pumpAndSettle();

      // Editar stays available for the vet; the active-only actions go away.
      expect(find.widgetWithText(FilledButton, 'Editar'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Mover'), findsNothing);
      expect(find.byIcon(Icons.arrow_downward), findsNothing);
    });
  });

  group('AnimalDetailScreen — header verde (spec 4.4)', () {
    testWidgets('renders hero number, category, UA badge and glass tiles',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          animal: _activeAnimal,
          role: 'veterinarian',
          lotWithPaddockBuilder: (id) async => LotWithPaddockName(
            lot: Lot(
              id: 'lot-A',
              propertyId: 'prop-1',
              paddockId: 'pad-1',
              name: 'Lote A',
              createdAt: DateTime(2025, 1, 1),
            ),
            paddockName: 'Piquete Norte',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('#9'), findsOneWidget);
      expect(find.text('Vaca'), findsOneWidget);
      // vaca = 1.0 UA (kUaWeights), comma decimal
      expect(find.text('1,0'), findsOneWidget);
      expect(find.text('UA'), findsOneWidget);
      expect(find.text('LOTE'), findsOneWidget);
      expect(find.text('PIQUETE'), findsOneWidget);
      expect(find.text('Lote A'), findsOneWidget);
      expect(find.text('Piquete Norte'), findsOneWidget);
    });

    testWidgets(
        'lote+piquete read failing does not hide the animal\'s own header',
        (tester) async {
      final animal = _activeAnimal.copyWith(
        breed: 'Nelore',
        bodyCondition: 3,
        observation: 'Manso.',
      );
      await tester.pumpWidget(
        _buildScreen(
          animal: animal,
          role: 'veterinarian',
          lotWithPaddockBuilder: (id) async => throw Exception('boom'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('#9'), findsOneWidget);
      expect(find.text('LOTE'), findsOneWidget);
      expect(find.text('PIQUETE'), findsOneWidget);
      // EC and observação are set, so the only "—" fallbacks come from the
      // two failed glass tiles.
      expect(find.text('—'), findsNWidgets(2));
    });
  });

  group('AnimalDetailScreen — timeline reprodutiva (REPR-05, spec 3.11)', () {
    testWidgets('empty history: timeline still shows the cadastro event',
        (tester) async {
      await tester.pumpWidget(_buildScreen(
        animal: _activeAnimal,
        role: 'veterinarian',
        historyBuilder: (id) async => const [],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Cadastrado no rebanho'), findsOneWidget);
      expect(find.textContaining('DG —'), findsNothing);
    });

    testWidgets(
        'loading: renders a card-local spinner while the header still renders',
        (tester) async {
      await tester.pumpWidget(_buildScreen(
        animal: _activeAnimal,
        role: 'veterinarian',
        historyBuilder: (id) =>
            Completer<List<ReproductiveHistoryEntry>>().future,
      ));
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('#9'), findsOneWidget);
    });

    testWidgets(
        'error: renders "Erro ao carregar histórico reprodutivo." with retry, header stays',
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
      expect(find.text('Tentar novamente'), findsOneWidget);
      expect(find.text('#9'), findsOneWidget);
    });

    testWidgets(
        'populated: one event per entry, newest first, with result chips',
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
      // Timeline chip labels (spec 4.4): Prenhe (solid) / Vazia (danger).
      expect(find.text('Prenhe'), findsOneWidget);
      expect(find.text('Vazia'), findsOneWidget);

      // Ordering: Primavera DG (10/2026) > Inverno insem (07/2026) >
      // Outono DG (05/2026).
      final primaveraY =
          tester.getTopLeft(find.textContaining('ATF Primavera')).dy;
      final invernoY = tester.getTopLeft(find.textContaining('ATF Inverno')).dy;
      final outonoY = tester.getTopLeft(find.textContaining('ATF Outono')).dy;
      expect(primaveraY, lessThan(invernoY));
      expect(invernoY, lessThan(outonoY));

      // Cadastro event renders last.
      final cadastroY =
          tester.getTopLeft(find.text('Cadastrado no rebanho')).dy;
      expect(outonoY, lessThan(cadastroY));
    });

    testWidgets(
        'partial: an entry with no DG yet renders "aguardando DG" and no chip',
        (tester) async {
      await tester.pumpWidget(_buildScreen(
        animal: _activeAnimal,
        role: 'veterinarian',
        historyBuilder: (id) async => [_atfInverno],
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('aguardando DG'), findsOneWidget);
      expect(find.text('Prenhe'), findsNothing);
      expect(find.text('Vazia'), findsNothing);
    });

    testWidgets('navigation: tapping a repro event navigates to /atf/:atfId',
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

  group('AnimalDetailScreen — timeline sanitária (SANI-05, spec 3.11)', () {
    testWidgets('renders dose name and frozen lot detail', (tester) async {
      await tester.pumpWidget(_buildScreen(
        animal: _activeAnimal,
        role: 'veterinarian',
        sanitaryBuilder: (id) async => [
          _app(
            id: 'app-1',
            doseName: 'Ivomec Gold',
            appliedAt: DateTime(2026, 5, 12),
          ),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Ivomec Gold'), findsOneWidget);
      expect(
        find.text('lote da época: Lote A · 400 mL/UA'),
        findsOneWidget,
      );
    });

    testWidgets(
        'estornada: original renders struck-through with block icon and reversal detail; the reversal row itself is not listed',
        (tester) async {
      await tester.pumpWidget(_buildScreen(
        animal: _activeAnimal,
        role: 'veterinarian',
        sanitaryBuilder: (id) async => [
          _app(
            id: 'rev-1',
            doseName: 'Vacina Aftosa',
            appliedAt: DateTime(2026, 4, 4),
            reversesApplicationId: 'app-2',
            notes: 'dose errada',
          ),
          _app(
            id: 'app-2',
            doseName: 'Vacina Aftosa',
            appliedAt: DateTime(2026, 4, 3),
          ),
        ],
      ));
      await tester.pumpAndSettle();

      // Only the original row renders (the reversal is its subtitle).
      expect(find.text('Vacina Aftosa'), findsOneWidget);
      expect(find.text('estornada em 04/04 — dose errada'), findsOneWidget);
      expect(find.byIcon(Icons.block), findsOneWidget);

      final title = tester.widget<Text>(find.text('Vacina Aftosa'));
      expect(title.style?.decoration, TextDecoration.lineThrough);
    });

    testWidgets(
        'navigation: tapping a sanitary event navigates to /aplicacoes/:id',
        (tester) async {
      await tester.pumpWidget(_buildRoutedScreen(
        animal: _activeAnimal,
        sanitaryBuilder: (id) async => [
          _app(
            id: 'app-7',
            doseName: 'Ivomec Gold',
            appliedAt: DateTime(2026, 5, 12),
          ),
        ],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ivomec Gold'));
      await tester.pumpAndSettle();

      expect(find.text('aplicacao-detail-app-7'), findsOneWidget);
    });
  });

  group('AnimalDetailScreen — filtros e "ver histórico completo"', () {
    testWidgets('Sanitário filter hides reproductive events', (tester) async {
      await tester.pumpWidget(_buildScreen(
        animal: _activeAnimal,
        role: 'veterinarian',
        historyBuilder: (id) async => [_atfPrimavera],
        sanitaryBuilder: (id) async => [
          _app(
            id: 'app-1',
            doseName: 'Ivomec Gold',
            appliedAt: DateTime(2026, 5, 12),
          ),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('ATF Primavera'), findsOneWidget);
      expect(find.text('Ivomec Gold'), findsOneWidget);

      await tester.tap(find.text('Sanitário'));
      await tester.pumpAndSettle();

      expect(find.textContaining('ATF Primavera'), findsNothing);
      expect(find.text('Ivomec Gold'), findsOneWidget);

      await tester.tap(find.text('Reprodução'));
      await tester.pumpAndSettle();

      expect(find.textContaining('ATF Primavera'), findsOneWidget);
      expect(find.text('Ivomec Gold'), findsNothing);
    });

    testWidgets(
        '>10 events: truncates at 10 and "Ver histórico completo (N)" expands',
        (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;

      final apps = [
        for (var i = 0; i < 12; i++)
          _app(
            id: 'app-$i',
            doseName: 'Dose $i',
            appliedAt: DateTime(2026, 1, 1).add(Duration(days: i)),
          ),
      ];
      await tester.pumpWidget(_buildScreen(
        animal: _activeAnimal,
        role: 'veterinarian',
        sanitaryBuilder: (id) async => apps,
      ));
      await tester.pumpAndSettle();

      // 12 sanitary + cadastro = 13 total, only 10 rendered.
      expect(find.text('Ver histórico completo (13)'), findsOneWidget);
      expect(find.text('Cadastrado no rebanho'), findsNothing);

      await tester.tap(find.text('Ver histórico completo (13)'));
      await tester.pumpAndSettle();

      expect(find.text('Ver histórico completo (13)'), findsNothing);
      expect(find.text('Cadastrado no rebanho'), findsOneWidget);
    });

    testWidgets('timeline card is read-only — no buttons among the events',
        (tester) async {
      await tester.pumpWidget(_buildScreen(
        animal: _activeAnimal,
        role: 'veterinarian',
        historyBuilder: (id) async => [_atfPrimavera, _atfOutono],
      ));
      await tester.pumpAndSettle();

      final timelineCard = find.ancestor(
        of: find.text('Cadastrado no rebanho'),
        matching: find.byType(Card),
      );
      expect(timelineCard, findsOneWidget);
      expect(
        find.descendant(
          of: timelineCard,
          matching: find.byWidgetPredicate(
            (w) => w is ButtonStyleButton || w is IconButton,
          ),
        ),
        findsNothing,
      );
    });
  });

  group('AnimalDetailScreen — card de estado (EC + observação)', () {
    testWidgets('shows EC meter and observation text when both set',
        (tester) async {
      final animal = _activeAnimal.copyWith(
        bodyCondition: 3,
        observation: 'Manso, fácil manejo.',
      );
      await tester.pumpWidget(
        _buildScreen(animal: animal, role: 'veterinarian'),
      );
      await tester.pumpAndSettle();

      expect(find.text('ESTADO CORPORAL'), findsOneWidget);
      expect(find.text('3/5'), findsOneWidget);
      expect(find.text('OBSERVAÇÃO'), findsOneWidget);
      expect(find.text('Manso, fácil manejo.'), findsOneWidget);
    });

    testWidgets('renders full multi-line observation text, not just first line',
        (tester) async {
      final animal = _activeAnimal.copyWith(
        observation: 'Tratamento inicial em 10/01.\nBaixa em 20/03: vendido.',
      );
      await tester.pumpWidget(
        _buildScreen(animal: animal, role: 'veterinarian'),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Baixa em 20/03: vendido.'), findsOneWidget);
    });
  });

  group('AnimalDetailScreen — Banner de baixa (D-12..D-15, SC-4)', () {
    testWidgets('active animal: no banner', (tester) async {
      await tester.pumpWidget(
        _buildScreen(animal: _activeAnimal, role: 'veterinarian'),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.info_outline), findsNothing);
    });

    testWidgets(
        'sold animal with date and observation: banner shows reason, date and observation',
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
        find.textContaining(
            'Vendido em 01/06/2025 — Vendido em leilão da região.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'sold animal without observation: banner shows reason and date, no dangling dash',
        (tester) async {
      final animal = _archivedAnimal.copyWith(baixaDate: DateTime(2025, 6, 1));
      await tester.pumpWidget(
        _buildScreen(animal: animal, role: 'veterinarian'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Vendido em 01/06/2025'), findsOneWidget);
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

    testWidgets('banner renders above the state card (D-12 order)',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(animal: _archivedAnimal, role: 'veterinarian'),
      );
      await tester.pumpAndSettle();

      final bannerY = tester.getTopLeft(find.byIcon(Icons.info_outline)).dy;
      final cardY = tester.getTopLeft(find.text('ESTADO CORPORAL')).dy;
      expect(bannerY, lessThan(cardY));
    });

    testWidgets('archived animal: timeline stays reachable (D-16)',
        (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        _buildScreen(animal: _archivedAnimal, role: 'veterinarian'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tudo'), findsOneWidget);
      expect(find.text('Reprodução'), findsOneWidget);
      expect(find.text('Sanitário'), findsOneWidget);
      expect(find.text('Cadastrado no rebanho'), findsOneWidget);
    });
  });

  group('AnimalDetailScreen — layout a 360px', () {
    testWidgets('360px: no layout overflow with long lot/paddock names',
        (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      tester.view.physicalSize = const Size(360, 1400);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        _buildScreen(
          animal: _activeAnimal.copyWith(breed: 'Nelore', bodyCondition: 3),
          role: 'veterinarian',
          lotWithPaddockBuilder: (id) async => LotWithPaddockName(
            lot: Lot(
              id: 'lot-A',
              propertyId: 'prop-1',
              paddockId: 'pad-1',
              name: 'Lote Fundo de Vale Extremamente Comprido do Setor Norte',
              createdAt: DateTime(2025, 1, 1),
            ),
            paddockName:
                'Piquete Extremamente Comprido do Fundo do Setor Sul',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('#9'), findsOneWidget);
    });
  });
}
