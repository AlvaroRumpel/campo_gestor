// Wave 0 RED stub for PROP-02 UI. Plan 05 makes this green.
import 'package:campo_gestor/features/piquetes/data/piquete_model.dart';
import 'package:campo_gestor/features/piquetes/data/piquete_repository.dart';
import 'package:campo_gestor/features/piquetes/presentation/piquetes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('PiquetesScreen shows empty state copy when list is empty', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paddockListProvider.overrideWith((ref) async => <Paddock>[]),
        ],
        child: const MaterialApp(home: PiquetesScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nenhum piquete cadastrado'), findsOneWidget);
    expect(find.text('Adicione piquetes para começar a organizar os lotes da fazenda.'), findsOneWidget);
  });
}
