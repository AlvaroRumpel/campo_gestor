// MEMB-01/02 — InviteBanner widget tests: the single shared invite
// accept/decline widget consumed by /sem-acesso (10-08) and the dashboard
// banner (10-09).
import 'dart:async';

import 'package:campo_gestor/core/providers/current_property_provider.dart';
import 'package:campo_gestor/core/services/supabase_service.dart';
import 'package:campo_gestor/features/membros/data/membro_models.dart';
import 'package:campo_gestor/features/membros/data/membro_repository.dart';
import 'package:campo_gestor/features/membros/presentation/invite_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

// SupabaseService() is safe to construct — its client getter is never
// invoked because every method exercised by the test is overridden below
// (same pattern as _FakeAnimalRepo in test/widget/baixa_dialog_test.dart).
class _FakeMembroRepository extends MembroRepository {
  _FakeMembroRepository({this.acceptError}) : super(SupabaseService());

  final Object? acceptError;

  int acceptCallCount = 0;
  int declineCallCount = 0;
  String? lastAcceptId;
  String? lastDeclineId;

  // Both writes stay "in flight" until the test releases them, so a second
  // tap during the pending call can be exercised deterministically.
  final _acceptGate = Completer<void>();
  final _declineGate = Completer<void>();
  bool acceptGated = false;
  bool declineGated = false;

  void releaseAccept() => _acceptGate.complete();
  void releaseDecline() => _declineGate.complete();

  @override
  Future<void> acceptInvite(String inviteId) async {
    acceptCallCount++;
    lastAcceptId = inviteId;
    if (acceptGated) await _acceptGate.future;
    if (acceptError != null) throw acceptError!;
  }

  @override
  Future<void> declineInvite(String inviteId) async {
    declineCallCount++;
    lastDeclineId = inviteId;
    if (declineGated) await _declineGate.future;
  }
}

final _invite = MyInvite(
  id: 'invite-1',
  propertyId: 'prop-1',
  propertyName: 'Fazenda Solo',
  role: 'veterinarian',
  createdAt: DateTime(2026, 1, 1),
);

MyInvite _inviteWith({required String propertyName, String role = 'reader'}) =>
    MyInvite(
      id: 'invite-1',
      propertyId: 'prop-1',
      propertyName: propertyName,
      role: role,
      createdAt: DateTime(2026, 1, 1),
    );

Widget _buildBanner({
  required ProviderContainer container,
  MyInvite? invite,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(body: InviteBanner(invite: invite ?? _invite)),
    ),
  );
}

void main() {
  group('InviteBanner (MEMB-01/02)', () {
    testWidgets('renders the exact invite phrase with farm and role',
        (tester) async {
      final repo = _FakeMembroRepository();
      final container = ProviderContainer(overrides: [
        membroRepositoryProvider.overrideWithValue(repo),
        memberPropertiesProvider.overrideWith((ref) async => []),
        myInvitesProvider.overrideWith((ref) async => []),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildBanner(container: container));

      expect(
        find.text(
          'Você recebeu um convite para Fazenda Solo como Veterinário.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders an Aceitar FilledButton and a Recusar OutlinedButton',
        (tester) async {
      final repo = _FakeMembroRepository();
      final container = ProviderContainer(overrides: [
        membroRepositoryProvider.overrideWithValue(repo),
        memberPropertiesProvider.overrideWith((ref) async => []),
        myInvitesProvider.overrideWith((ref) async => []),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildBanner(container: container));

      expect(find.widgetWithText(FilledButton, 'Aceitar'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Recusar'), findsOneWidget);
    });

    testWidgets(
        'tapping Aceitar calls acceptInvite exactly once with the invite id',
        (tester) async {
      final repo = _FakeMembroRepository();
      final container = ProviderContainer(overrides: [
        membroRepositoryProvider.overrideWithValue(repo),
        memberPropertiesProvider.overrideWith((ref) async => []),
        myInvitesProvider.overrideWith((ref) async => []),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildBanner(container: container));
      await tester.tap(find.widgetWithText(FilledButton, 'Aceitar'));
      await tester.pumpAndSettle();

      expect(repo.acceptCallCount, 1);
      expect(repo.lastAcceptId, 'invite-1');
    });

    testWidgets(
        'successful accept invalidates memberPropertiesProvider and '
        'myInvitesProvider, and triggers no navigation', (tester) async {
      final repo = _FakeMembroRepository();
      var memberPropsBuilds = 0;
      var myInvitesBuilds = 0;
      final container = ProviderContainer(overrides: [
        membroRepositoryProvider.overrideWithValue(repo),
        memberPropertiesProvider.overrideWith((ref) async {
          memberPropsBuilds++;
          return [];
        }),
        myInvitesProvider.overrideWith((ref) async {
          myInvitesBuilds++;
          return [];
        }),
      ]);
      addTearDown(container.dispose);
      // Active listeners keep both providers alive so ref.invalidate()
      // triggers an eager rebuild instead of only marking them dirty.
      container.listen(memberPropertiesProvider, (_, _) {});
      container.listen(myInvitesProvider, (_, _) {});
      await container.read(memberPropertiesProvider.future);
      await container.read(myInvitesProvider.future);
      expect(memberPropsBuilds, 1);
      expect(myInvitesBuilds, 1);

      await tester.pumpWidget(_buildBanner(container: container));
      await tester.tap(find.widgetWithText(FilledButton, 'Aceitar'));
      await tester.pumpAndSettle();

      expect(memberPropsBuilds, 2);
      expect(myInvitesBuilds, 2);
      // MaterialApp has no GoRouter in this test tree — a context.go/push
      // call would throw. No exception means no navigation was attempted.
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'tapping Recusar calls declineInvite once with the invite id',
        (tester) async {
      final repo = _FakeMembroRepository();
      final container = ProviderContainer(overrides: [
        membroRepositoryProvider.overrideWithValue(repo),
        memberPropertiesProvider.overrideWith((ref) async => []),
        myInvitesProvider.overrideWith((ref) async => []),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildBanner(container: container));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Recusar'));
      await tester.pumpAndSettle();

      expect(repo.declineCallCount, 1);
      expect(repo.lastDeclineId, 'invite-1');
    });

    testWidgets(
        'decline invalidates only myInvitesProvider, never '
        'memberPropertiesProvider', (tester) async {
      final repo = _FakeMembroRepository();
      var memberPropsBuilds = 0;
      var myInvitesBuilds = 0;
      final container = ProviderContainer(overrides: [
        membroRepositoryProvider.overrideWithValue(repo),
        memberPropertiesProvider.overrideWith((ref) async {
          memberPropsBuilds++;
          return [];
        }),
        myInvitesProvider.overrideWith((ref) async {
          myInvitesBuilds++;
          return [];
        }),
      ]);
      addTearDown(container.dispose);
      container.listen(memberPropertiesProvider, (_, _) {});
      container.listen(myInvitesProvider, (_, _) {});
      await container.read(memberPropertiesProvider.future);
      await container.read(myInvitesProvider.future);
      expect(memberPropsBuilds, 1);
      expect(myInvitesBuilds, 1);

      await tester.pumpWidget(_buildBanner(container: container));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Recusar'));
      await tester.pumpAndSettle();

      expect(myInvitesBuilds, 2);
      expect(memberPropsBuilds, 1, reason: 'decline must not touch it');
    });

    testWidgets('Recusar does not open a confirmation dialog', (tester) async {
      final repo = _FakeMembroRepository();
      final container = ProviderContainer(overrides: [
        membroRepositoryProvider.overrideWithValue(repo),
        memberPropertiesProvider.overrideWith((ref) async => []),
        myInvitesProvider.overrideWith((ref) async => []),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildBanner(container: container));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Recusar'));
      await tester.pump();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(Dialog), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets(
        'a second tap during an in-flight accept does not fire a second call',
        (tester) async {
      final repo = _FakeMembroRepository()..acceptGated = true;
      final container = ProviderContainer(overrides: [
        membroRepositoryProvider.overrideWithValue(repo),
        memberPropertiesProvider.overrideWith((ref) async => []),
        myInvitesProvider.overrideWith((ref) async => []),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildBanner(container: container));
      await tester.tap(find.widgetWithText(FilledButton, 'Aceitar'));
      await tester.pump();

      expect(repo.acceptCallCount, 1);
      // Buttons are disabled while the first call is in flight.
      await tester.tap(find.widgetWithText(FilledButton, 'Aceitar'),
          warnIfMissed: false);
      await tester.pump();
      expect(repo.acceptCallCount, 1);

      repo.releaseAccept();
      await tester.pumpAndSettle();
    });

    testWidgets(
        'acceptInvite raising P0002 shows the generic stale-state SnackBar',
        (tester) async {
      final repo = _FakeMembroRepository(
        acceptError: const PostgrestException(message: 'stale', code: 'P0002'),
      );
      final container = ProviderContainer(overrides: [
        membroRepositoryProvider.overrideWithValue(repo),
        memberPropertiesProvider.overrideWith((ref) async => []),
        myInvitesProvider.overrideWith((ref) async => []),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildBanner(container: container));
      await tester.tap(find.widgetWithText(FilledButton, 'Aceitar'));
      await tester.pumpAndSettle();

      expect(
        find.text('Não foi possível concluir. Atualize a lista e tente novamente.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'at 360px width, a long farm name wraps across lines with no '
        'overflow exception', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _FakeMembroRepository();
      final container = ProviderContainer(overrides: [
        membroRepositoryProvider.overrideWithValue(repo),
        memberPropertiesProvider.overrideWith((ref) async => []),
        myInvitesProvider.overrideWith((ref) async => []),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildBanner(
        container: container,
        invite: _inviteWith(
          propertyName:
              'Fazenda Muito Extensa Com Um Nome Longuíssimo Para Testar Quebra De Linha',
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
