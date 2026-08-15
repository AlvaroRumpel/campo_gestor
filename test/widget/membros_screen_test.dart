// Phase 10 Plan 5 — MembrosScreen: lista de membros, ações de gestão e
// convites pendentes. Molde de fake repo de
// `test/features/membros/invite_banner_test.dart`; molde de harness/router
// de `test/widget/gastos_property_screen_test.dart`.
import 'package:campo_gestor/core/providers/current_property_provider.dart';
import 'package:campo_gestor/core/router/routes.dart';
import 'package:campo_gestor/core/services/supabase_service.dart';
import 'package:campo_gestor/core/widgets/ui.dart';
import 'package:campo_gestor/features/auth/data/property_repository.dart';
import 'package:campo_gestor/features/membros/data/membro_models.dart';
import 'package:campo_gestor/features/membros/data/membro_repository.dart';
import 'package:campo_gestor/features/membros/presentation/membros_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

// SupabaseService() is safe to construct here — its client getter is never
// invoked because every method exercised by these tests is overridden below
// (same pattern as _FakeMembroRepository in invite_banner_test.dart).
class _FakeMembroRepository extends MembroRepository {
  _FakeMembroRepository({this.removeError, this.revokeError})
      : super(SupabaseService());

  final Object? removeError;
  final Object? revokeError;

  int removeCallCount = 0;
  int revokeCallCount = 0;
  int leaveCallCount = 0;
  int updateRoleCallCount = 0;

  @override
  Future<void> removeMember({
    required String propertyId,
    required String userId,
  }) async {
    removeCallCount++;
    if (removeError != null) throw removeError!;
  }

  @override
  Future<void> revokeInvite(String inviteId) async {
    revokeCallCount++;
    if (revokeError != null) throw revokeError!;
  }

  @override
  Future<void> leaveProperty(String propertyId) async {
    leaveCallCount++;
  }

  @override
  Future<void> updateMemberRole({
    required String propertyId,
    required String userId,
    required String newRole,
  }) async {
    updateRoleCallCount++;
  }
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _prop = SelectedProperty(id: 'prop-1', name: 'Fazenda Alpha');
const _vetMembership =
    PropertyMembership(property: _prop, role: 'veterinarian');
const _readerMembership = PropertyMembership(property: _prop, role: 'reader');

final _self = PropertyMember(
  userId: 'user-1',
  email: 'vet@example.com',
  role: 'veterinarian',
  createdAt: DateTime(2026, 1, 1),
  isSelf: true,
);

final _owner = PropertyMember(
  userId: 'user-2',
  email: 'owner@example.com',
  role: 'owner',
  createdAt: DateTime(2026, 1, 1),
  isSelf: false,
);

final _reader = PropertyMember(
  userId: 'user-3',
  email: 'reader@example.com',
  role: 'reader',
  createdAt: DateTime(2026, 1, 1),
  isSelf: false,
);

final _pendingInvite = Invite(
  id: 'invite-1',
  propertyId: 'prop-1',
  invitedEmail: 'novo@example.com',
  role: 'reader',
  status: 'pending',
  invitedBy: 'user-1',
  createdAt: DateTime(2026, 1, 1),
);

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

GoRouter _buildRouter() => GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const MembrosScreen(propertyId: 'prop-1'),
        ),
        GoRoute(
          path: AppRoutes.dashboard,
          builder: (context, state) =>
              const Scaffold(body: Text('dashboard')),
        ),
      ],
    );

Widget _buildScreen({
  required MembroRepository repo,
  required List<PropertyMember> members,
  required List<Invite> invites,
  required List<PropertyMembership> memberships,
}) {
  return ProviderScope(
    retry: (retryCount, error) => null,
    overrides: [
      membroRepositoryProvider.overrideWithValue(repo),
      propertyMembersProvider('prop-1').overrideWith((ref) async => members),
      propertyInvitesProvider('prop-1').overrideWith((ref) async => invites),
      memberPropertiesProvider.overrideWith((ref) async => memberships),
    ],
    child: MaterialApp.router(routerConfig: _buildRouter()),
  );
}

Future<void> _pump(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('MembrosScreen (Phase 10 Plan 5, MEMB-01/02/03)', () {
    testWidgets('reader role: no management controls, no FAB', (tester) async {
      await _pump(
        tester,
        _buildScreen(
          repo: _FakeMembroRepository(),
          members: [_owner, _reader],
          invites: [],
          memberships: const [_readerMembership],
        ),
      );

      expect(find.textContaining('Convidar'), findsNothing);
      expect(find.text('Trocar papel'), findsNothing);
      expect(find.text('Remover membro'), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets(
        'vet role: renders FAB Convidar and a PopupMenuButton per row',
        (tester) async {
      await _pump(
        tester,
        _buildScreen(
          repo: _FakeMembroRepository(),
          members: [_self, _owner],
          invites: [],
          memberships: const [_vetMembership],
        ),
      );

      expect(
        find.widgetWithText(FloatingActionButton, 'Convidar'),
        findsOneWidget,
      );
      expect(find.byType(PopupMenuButton<String>), findsNWidgets(2));
    });

    testWidgets('self row offers Sair da fazenda, not Remover membro',
        (tester) async {
      await _pump(
        tester,
        _buildScreen(
          repo: _FakeMembroRepository(),
          members: [_self, _owner],
          invites: [],
          memberships: const [_vetMembership],
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();

      expect(find.text('Sair da fazenda'), findsOneWidget);
      expect(find.text('Remover membro'), findsNothing);
    });

    testWidgets('count label: singular for 1 member', (tester) async {
      await _pump(
        tester,
        _buildScreen(
          repo: _FakeMembroRepository(),
          members: [_self],
          invites: [],
          memberships: const [_vetMembership],
        ),
      );

      expect(find.text('1 membro'), findsOneWidget);
    });

    testWidgets('count label: plural for 3 members', (tester) async {
      await _pump(
        tester,
        _buildScreen(
          repo: _FakeMembroRepository(),
          members: [_self, _owner, _reader],
          invites: [],
          memberships: const [_vetMembership],
        ),
      );

      expect(find.text('3 membros'), findsOneWidget);
    });

    testWidgets(
        'empty invites: inline "Nenhum convite pendente", no second EmptyState',
        (tester) async {
      await _pump(
        tester,
        _buildScreen(
          repo: _FakeMembroRepository(),
          members: [_self],
          invites: [],
          memberships: const [_vetMembership],
        ),
      );

      expect(find.text('Nenhum convite pendente'), findsOneWidget);
      expect(find.byType(EmptyState), findsNothing);
    });

    testWidgets('pending invite shows email, Pendente chip, and Revogar',
        (tester) async {
      await _pump(
        tester,
        _buildScreen(
          repo: _FakeMembroRepository(),
          members: [_self],
          invites: [_pendingInvite],
          memberships: const [_vetMembership],
        ),
      );

      expect(find.text('novo@example.com'), findsOneWidget);
      expect(find.widgetWithText(StatusChip, 'Pendente'), findsOneWidget);
      expect(find.text('Revogar'), findsOneWidget);
    });

    testWidgets(
        'revoke failing with P0002 shows the generic stale-state SnackBar',
        (tester) async {
      final repo = _FakeMembroRepository(
        revokeError: const PostgrestException(message: 'stale', code: 'P0002'),
      );
      await _pump(
        tester,
        _buildScreen(
          repo: repo,
          members: [_self],
          invites: [_pendingInvite],
          memberships: const [_vetMembership],
        ),
      );

      await tester.tap(find.text('Revogar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Revogar'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Não foi possível concluir. Atualize a lista e tente novamente.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'remove failing with 23514 shows the guard SnackBar with the farm '
        'name and "responsável"', (tester) async {
      final repo = _FakeMembroRepository(
        removeError: const PostgrestException(message: 'guard', code: '23514'),
      );
      await _pump(
        tester,
        _buildScreen(
          repo: repo,
          members: [_self, _owner],
          invites: [],
          memberships: const [_vetMembership],
        ),
      );

      // Owner's row (index 1) — not self, so it offers "Remover membro".
      await tester.tap(find.byType(PopupMenuButton<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remover membro'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remover'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Fazenda Alpha'), findsOneWidget);
      expect(find.textContaining('responsável'), findsOneWidget);
    });

    testWidgets('360px width renders with no overflow exception',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(360, 800));
      await _pump(
        tester,
        _buildScreen(
          repo: _FakeMembroRepository(),
          members: [_self, _owner, _reader],
          invites: [_pendingInvite],
          memberships: const [_vetMembership],
        ),
      );

      expect(tester.takeException(), isNull);
    });

    // -------------------------------------------------------------------
    // Task 2 — layout desktop mestre-detalhe
    // -------------------------------------------------------------------

    testWidgets(
        '1280x900: painel de 380px com borda à esquerda e tabela (não '
        'ListView de Cards)', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      await _pump(
        tester,
        _buildScreen(
          repo: _FakeMembroRepository(),
          members: [_self, _owner],
          invites: [],
          memberships: const [_vetMembership],
        ),
      );

      expect(
        tester.getSize(find.byKey(const ValueKey('membros-painel'))).width,
        380,
      );
      // FarmAvatar só aparece no _MemberCard mobile — sua ausência prova
      // que a listagem principal virou tabela, não ListView de Cards.
      expect(find.byType(FarmAvatar), findsNothing);
    });

    testWidgets('1280x900: cabeçalhos de coluna Nome/E-mail, Papel e Ações',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      await _pump(
        tester,
        _buildScreen(
          repo: _FakeMembroRepository(),
          members: [_self, _owner],
          invites: [],
          memberships: const [_vetMembership],
        ),
      );

      expect(find.text('Nome/E-mail'), findsOneWidget);
      expect(find.text('Papel'), findsOneWidget);
      expect(find.text('Ações'), findsOneWidget);
    });

    testWidgets(
        '1280x900: painel mostra "Convidar membro" quando canManageMembers '
        'é verdadeiro', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      await _pump(
        tester,
        _buildScreen(
          repo: _FakeMembroRepository(),
          members: [_self, _owner],
          invites: [],
          memberships: const [_vetMembership],
        ),
      );

      expect(find.widgetWithText(FilledButton, 'Convidar membro'), findsOneWidget);
    });

    testWidgets('1280x900: papel reader não mostra "Convidar membro" no painel',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      await _pump(
        tester,
        _buildScreen(
          repo: _FakeMembroRepository(),
          members: [_owner, _reader],
          invites: [],
          memberships: const [_readerMembership],
        ),
      );

      expect(find.text('Convidar membro'), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets(
        '1280x900: SectionCard "Convites pendentes" vive dentro do painel '
        '(único método, compartilhado com o mobile)', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      await _pump(
        tester,
        _buildScreen(
          repo: _FakeMembroRepository(),
          members: [_self],
          invites: [_pendingInvite],
          memberships: const [_vetMembership],
        ),
      );

      final panel = find.byKey(const ValueKey('membros-painel'));
      expect(
        find.descendant(of: panel, matching: find.text('novo@example.com')),
        findsOneWidget,
      );
    });

    testWidgets(
        '1280x900: e-mail muito longo na tabela não gera overflow, e não '
        'há FloatingActionButton', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      final longEmailMember = PropertyMember(
        userId: 'user-9',
        email: 'um.endereco.de.email.extremamente.longo.para.testar.a.'
            'quebra@dominio-muito-extenso-de-teste.com.br',
        role: 'reader',
        createdAt: DateTime(2026, 1, 1),
        isSelf: false,
      );
      await _pump(
        tester,
        _buildScreen(
          repo: _FakeMembroRepository(),
          members: [_self, longEmailMember],
          invites: [],
          memberships: const [_vetMembership],
        ),
      );

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'G-10-03: tapping the Atualizar action refetches propertyMembersProvider',
        (tester) async {
      var fetchCount = 0;
      await _pump(
        tester,
        ProviderScope(
          retry: (retryCount, error) => null,
          overrides: [
            membroRepositoryProvider.overrideWithValue(_FakeMembroRepository()),
            propertyMembersProvider('prop-1').overrideWith((ref) async {
              fetchCount++;
              return [_self];
            }),
            propertyInvitesProvider('prop-1').overrideWith((ref) async => []),
            memberPropertiesProvider.overrideWith(
              (ref) async => const [_vetMembership],
            ),
          ],
          child: MaterialApp.router(routerConfig: _buildRouter()),
        ),
      );

      expect(fetchCount, 1);

      await tester.tap(find.widgetWithIcon(IconButton, Icons.refresh));
      await tester.pumpAndSettle();

      expect(fetchCount, 2);
      expect(find.text('vet@example.com'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
