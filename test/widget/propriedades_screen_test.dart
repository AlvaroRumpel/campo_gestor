// PROPV-01, PROPV-02 — PropriedadesScreen: alternador Ativas/Arquivadas,
// arquivamento com confirmação forte, restauração pela UI.
import 'package:campo_gestor/core/providers/current_property_provider.dart';
import 'package:campo_gestor/core/services/supabase_service.dart';
import 'package:campo_gestor/features/auth/data/property_repository.dart';
import 'package:campo_gestor/features/propriedades/data/propriedade_model.dart';
import 'package:campo_gestor/features/propriedades/data/propriedade_repository.dart';
import 'package:campo_gestor/features/propriedades/presentation/propriedades_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// SupabaseService() is safe to construct — client getter is never called
// because every overridden method below avoids it.
class _FakePropertyRepository extends PropertyRepository {
  _FakePropertyRepository() : super(SupabaseService());

  int restoreCallCount = 0;
  String? restoredId;

  @override
  Future<void> restoreProperty(String id) async {
    restoreCallCount++;
    restoredId = id;
  }
}

Property _property({
  String id = 'prop-1',
  String name = 'Fazenda Alpha',
}) => Property(id: id, name: name, createdAt: DateTime(2025, 1, 1));

const _prop = SelectedProperty(id: 'prop-1', name: 'Fazenda Alpha');
const _vetMembership = PropertyMembership(property: _prop, role: 'veterinarian');
const _readerMembership = PropertyMembership(property: _prop, role: 'owner');

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
}
