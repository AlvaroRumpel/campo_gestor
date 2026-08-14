// PROPV-01, PROPV-02, MEMB-02 — PropriedadesScreen: alternador
// Ativas/Arquivadas, arquivamento com confirmação forte, restauração pela
// UI, e o item "Membros" no menu do cartão (Fase 10 Plano 10).
import 'package:campo_gestor/core/providers/current_property_provider.dart';
import 'package:campo_gestor/core/router/routes.dart';
import 'package:campo_gestor/core/services/supabase_service.dart';
import 'package:campo_gestor/features/auth/data/property_repository.dart';
import 'package:campo_gestor/features/propriedades/data/propriedade_model.dart';
import 'package:campo_gestor/features/propriedades/data/propriedade_repository.dart';
import 'package:campo_gestor/features/propriedades/presentation/propriedades_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// SupabaseService() is safe to construct — client getter is never called
// because every overridden method below avoids it.
class _FakePropertyRepository extends PropertyRepository {
  _FakePropertyRepository() : super(SupabaseService());

  int restoreCallCount = 0;
  String? restoredId;
  int archiveCallCount = 0;
  String? archivedId;
  bool throwOnArchive = false;

  @override
  Future<void> restoreProperty(String id) async {
    restoreCallCount++;
    restoredId = id;
  }

  @override
  Future<void> softDeleteProperty(String id) async {
    if (throwOnArchive) throw Exception('boom');
    archiveCallCount++;
    archivedId = id;
  }
}

Property _property({
  String id = 'prop-1',
  String name = 'Fazenda Alpha',
}) => Property(id: id, name: name, createdAt: DateTime(2025, 1, 1));

const _prop = SelectedProperty(id: 'prop-1', name: 'Fazenda Alpha');
const _vetMembership = PropertyMembership(property: _prop, role: 'veterinarian');
const _readerMembership = PropertyMembership(property: _prop, role: 'owner');
// MEMB-02 (Task 2): canManageMembers is vet OR owner — distinct from
// _readerMembership above (misnamed pre-existing const, role is 'owner').
// This one carries the real 'reader' role for the two-gate coexistence tests.
const _trueReaderMembership = PropertyMembership(property: _prop, role: 'reader');

Widget _buildScreen({
  List<Property> active = const [],
  List<Property> archived = const [],
  List<PropertyMembership> members = const [_vetMembership],
  PropertyRepository? repository,
}) {
  return ProviderScope(
    overrides: [
      propertyListProvider.overrideWith((ref) async => active),
      archivedPropertyListProvider.overrideWith((ref) async => archived),
      // Single membership -> CurrentPropertyNotifier auto-selects it.
      memberPropertiesProvider.overrideWith((ref) async => members),
      if (repository != null)
        propertyRepositoryProvider.overrideWithValue(repository),
    ],
    child: const MaterialApp(home: PropriedadesScreen()),
  );
}

// Navigation-capable variant for the "selecting Membros navigates" test —
// mirrors the router harness in test/core/router_test.dart.
Widget _buildScreenWithRouter({
  List<Property> active = const [],
  List<PropertyMembership> members = const [_vetMembership],
}) {
  final router = GoRouter(
    initialLocation: AppRoutes.propriedades,
    routes: [
      GoRoute(
        path: AppRoutes.propriedades,
        builder: (ctx, _) => const PropriedadesScreen(),
      ),
      GoRoute(
        path: AppRoutes.membrosById,
        builder: (ctx, state) => Scaffold(
          body: Text('membros-${state.pathParameters['propertyId']}'),
        ),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      propertyListProvider.overrideWith((ref) async => active),
      archivedPropertyListProvider.overrideWith((ref) async => []),
      memberPropertiesProvider.overrideWith((ref) async => members),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('PropriedadesScreen shows empty state copy when list is empty', (tester) async {
    await tester.pumpWidget(_buildScreen());
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma fazenda cadastrada'), findsOneWidget);
    expect(find.text('Crie sua primeira fazenda para começar a organizar o rebanho.'), findsOneWidget);
  });

  testWidgets('Ativas tab selected by default shows active properties', (tester) async {
    await tester.pumpWidget(_buildScreen(active: [_property()]));
    await tester.pumpAndSettle();
    expect(find.text('Fazenda Alpha'), findsOneWidget);
  });

  testWidgets('tapping Arquivadas switches list to archivedPropertyListProvider', (tester) async {
    await tester.pumpWidget(
      _buildScreen(
        active: [_property(id: 'prop-1', name: 'Ativa')],
        archived: [_property(id: 'prop-2', name: 'Arquivada')],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ativa'), findsOneWidget);
    expect(find.text('Arquivada'), findsNothing);

    await tester.tap(find.text('Arquivadas'));
    await tester.pumpAndSettle();

    expect(find.text('Arquivada'), findsOneWidget);
    expect(find.text('Ativa'), findsNothing);
  });

  testWidgets('empty archived tab shows Nenhuma fazenda arquivada copy', (tester) async {
    await tester.pumpWidget(_buildScreen(active: [_property()]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Arquivadas'));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma fazenda arquivada'), findsOneWidget);
    expect(
      find.text('Fazendas arquivadas por você aparecem aqui para restaurar quando precisar.'),
      findsOneWidget,
    );
  });

  testWidgets('archived card shows Restaurar fazenda button, not PopupMenuButton', (tester) async {
    await tester.pumpWidget(_buildScreen(archived: [_property(id: 'prop-2', name: 'Arquivada')]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Arquivadas'));
    await tester.pumpAndSettle();

    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(find.text('Restaurar fazenda'), findsOneWidget);
  });

  testWidgets('active card still shows PopupMenuButton for veterinarian', (tester) async {
    await tester.pumpWidget(_buildScreen(active: [_property()]));
    await tester.pumpAndSettle();

    expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    expect(find.text('Restaurar fazenda'), findsNothing);
  });

  testWidgets('tapping Restaurar fazenda calls restoreProperty once with the id', (tester) async {
    final fakeRepo = _FakePropertyRepository();
    await tester.pumpWidget(
      _buildScreen(
        archived: [_property(id: 'prop-9', name: 'Arquivada')],
        repository: fakeRepo,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Arquivadas'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Restaurar fazenda'));
    await tester.pumpAndSettle();

    expect(fakeRepo.restoreCallCount, 1);
    expect(fakeRepo.restoredId, 'prop-9');
    expect(find.text('Erro ao restaurar a fazenda. Tente novamente.'), findsNothing);
  });

  testWidgets('FloatingActionButton only appears on Ativas tab', (tester) async {
    await tester.pumpWidget(_buildScreen(active: [_property()], archived: [_property(id: 'prop-2')]));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.tap(find.text('Arquivadas'));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('archived tab with non-veterinarian role hides Restaurar fazenda button', (tester) async {
    await tester.pumpWidget(
      _buildScreen(
        archived: [_property(id: 'prop-2', name: 'Arquivada')],
        members: const [_readerMembership],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Arquivadas'));
    await tester.pumpAndSettle();

    expect(find.text('Restaurar fazenda'), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
  });

  testWidgets('active card menu item is Arquivar, not Remover', (tester) async {
    await tester.pumpWidget(_buildScreen(active: [_property()]));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    expect(find.text('Arquivar'), findsOneWidget);
    expect(find.text('Remover'), findsNothing);
  });

  testWidgets('selecting Arquivar opens ArchiveConfirmDialog with the property name', (tester) async {
    await tester.pumpWidget(_buildScreen(active: [_property(name: 'Fazenda Alpha')]));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arquivar'));
    await tester.pumpAndSettle();

    expect(find.text('Arquivar fazenda'), findsOneWidget);
    expect(find.textContaining('Fazenda Alpha'), findsWidgets);
  });

  testWidgets('cancelling the dialog does not call softDeleteProperty', (tester) async {
    final fakeRepo = _FakePropertyRepository();
    await tester.pumpWidget(
      _buildScreen(active: [_property()], repository: fakeRepo),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arquivar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(fakeRepo.archiveCallCount, 0);
  });

  testWidgets('typing the exact name and confirming calls softDeleteProperty once', (tester) async {
    final fakeRepo = _FakePropertyRepository();
    await tester.pumpWidget(
      _buildScreen(
        active: [_property(id: 'prop-7', name: 'Fazenda Alpha')],
        repository: fakeRepo,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arquivar'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Fazenda Alpha');
    await tester.pumpAndSettle();
    // Two "Arquivar" texts on screen at this point: the dialog heading and
    // the confirm button label — the button is the tappable FilledButton.
    await tester.tap(
      find.descendant(of: find.byType(FilledButton), matching: find.text('Arquivar')),
    );
    await tester.pumpAndSettle();

    expect(fakeRepo.archiveCallCount, 1);
    expect(fakeRepo.archivedId, 'prop-7');
  });

  testWidgets('archive error shows an authored SnackBar, no raw db text', (tester) async {
    final fakeRepo = _FakePropertyRepository()..throwOnArchive = true;
    await tester.pumpWidget(
      _buildScreen(
        active: [_property(name: 'Fazenda Alpha')],
        repository: fakeRepo,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arquivar'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Fazenda Alpha');
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(FilledButton), matching: find.text('Arquivar')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Erro ao arquivar a fazenda. Tente novamente.'), findsOneWidget);
  });

  testWidgets('propriedades_screen.dart no longer contains an AlertDialog', (tester) async {
    // Regression guard for the removed generic confirmation dialog — a
    // widget-tree assertion mirroring the acceptance criteria's source scan.
    await tester.pumpWidget(_buildScreen(active: [_property()]));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arquivar'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });

  group('"Membros" no menu do cartão (MEMB-02, Fase 10 Plano 10)', () {
    testWidgets('veterinarian: menu contains Membros, Editar and Arquivar', (tester) async {
      await tester.pumpWidget(_buildScreen(active: [_property()]));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('Membros'), findsOneWidget);
      expect(find.text('Editar'), findsOneWidget);
      expect(find.text('Arquivar'), findsOneWidget);
    });

    testWidgets('owner: menu contains Membros but not Editar/Arquivar', (tester) async {
      await tester.pumpWidget(
        _buildScreen(active: [_property()], members: const [_readerMembership]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('Membros'), findsOneWidget);
      expect(find.text('Editar'), findsNothing);
      expect(find.text('Arquivar'), findsNothing);
    });

    testWidgets('reader: no PopupMenuButton at all', (tester) async {
      await tester.pumpWidget(
        _buildScreen(active: [_property()], members: const [_trueReaderMembership]),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PopupMenuButton<String>), findsNothing);
    });

    testWidgets('selecting Membros navigates to /propriedades/{id}/membros', (tester) async {
      await tester.pumpWidget(
        _buildScreenWithRouter(active: [_property(id: 'prop-9')]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Membros'));
      await tester.pumpAndSettle();

      expect(find.text('membros-prop-9'), findsOneWidget);
    });

    testWidgets('archived card does not offer Membros, only Restaurar fazenda', (tester) async {
      await tester.pumpWidget(
        _buildScreen(archived: [_property(id: 'prop-2', name: 'Arquivada')]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Arquivadas'));
      await tester.pumpAndSettle();

      expect(find.text('Membros'), findsNothing);
      expect(find.text('Restaurar fazenda'), findsOneWidget);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
    });

    testWidgets('_canEditProperties stays veterinarian-only (owner still cannot Editar/Arquivar)',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(active: [_property()], members: const [_readerMembership]),
      );
      await tester.pumpAndSettle();

      // Not empty memberships and current prop set -> FAB gated by canEdit,
      // which must stay false for owner (vet-only).
      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });
}
