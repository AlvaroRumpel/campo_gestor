// Task 3, quick task 260813-vvh — SanitarioScreen desktop tables
// (>=Breakpoints.rail): AplicacoesTableView + DosesTableView, mobile path
// (cards) intacto abaixo de 1024px. Harness `setSurfaceSize` de
// lotes_desktop_test.dart.
import 'package:campo_gestor/core/providers/current_property_provider.dart';
import 'package:campo_gestor/core/router/routes.dart';
import 'package:campo_gestor/features/auth/data/property_repository.dart';
import 'package:campo_gestor/features/lotes/data/lote_repository.dart';
import 'package:campo_gestor/features/propriedades/data/propriedade_model.dart';
import 'package:campo_gestor/features/propriedades/data/propriedade_repository.dart';
import 'package:campo_gestor/features/sanitario/data/dose_model.dart';
import 'package:campo_gestor/features/sanitario/data/dose_repository.dart';
import 'package:campo_gestor/features/sanitario/data/sanitary_application_model.dart';
import 'package:campo_gestor/features/sanitario/data/sanitary_application_repository.dart';
import 'package:campo_gestor/features/sanitario/presentation/sanitario_screen.dart';
import 'package:campo_gestor/features/sanitario/presentation/sanitario_table_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// ---------------------------------------------------------------------------
// Fake data
// ---------------------------------------------------------------------------

const _prop = SelectedProperty(id: 'prop-1', name: 'Fazenda Alpha');
const _vetMembership =
    PropertyMembership(property: _prop, role: 'veterinarian');

final _property = Property(
  id: 'prop-1',
  name: 'Fazenda Alpha',
  createdAt: DateTime(2026, 1, 1),
  kgPerUa: 400,
);

// app-1: aplicação normal, nunca estornada. app-2: aplicação original que
// FOI estornada. app-3: o estorno de app-2 (reversesApplicationId aponta
// para app-2, fazendo `reversedApplicationIds` marcar app-2). Com o toggle
// "Mostrar estornadas" desligado (default), app-2 e app-3 somem e só app-1
// fica visível — é o que garante uma linha na tabela por padrão.
final _appNormal = SanitaryApplication(
  id: 'app-1',
  propertyId: 'prop-1',
  lotId: 'lot-1',
  lotName: 'Lote A',
  paddockId: 'pad-1',
  paddockName: 'Piquete 1',
  doseId: 'dose-1',
  doseName: 'Ivomec Gold',
  dosagePerKg: 1.0,
  dosagePerUa: 400,
  costPerKg: 2.0,
  costPerUa: 800,
  appliedAt: DateTime(2026, 3, 10),
  appliedBy: 'user-1',
  animalCount: 5,
  totalUa: 5.0,
  totalVolume: 2000,
  totalCost: 1600,
  skippedCount: 0,
  createdAt: DateTime(2026, 3, 10),
);

final _appOriginal = SanitaryApplication(
  id: 'app-2',
  propertyId: 'prop-1',
  lotId: 'lot-1',
  lotName: 'Lote A',
  paddockId: 'pad-1',
  paddockName: 'Piquete 1',
  doseId: 'dose-1',
  doseName: 'Ivomec Gold',
  dosagePerKg: 1.0,
  dosagePerUa: 400,
  costPerKg: 2.0,
  costPerUa: 800,
  appliedAt: DateTime(2026, 3, 5),
  appliedBy: 'user-1',
  animalCount: 3,
  totalUa: 3.0,
  totalVolume: 1200,
  totalCost: 960,
  skippedCount: 0,
  createdAt: DateTime(2026, 3, 5),
);

final _appReversal = SanitaryApplication(
  id: 'app-3',
  propertyId: 'prop-1',
  lotId: 'lot-1',
  lotName: 'Lote A',
  paddockId: 'pad-1',
  paddockName: 'Piquete 1',
  doseId: 'dose-1',
  doseName: 'Ivomec Gold',
  dosagePerKg: 1.0,
  dosagePerUa: 400,
  costPerKg: 2.0,
  costPerUa: 800,
  appliedAt: DateTime(2026, 3, 5),
  appliedBy: 'user-1',
  animalCount: -3,
  totalUa: -3.0,
  totalVolume: -1200,
  totalCost: -960,
  skippedCount: 0,
  reversesApplicationId: 'app-2',
  createdAt: DateTime(2026, 3, 6),
);

final _applications = [_appNormal, _appOriginal, _appReversal];

final _activeDoses = <Dose>[
  Dose(
    id: 'dose-1',
    propertyId: 'prop-1',
    name: 'Ivomec Gold',
    activeIngredient: 'Ivermectina',
    dosagePerKg: 1.0,
    costPerKg: 2.0,
    createdAt: DateTime(2026, 1, 1),
  ),
  Dose(
    id: 'dose-2',
    propertyId: 'prop-1',
    name: 'Vacina Aftosa',
    dosagePerKg: 0.5,
    createdAt: DateTime(2026, 1, 1),
  ),
];

final _archivedDoses = <Dose>[
  Dose(
    id: 'dose-3',
    propertyId: 'prop-1',
    name: 'Dose Antiga',
    dosagePerKg: 1.2,
    costPerKg: 3.0,
    createdAt: DateTime(2025, 1, 1),
    deletedAt: DateTime(2026, 1, 1),
  ),
];

// ---------------------------------------------------------------------------
// Router stub (go_router needs a MaterialApp.router)
// ---------------------------------------------------------------------------

GoRouter _buildRouter() => GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SanitarioScreen(),
        ),
        GoRoute(
          path: AppRoutes.aplicacaoById,
          builder: (context, state) => Scaffold(
            body: Text('aplicacao-${state.pathParameters['id']}'),
          ),
        ),
      ],
    );

Widget _buildScreen() {
  return ProviderScope(
    overrides: [
      memberPropertiesProvider.overrideWith((ref) async => [_vetMembership]),
      propertyListProvider.overrideWith((ref) async => [_property]),
      sanitaryApplicationListByPropertyProvider
          .overrideWith((ref) async => _applications),
      doseListByPropertyProvider.overrideWith((ref) async => _activeDoses),
      archivedDoseListByPropertyProvider
          .overrideWith((ref) async => _archivedDoses),
      loteListByPropertyProvider.overrideWith((ref) async => const []),
    ],
    child: MaterialApp.router(routerConfig: _buildRouter()),
  );
}

Future<void> _pumpDesktop(WidgetTester tester) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  await tester.pumpWidget(_buildScreen());
  await tester.pumpAndSettle();
}

Future<void> _pumpMobile(WidgetTester tester) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(800, 600));
  await tester.pumpWidget(_buildScreen());
  await tester.pumpAndSettle();
}

Future<void> _switchToDoses(WidgetTester tester) async {
  await tester.tap(find.text('Doses'));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SanitarioScreen — tabelas desktop (260813-vvh)', () {
    testWidgets(
        '1440x900, aba Aplicações: AplicacoesTableView renders with a '
        'PIQUETE column header', (tester) async {
      await _pumpDesktop(tester);

      expect(find.byType(AplicacoesTableView), findsOneWidget);
      expect(find.text('PIQUETE'), findsOneWidget);
    });

    testWidgets(
        '1440x900, aba Aplicações com "Mostrar estornadas" ligado: a linha '
        'estornada continua na tabela com o chip "Estornada"',
        (tester) async {
      await _pumpDesktop(tester);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(find.byType(AplicacoesTableView), findsOneWidget);
      expect(find.text('Estornada'), findsOneWidget);
    });

    testWidgets(
        '1440x900, aba Doses: DosesTableView renders with an ML/UA header '
        'and a kg/UA footer note', (tester) async {
      await _pumpDesktop(tester);
      await _switchToDoses(tester);

      expect(find.byType(DosesTableView), findsOneWidget);
      expect(find.text('ML/UA'), findsOneWidget);
      expect(find.textContaining('kg/UA'), findsWidgets);
    });

    testWidgets(
        '1440x900, aba Doses com "Mostrar arquivadas" ligado: chip '
        '"Arquivada" e ação "Reativar dose" aparecem', (tester) async {
      await _pumpDesktop(tester);
      await _switchToDoses(tester);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(find.byType(DosesTableView), findsOneWidget);
      expect(find.text('Arquivada'), findsOneWidget);
      expect(find.byTooltip('Reativar dose'), findsOneWidget);
    });

    testWidgets(
        '800x600, as duas abas: nem AplicacoesTableView nem DosesTableView '
        'aparecem — caminho mobile intacto', (tester) async {
      await _pumpMobile(tester);

      expect(find.byType(AplicacoesTableView), findsNothing);
      expect(find.byType(DosesTableView), findsNothing);

      await _switchToDoses(tester);

      expect(find.byType(AplicacoesTableView), findsNothing);
      expect(find.byType(DosesTableView), findsNothing);
    });
  });
}
