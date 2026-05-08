import 'package:campo_gestor/core/providers/current_property_provider.dart';
import 'package:campo_gestor/features/auth/data/property_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

ProviderContainer _makeContainer(List<PropertyMembership> memberships) {
  return ProviderContainer(
    overrides: [
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
        property: SelectedProperty(id: 'p1', name: 'Fazenda Solo'),
        role: 'owner',
      ),
    ]);
    addTearDown(container.dispose);

    final v = await container.read(currentPropertyProvider.future);
    expect(v, isNotNull);
    expect(v!.id, 'p1');
    expect(v.name, 'Fazenda Solo');
  });

  test('with N properties uses saved id from SharedPreferences (D-06)',
      () async {
    SharedPreferences.setMockInitialValues({'active_property_id': 'p2'});

    final container = _makeContainer(const [
      PropertyMembership(
        property: SelectedProperty(id: 'p1', name: 'Alpha'),
        role: 'owner',
      ),
      PropertyMembership(
        property: SelectedProperty(id: 'p2', name: 'Beta'),
        role: 'veterinarian',
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
        property: SelectedProperty(id: 'p1', name: 'Alpha'),
        role: 'owner',
      ),
      PropertyMembership(
        property: SelectedProperty(id: 'p2', name: 'Beta'),
        role: 'reader',
      ),
    ]);
    addTearDown(container.dispose);

    final v = await container.read(currentPropertyProvider.future);
    expect(v?.id, 'p1', reason: 'Should fall back to first when saved id missing');
  });

  test('selectProperty persists id and updates state', () async {
    final container = _makeContainer(const [
      PropertyMembership(
        property: SelectedProperty(id: 'p1', name: 'Alpha'),
        role: 'owner',
      ),
      PropertyMembership(
        property: SelectedProperty(id: 'p2', name: 'Beta'),
        role: 'veterinarian',
      ),
    ]);
    addTearDown(container.dispose);

    await container.read(currentPropertyProvider.future);
    await container
        .read(currentPropertyProvider.notifier)
        .selectProperty(const SelectedProperty(id: 'p2', name: 'Beta'));

    final updated = container.read(currentPropertyProvider).asData?.value;
    expect(updated?.id, 'p2');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('active_property_id'), 'p2');
  });

  test('clear() removes saved id and zeroes state', () async {
    SharedPreferences.setMockInitialValues({'active_property_id': 'p1'});

    final container = _makeContainer(const [
      PropertyMembership(
        property: SelectedProperty(id: 'p1', name: 'Alpha'),
        role: 'owner',
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
