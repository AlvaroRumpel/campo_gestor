// MEMB-01 — /sem-acesso becomes the invitee's inbox: pending invites
// addressed to the logged-in email, rendered via InviteBanner (10-04), with
// loading/empty/error states and both exit actions preserved in every state
// (T-10-29).
import 'dart:async';

import 'package:campo_gestor/features/auth/presentation/no_access_screen.dart';
import 'package:campo_gestor/features/membros/data/membro_models.dart';
import 'package:campo_gestor/features/membros/data/membro_repository.dart';
import 'package:campo_gestor/features/membros/presentation/invite_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

MyInvite _inviteWith({
  String id = 'invite-1',
  String propertyName = 'Fazenda Solo',
  String role = 'veterinarian',
}) =>
    MyInvite(
      id: id,
      propertyId: 'prop-1',
      propertyName: propertyName,
      role: role,
      createdAt: DateTime(2026, 1, 1),
    );

GoRouter _buildRouter() => GoRouter(
      initialLocation: '/sem-acesso',
      routes: [
        GoRoute(
          path: '/sem-acesso',
          builder: (context, state) => const NoAccessScreen(),
        ),
        GoRoute(
          path: '/propriedades',
          builder: (context, state) =>
              const Scaffold(body: Text('propriedades-screen')),
        ),
      ],
    );

Widget _buildScreen(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: _buildRouter()),
  );
}

void main() {
  group('NoAccessScreen (MEMB-01)', () {
    testWidgets('empty invites: shows the new empty-state copy, not the old one',
        (tester) async {
      final container = ProviderContainer(overrides: [
        myInvitesProvider.overrideWith((ref) async => <MyInvite>[]),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildScreen(container));
      await tester.pumpAndSettle();

      expect(find.text('Nenhum convite no momento'), findsOneWidget);
      expect(
        find.text(
          'Peça para um veterinário da fazenda te convidar pelo seu '
          'e-mail de cadastro.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Entre em contato com o proprietário'),
        findsNothing,
      );
    });

    testWidgets(
        'empty invites: both exit actions stay present and functional',
        (tester) async {
      final container = ProviderContainer(overrides: [
        myInvitesProvider.overrideWith((ref) async => <MyInvite>[]),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildScreen(container));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Criar minha fazenda'),
          findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Sair'), findsOneWidget);

      await tester
          .tap(find.widgetWithText(FilledButton, 'Criar minha fazenda'));
      await tester.pumpAndSettle();

      expect(find.text('propriedades-screen'), findsOneWidget);
    });

    testWidgets('two pending invites render two InviteBanner widgets',
        (tester) async {
      final container = ProviderContainer(overrides: [
        myInvitesProvider.overrideWith((ref) async => [
              _inviteWith(id: 'invite-1'),
              _inviteWith(id: 'invite-2', propertyName: 'Fazenda Azul'),
            ]),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildScreen(container));
      await tester.pumpAndSettle();

      expect(find.byType(InviteBanner), findsNWidgets(2));
    });

    testWidgets('with invites: both exit actions remain present',
        (tester) async {
      final container = ProviderContainer(overrides: [
        myInvitesProvider.overrideWith((ref) async => [_inviteWith()]),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildScreen(container));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Criar minha fazenda'),
          findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Sair'), findsOneWidget);
    });

    testWidgets(
        'error loading invites shows ErrorRetry, and tapping retry '
        'invalidates the provider', (tester) async {
      var callCount = 0;
      final container = ProviderContainer(
        // Riverpod 3 auto-retries a failed FutureProvider with exponential
        // backoff by default, masking AsyncError behind AsyncLoading until
        // the retry settles — disable it so the error state is observable
        // deterministically (mirrors sanitary_history_section_test.dart).
        retry: (retryCount, error) => null,
        overrides: [
          myInvitesProvider.overrideWith((ref) async {
            callCount++;
            if (callCount == 1) {
              throw Exception('boom');
            }
            return <MyInvite>[];
          }),
        ],
      );
      addTearDown(container.dispose);
      container.listen(myInvitesProvider, (_, _) {});

      await tester.pumpWidget(_buildScreen(container));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Erro ao carregar. Verifique sua conexão e tente novamente.',
        ),
        findsOneWidget,
      );
      expect(callCount, 1);

      await tester.tap(find.widgetWithText(TextButton, 'Tentar novamente'));
      await tester.pumpAndSettle();

      expect(callCount, 2);
      expect(find.text('Nenhum convite no momento'), findsOneWidget);
    });

    testWidgets('shows a CircularProgressIndicator while invites load',
        (tester) async {
      final gate = Completer<List<MyInvite>>();
      final container = ProviderContainer(overrides: [
        myInvitesProvider.overrideWith((ref) => gate.future),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildScreen(container));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      gate.complete(<MyInvite>[]);
      await tester.pumpAndSettle();
    });

    testWidgets(
        'at 360px, two invites with long farm names render with no '
        'overflow exception', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(overrides: [
        myInvitesProvider.overrideWith((ref) async => [
              _inviteWith(
                id: 'invite-1',
                propertyName: 'Fazenda Muito Extensa Com Um Nome '
                    'Longuíssimo Para Testar Quebra De Linha',
              ),
              _inviteWith(
                id: 'invite-2',
                propertyName: 'Outra Fazenda Com Nome Também Bastante '
                    'Extenso E Difícil De Encaixar',
              ),
            ]),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildScreen(container));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
