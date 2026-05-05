import 'package:campo_gestor/core/providers/current_property_provider.dart';
import 'package:campo_gestor/features/auth/data/property_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

ProviderContainer _makeContainer(List<PropertyMembership> memberships) {
  return ProviderContainer(
    overrides: [
      // Override memberPropertiesProvider so we don't have to wire a fake
      // authNotifier and SupabaseService.
      memberPropertiesProvider.overrideWith((ref) async => memberships),
    ],
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('returns null when user has 0 properties', () async {
    final container = _makeContainer(const []);
    addTearDown(container.dispose);

    final v = await container.read(currentPropertyProvider.future);
    expect(v, isNull);
  });

  test('auto-selects with 1 property (D-05)', () async {
    final container = _makeContainer(const [
      PropertyMembership(
        property: Property(id: 'p1', nome: 'Fazenda Solo'),
        perfil: 'proprietario',
      ),
    ]);
    addTearDown(container.dispose);

    final v = await container.read(currentPropertyProvider.future);
    expect(v, isNotNull);
    expect(v!.id, 'p1');
    expect(v.nome, 'Fazenda Solo');
  });

  test('with N properties uses saved id from SharedPreferences (D-06)',
      () async {
    SharedPreferences.setMockInitialValues({'active_property_id': 'p2'});

    final container = _makeContainer(const [
      PropertyMembership(
        property: Property(id: 'p1', nome: 'Alpha'),
        perfil: 'proprietario',
      ),
      PropertyMembership(
        property: Property(id: 'p2', nome: 'Beta'),
        perfil: 'veterinario',
      ),
    ]);
    addTearDown(container.dispose);

    final v = await container.read(currentPropertyProvider.future);
    expect(v?.id, 'p2');
  });

  test('with N properties falls back to first when saved id stale (Pitfall 4)',
      () async {
    SharedPreferences.setMockInitialValues({
      'active_property_id': 'GHOST-NOT-IN-LIST',
    });

    final container = _makeContainer(const [
      PropertyMembership(
        property: Property(id: 'p1', nome: 'Alpha'),
        perfil: 'proprietario',
      ),
      PropertyMembership(
        property: Property(id: 'p2', nome: 'Beta'),
        perfil: 'leitor',
      ),
    ]);
    addTearDown(container.dispose);

    final v = await container.read(currentPropertyProvider.future);
    expect(v?.id, 'p1', reason: 'Should fall back to first when saved id missing');
  });

  test('selectProperty persists id and updates state', () async {
    final container = _makeContainer(const [
      PropertyMembership(
        property: Property(id: 'p1', nome: 'Alpha'),
        perfil: 'proprietario',
      ),
      PropertyMembership(
        property: Property(id: 'p2', nome: 'Beta'),
        perfil: 'veterinario',
      ),
    ]);
    addTearDown(container.dispose);

    await container.read(currentPropertyProvider.future);
    await container
        .read(currentPropertyProvider.notifier)
        .selectProperty(const Property(id: 'p2', nome: 'Beta'));

    final updated = container.read(currentPropertyProvider).asData?.value;
    expect(updated?.id, 'p2');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('active_property_id'), 'p2');
  });

  test('clear() removes saved id and zeroes state', () async {
    SharedPreferences.setMockInitialValues({'active_property_id': 'p1'});

    final container = _makeContainer(const [
      PropertyMembership(
        property: Property(id: 'p1', nome: 'Alpha'),
        perfil: 'proprietario',
      ),
    ]);
    addTearDown(container.dispose);

    await container.read(currentPropertyProvider.future);
    await container.read(currentPropertyProvider.notifier).clear();

    final state = container.read(currentPropertyProvider).asData?.value;
    expect(state, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('active_property_id'), isNull);
  });
}
