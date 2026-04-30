import 'package:campo_gestor/core/providers/current_property_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('currentPropertyProvider returns null in initial state', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final value = await container.read(currentPropertyProvider.future);
    expect(value, isNull);
  });

  test('selectProperty updates state to provided Property', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Wait for initial null state to settle.
    await container.read(currentPropertyProvider.future);

    await container
        .read(currentPropertyProvider.notifier)
        .selectProperty(const Property(id: 'p1', nome: 'Fazenda Teste'));

    final asyncValue = container.read(currentPropertyProvider);
    final updated = asyncValue.asData?.value;
    expect(updated, isNotNull);
    expect(updated!.nome, 'Fazenda Teste');
  });
}
