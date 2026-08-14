// MEMB-01/02 — InviteFormDialog widget tests. Isolated from the screen that
// opens it (10-05); this file mounts the dialog directly.
import 'package:campo_gestor/core/services/supabase_service.dart';
import 'package:campo_gestor/features/membros/data/membro_repository.dart';
import 'package:campo_gestor/features/membros/presentation/invite_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

// SupabaseService() is safe to construct — its client getter is never
// invoked because every method exercised by the test is overridden below
// (same pattern as _FakeAnimalRepo in test/widget/baixa_dialog_test.dart).
class _FakeMembroRepository extends MembroRepository {
  _FakeMembroRepository(this._onCreateInvite) : super(SupabaseService());

  final Future<void> Function({
    required String propertyId,
    required String email,
    required String role,
  }) _onCreateInvite;

  int createInviteCallCount = 0;
  Map<String, String>? lastCreateInviteArgs;

  @override
  Future<void> createInvite({
    required String propertyId,
    required String email,
    required String role,
  }) async {
    createInviteCallCount++;
    lastCreateInviteArgs = {
      'propertyId': propertyId,
      'email': email,
      'role': role,
    };
    await _onCreateInvite(propertyId: propertyId, email: email, role: role);
  }
}

Widget _buildDialog(MembroRepository repo) {
  return ProviderScope(
    overrides: [
      membroRepositoryProvider.overrideWithValue(repo),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: InviteFormDialog(propertyId: 'prop-1'),
      ),
    ),
  );
}

void main() {
  group('InviteFormDialog (MEMB-01/02)', () {
    testWidgets(
        'renders title, fields and buttons per the copywriting contract',
        (tester) async {
      final repo = _FakeMembroRepository((
              {required propertyId, required email, required role}) async {});
      await tester.pumpWidget(_buildDialog(repo));

      expect(find.text('Convidar membro'), findsOneWidget);
      expect(find.text('E-mail do convidado *'), findsOneWidget);
      expect(find.text('Papel'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Enviar convite'), findsOneWidget);
    });

    testWidgets('dropdown offers exactly Veterinário / Proprietário / Leitor',
        (tester) async {
      final repo = _FakeMembroRepository((
              {required propertyId, required email, required role}) async {});
      await tester.pumpWidget(_buildDialog(repo));

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      // Flutter's DropdownButtonFormField builds each item's Text twice when
      // the menu opens (an offstage sizing pass + the visible menu route);
      // dedupe by label instead of counting raw widget instances.
      final labels = tester
          .widgetList<Text>(find.descendant(
            of: find.byType(DropdownMenuItem<String>),
            matching: find.byType(Text),
          ))
          .map((t) => t.data)
          .toSet();
      expect(labels, {'Veterinário', 'Proprietário', 'Leitor'});
    });

    testWidgets('empty email: shows validation error and calls no repository',
        (tester) async {
      final repo = _FakeMembroRepository((
              {required propertyId, required email, required role}) async {});
      await tester.pumpWidget(_buildDialog(repo));

      await tester.tap(find.text('Enviar convite'));
      await tester.pumpAndSettle();

      expect(find.text('Informe o e-mail do convidado.'), findsOneWidget);
      expect(repo.createInviteCallCount, 0);
    });

    testWidgets('email without @: shows validation error and calls no repository',
        (tester) async {
      final repo = _FakeMembroRepository((
              {required propertyId, required email, required role}) async {});
      await tester.pumpWidget(_buildDialog(repo));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-mail do convidado *'),
        'not-an-email',
      );
      await tester.tap(find.text('Enviar convite'));
      await tester.pumpAndSettle();

      expect(find.text('Informe um e-mail válido.'), findsOneWidget);
      expect(repo.createInviteCallCount, 0);
    });

    testWidgets(
        'valid email: calls createInvite once with propertyId, email and role',
        (tester) async {
      final repo = _FakeMembroRepository((
              {required propertyId, required email, required role}) async {});
      await tester.pumpWidget(_buildDialog(repo));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-mail do convidado *'),
        'novo@exemplo.com',
      );
      await tester.tap(find.text('Enviar convite'));
      await tester.pumpAndSettle();

      expect(repo.createInviteCallCount, 1);
      expect(repo.lastCreateInviteArgs, {
        'propertyId': 'prop-1',
        'email': 'novo@exemplo.com',
        'role': 'reader',
      });
    });

    testWidgets(
        'createInvite raises 23505: dialog stays open with the pt-BR '
        '"already invited" message, never the raw exception text',
        (tester) async {
      final repo = _FakeMembroRepository((
          {required propertyId, required email, required role}) async {
        throw const PostgrestException(
          message: 'duplicate key value',
          code: '23505',
        );
      });
      await tester.pumpWidget(_buildDialog(repo));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-mail do convidado *'),
        'ja@convidado.com',
      );
      await tester.tap(find.text('Enviar convite'));
      await tester.pumpAndSettle();

      expect(
        find.text('Este e-mail já foi convidado ou já é membro desta fazenda.'),
        findsOneWidget,
      );
      expect(find.textContaining('duplicate key value'), findsNothing);
      expect(find.text('Convidar membro'), findsOneWidget);
    });
  });
}
