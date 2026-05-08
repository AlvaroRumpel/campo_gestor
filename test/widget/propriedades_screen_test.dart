// Wave 0 RED stub for PROP-01 UI. Plan 04 makes this green.
import 'package:campo_gestor/features/propriedades/data/propriedade_model.dart';
import 'package:campo_gestor/features/propriedades/data/propriedade_repository.dart';
import 'package:campo_gestor/features/propriedades/presentation/propriedades_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('PropriedadesScreen shows empty state copy when list is empty', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          propriedadeListProvider.overrideWith((ref) async => <Propriedade>[]),
        ],
        child: const MaterialApp(home: PropriedadesScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma fazenda cadastrada'), findsOneWidget);
    expect(find.text('Crie sua primeira fazenda para começar a organizar o rebanho.'), findsOneWidget);
  });
}
