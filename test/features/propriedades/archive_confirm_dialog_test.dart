import 'package:campo_gestor/core/widgets/ui.dart';
import 'package:campo_gestor/features/propriedades/presentation/archive_confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildApp(String propertyName) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showAdaptiveForm<bool>(
            context: context,
            width: FormWidth.confirm,
            builder: (_) => ArchiveConfirmDialog(propertyName: propertyName),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
}

void main() {
  group('ArchiveConfirmDialog', () {
    testWidgets('shows title, body with farm name, hint and buttons',
        (tester) async {
      await tester.pumpWidget(_buildApp('Santa Rita'));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.text('Arquivar fazenda'), findsOneWidget);
      expect(find.textContaining('Santa Rita'), findsOneWidget);
      expect(
        find.textContaining('Digite o nome da fazenda para confirmar.'),
        findsOneWidget,
      );
      expect(find.text('Nome da fazenda'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Arquivar'), findsOneWidget);
    });

    testWidgets('confirm button starts disabled', (tester) async {
      await tester.pumpWidget(_buildApp('Santa Rita'));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Arquivar'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('typing a prefix keeps the button disabled', (tester) async {
      await tester.pumpWidget(_buildApp('Santa Rita'));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Santa');
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Arquivar'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('typing a different case keeps the button disabled',
        (tester) async {
      await tester.pumpWidget(_buildApp('Santa Rita'));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'santa rita');
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Arquivar'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('typing the exact name enables the button', (tester) async {
      await tester.pumpWidget(_buildApp('Santa Rita'));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Santa Rita');
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Arquivar'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('tapping the enabled confirm button returns true',
        (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showAdaptiveForm<bool>(
                    context: context,
                    width: FormWidth.confirm,
                    builder: (_) => const ArchiveConfirmDialog(
                      propertyName: 'Santa Rita',
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Santa Rita');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Arquivar'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('cancel button closes dialog with false or null',
        (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showAdaptiveForm<bool>(
                    context: context,
                    width: FormWidth.confirm,
                    builder: (_) => const ArchiveConfirmDialog(
                      propertyName: 'Santa Rita',
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar'));
      await tester.pumpAndSettle();

      expect(result, anyOf(isNull, isFalse));
    });

    testWidgets('long farm name wraps without truncation', (tester) async {
      const longName =
          'Fazenda Muito Longa Com Nome Extenso Para Testar Quebra De Linha '
          'No Corpo Do Dialogo De Arquivamento';
      await tester.pumpWidget(_buildApp(longName));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      final textWidgets = tester.widgetList<Text>(
        find.textContaining('Fazenda Muito Longa'),
      );
      for (final t in textWidgets) {
        expect(t.overflow, isNot(TextOverflow.ellipsis));
        expect(t.maxLines, isNull);
      }
    });
  });
}
