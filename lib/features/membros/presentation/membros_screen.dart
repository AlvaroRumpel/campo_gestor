import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/role_gates.dart';
import '../../../core/providers/current_property_provider.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/breakpoints.dart';
import '../../../core/widgets/campo_app_bar.dart';
import '../../../core/widgets/ui.dart';
import '../data/membro_exception.dart';
import '../data/membro_models.dart';
import '../data/membro_repository.dart';
import 'invite_form_dialog.dart';

/// Tela de gestão de membros de uma propriedade (MEMB-02): listar com papel,
/// convidar, revogar convite, trocar papel, remover e sair. Mobile
/// (`ListView` + FAB) e desktop (tabela densa + painel 380px, Task 2) — molde
/// de composição em `gastos_property_screen.dart` (breakpoint) e
/// `propriedades_screen.dart` (diálogos de confirmação destrutiva).
class MembrosScreen extends ConsumerStatefulWidget {
  const MembrosScreen({super.key, required this.propertyId});

  final String propertyId;

  @override
  ConsumerState<MembrosScreen> createState() => _MembrosScreenState();
}

class _MembrosScreenState extends ConsumerState<MembrosScreen> {
  void _invalidateMembers() =>
      ref.invalidate(propertyMembersProvider(widget.propertyId));

  void _invalidateInvites() =>
      ref.invalidate(propertyInvitesProvider(widget.propertyId));

  // Sair/trocar papel também mudam o que `memberPropertiesProvider` retorna
  // (papel do usuário ou a própria lista de fazendas) — é o que o
  // `_RouterRefreshNotifier` do router escuta para reavaliar o redirect.
  void _invalidateMemberships() => ref.invalidate(memberPropertiesProvider);

  String _countLabel(int count) => Intl.plural(
        count,
        one: '1 membro',
        other: '$count membros',
        locale: 'pt_BR',
      );

  void _showError(
    Object error, {
    required String fallback,
    String? propertyName,
  }) {
    if (!mounted) return;
    final ex = asMembroException(
      error,
      fallbackMessage: fallback,
      propertyName: propertyName,
    );
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(ex.message)));
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String body,
    required String confirmLabel,
  }) {
    return showAdaptiveForm<bool>(
      context: context,
      width: FormWidth.confirm,
      builder: (_) =>
          _DangerConfirmDialog(title: title, body: body, confirmLabel: confirmLabel),
    );
  }

  Future<void> _openInvite() async {
    final result = await showAdaptiveForm<bool>(
      context: context,
      builder: (_) => InviteFormDialog(propertyId: widget.propertyId),
    );
    if (result == true) _invalidateInvites();
  }

  Future<void> _confirmRevoke(Invite invite) async {
    final confirmed = await _showConfirmDialog(
      title: 'Revogar convite',
      body:
          'Tem certeza que deseja revogar o convite enviado para ${invite.invitedEmail}?',
      confirmLabel: 'Revogar',
    );
    if (confirmed != true) return;
    try {
      await ref.read(membroRepositoryProvider).revokeInvite(invite.id);
      if (!mounted) return;
      _invalidateInvites();
    } catch (e) {
      _showError(e, fallback: 'Erro ao revogar o convite. Tente novamente.');
    }
  }

  Future<void> _confirmRemove(PropertyMember member, String propertyName) async {
    final confirmed = await _showConfirmDialog(
      title: 'Remover membro',
      body:
          'Tem certeza que deseja remover ${member.email} desta fazenda? '
          'Ele perderá acesso imediatamente.',
      confirmLabel: 'Remover',
    );
    if (confirmed != true) return;
    try {
      await ref.read(membroRepositoryProvider).removeMember(
            propertyId: widget.propertyId,
            userId: member.userId,
          );
      if (!mounted) return;
      _invalidateMembers();
    } catch (e) {
      _showError(
        e,
        fallback: 'Erro ao remover o membro. Tente novamente.',
        propertyName: propertyName,
      );
    }
  }

  Future<void> _confirmLeave(String propertyName) async {
    final confirmed = await _showConfirmDialog(
      title: 'Sair da fazenda',
      body:
          'Tem certeza que deseja sair de $propertyName? '
          'Você perderá acesso imediatamente.',
      confirmLabel: 'Sair',
    );
    if (confirmed != true) return;
    try {
      await ref.read(membroRepositoryProvider).leaveProperty(widget.propertyId);
      if (!mounted) return;
      _invalidateMembers();
      _invalidateMemberships();
    } catch (e) {
      _showError(
        e,
        fallback: 'Erro ao sair da fazenda. Tente novamente.',
        propertyName: propertyName,
      );
    }
  }

  Future<void> _openRoleChange(PropertyMember member) async {
    final newRole = await showAdaptiveForm<String>(
      context: context,
      width: FormWidth.confirm,
      builder: (_) => _RoleChangeSheet(currentRole: member.role),
    );
    if (newRole == null || newRole == member.role || !mounted) return;
    try {
      await ref.read(membroRepositoryProvider).updateMemberRole(
            propertyId: widget.propertyId,
            userId: member.userId,
            newRole: newRole,
          );
      if (!mounted) return;
      _invalidateMembers();
      _invalidateMemberships();
    } catch (e) {
      _showError(e, fallback: 'Erro ao trocar o papel. Tente novamente.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(propertyMembersProvider(widget.propertyId));
    final currentPropAsync = ref.watch(currentPropertyProvider);
    final membershipsAsync = ref.watch(memberPropertiesProvider);
    final canManage = canManageMembers(
      currentPropAsync.asData?.value,
      membershipsAsync.asData?.value,
    );
    final propertyName = membershipsAsync.asData?.value
            .where((m) => m.property.id == widget.propertyId)
            .map((m) => m.property.name)
            .firstOrNull ??
        '';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= Breakpoints.rail;
        return Scaffold(
          appBar: DetailAppBar(
            parentLabel: 'Fazendas',
            onBack: () {
              if (context.canPop()) {
                context.pop();
                return;
              }
              context.go(AppRoutes.dashboard);
            },
            // G-10-03: a tela pode ficar montada enquanto um convite é
            // aceito em outra sessão — os providers são auto-dispose, mas só
            // refazem o fetch ao remontar. Atualizar refaz os três fetches
            // que essa tela e o redirect do router dependem.
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Atualizar',
                onPressed: () {
                  _invalidateMembers();
                  _invalidateInvites();
                  _invalidateMemberships();
                },
              ),
            ],
          ),
          body: membersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, st) => Center(
              child: ErrorRetry(
                message:
                    'Erro ao carregar. Verifique sua conexão e tente novamente.',
                onRetry: _invalidateMembers,
              ),
            ),
            data: (members) => isDesktop
                ? _buildDesktop(members, canManage, propertyName)
                : _buildMobile(members, canManage, propertyName),
          ),
          floatingActionButton: (!isDesktop && canManage)
              ? FloatingActionButton.extended(
                  onPressed: _openInvite,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Convidar'),
                )
              : null,
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // Convites pendentes — compartilhado entre mobile (corpo) e desktop
  // (painel, Task 2). Um único método, nunca duplicado entre layouts.
  // ---------------------------------------------------------------------

  Widget _buildInvitesSection(bool canManage) {
    final invitesAsync = ref.watch(propertyInvitesProvider(widget.propertyId));
    return SectionCard(
      title: 'Convites pendentes',
      child: invitesAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (err, st) => ErrorRetry(
          message: 'Erro ao carregar. Verifique sua conexão e tente novamente.',
          onRetry: _invalidateInvites,
        ),
        data: (invites) {
          if (invites.isEmpty) {
            return const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nenhum convite pendente',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 4),
                Text(
                  'Convide um veterinário, proprietário ou leitor pelo e-mail.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < invites.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _InviteRow(
                  invite: invites[i],
                  canManage: canManage,
                  onRevoke: () => _confirmRevoke(invites[i]),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Mobile (<Breakpoints.rail)
  // ---------------------------------------------------------------------

  Widget _buildMobile(
    List<PropertyMember> members,
    bool canManage,
    String propertyName,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
      children: [
        Text(
          _countLabel(members.length),
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),
        for (final member in members) ...[
          _MemberCard(
            member: member,
            canManage: canManage,
            onChangeRole: () => _openRoleChange(member),
            onRemove: () => _confirmRemove(member, propertyName),
            onLeave: () => _confirmLeave(propertyName),
          ),
          const SizedBox(height: 10),
        ],
        _buildInvitesSection(canManage),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Desktop (>=Breakpoints.rail) — tabela densa + painel 380px ancorado,
  // molde `GastosPropertyScreen._buildDesktop`/`_buildPanel`. Handlers
  // reusados da Task 1, nenhuma lógica duplicada.
  // ---------------------------------------------------------------------

  Widget _buildDesktop(
    List<PropertyMember> members,
    bool canManage,
    String propertyName,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Membros',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                _countLabel(members.length),
                style:
                    const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        Expanded(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ColoredBox(
                    color: AppColors.surface,
                    child: _buildTable(members, canManage, propertyName),
                  ),
                ),
                _buildPanel(canManage),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTable(
    List<PropertyMember> members,
    bool canManage,
    String propertyName,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTableHeader(),
        Expanded(
          child: ListView.builder(
            itemCount: members.length,
            itemBuilder: (context, i) =>
                _buildTableRow(members[i], canManage, propertyName),
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      color: AppColors.surfaceVariant,
      child: const Row(
        children: [
          Expanded(flex: _kFlexNomeEmail, child: _ColumnHeader('Nome/E-mail')),
          SizedBox(width: _kColPapel, child: _ColumnHeader('Papel')),
          SizedBox(width: _kColAcoes, child: _ColumnHeader('Ações')),
        ],
      ),
    );
  }

  Widget _buildTableRow(
    PropertyMember member,
    bool canManage,
    String propertyName,
  ) {
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: _kFlexNomeEmail,
            child: Text(
              member.email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: _kColPapel,
            child: StatusChip(
              roleLabel(member.role),
              kind: member.role == 'veterinarian'
                  ? StatusKind.positive
                  : StatusKind.neutral,
            ),
          ),
          SizedBox(
            width: _kColAcoes,
            child: canManage
                ? PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'role') _openRoleChange(member);
                      if (v == 'remove') _confirmRemove(member, propertyName);
                      if (v == 'leave') _confirmLeave(propertyName);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'role',
                        child: Text('Trocar papel'),
                      ),
                      member.isSelf
                          ? const PopupMenuItem(
                              value: 'leave',
                              child: Text(
                                'Sair da fazenda',
                                style: TextStyle(color: AppColors.danger),
                              ),
                            )
                          : const PopupMenuItem(
                              value: 'remove',
                              child: Text(
                                'Remover membro',
                                style: TextStyle(color: AppColors.danger),
                              ),
                            ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // Painel direito ancorado (380px) — clone de
  // `GastosPropertyScreen._buildPanel`. CTA "Convidar membro" no topo
  // (só quando canManage) + a mesma seção de convites pendentes do mobile.
  Widget _buildPanel(bool canManage) {
    return Container(
      key: const ValueKey('membros-painel'),
      width: 380,
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(left: BorderSide(color: AppColors.divider)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (canManage) ...[
              SectionCard(
                title: 'Convidar membro',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Convide um veterinário, proprietário ou leitor pelo '
                      'e-mail.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _openInvite,
                      icon: const Icon(Icons.person_add_alt_1, size: 18),
                      label: const Text('Convidar membro'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            _buildInvitesSection(canManage),
          ],
        ),
      ),
    );
  }
}

const _kFlexNomeEmail = 3;
const _kColPapel = 140.0;
const _kColAcoes = 56.0;

/// Texto de coluna do cabeçalho desktop — mono 10.5px w700, letterSpacing
/// 0.8, mas SEM `.toUpperCase()`: a 10-UI-SPEC pede "Nome/E-mail"/"Papel"/
/// "Ações" em mixed-case, ao contrário do "DATA"/"CATEGORIA" já-maiúsculo
/// de `sanitario_table_views.dart`/`gastos_property_screen.dart`.
class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: monoStyle(
        size: 10.5,
        weight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AppColors.primaryDarkText,
      ),
    );
  }
}

// ─── Linha de membro (mobile) ───

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.canManage,
    required this.onChangeRole,
    required this.onRemove,
    required this.onLeave,
  });

  final PropertyMember member;
  final bool canManage;
  final VoidCallback onChangeRole;
  final VoidCallback onRemove;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            FarmAvatar(
              name: member.email,
              size: 40,
              background: AppColors.surfaceVariant,
              foreground: AppColors.primaryDarkText,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                member.email,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            StatusChip(
              roleLabel(member.role),
              kind: member.role == 'veterinarian'
                  ? StatusKind.positive
                  : StatusKind.neutral,
            ),
            if (canManage) ...[
              const SizedBox(width: 2),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'role') onChangeRole();
                  if (v == 'remove') onRemove();
                  if (v == 'leave') onLeave();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'role', child: Text('Trocar papel')),
                  member.isSelf
                      ? const PopupMenuItem(
                          value: 'leave',
                          child: Text(
                            'Sair da fazenda',
                            style: TextStyle(color: AppColors.danger),
                          ),
                        )
                      : const PopupMenuItem(
                          value: 'remove',
                          child: Text(
                            'Remover membro',
                            style: TextStyle(color: AppColors.danger),
                          ),
                        ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Linha de convite pendente (mobile + painel desktop) ───

class _InviteRow extends StatelessWidget {
  const _InviteRow({
    required this.invite,
    required this.canManage,
    required this.onRevoke,
  });

  final Invite invite;
  final bool canManage;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    // Duas linhas (não uma só Row): a 360px, e-mail + chip + papel + botão
    // numa única linha estoura — o e-mail ganha a linha inteira para
    // truncar com folga, o resto fica na linha de baixo.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          invite.invitedEmail,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        // Wrap (não Row+Spacer): a 360px, chip + papel + botão podem não
        // caber numa única linha — Wrap nunca estoura, só quebra linha.
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            StatusChip(
              inviteStatusLabel(invite.status),
              kind: StatusKind.warning,
            ),
            Text(
              roleLabel(invite.role),
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            if (canManage)
              TextButton(
                onPressed: onRevoke,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Revogar'),
              ),
          ],
        ),
      ],
    );
  }
}

// ─── Diálogo de confirmação destrutiva genérico — mesmo tratamento visual
// de `_confirmDelete`/`ArchiveConfirmDialog` (icone 38x38 dangerContainer). ───

class _DangerConfirmDialog extends StatelessWidget {
  const _DangerConfirmDialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
  });

  final String title;
  final String body;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.dangerContainer,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    size: 21,
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(body),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  flex: 10,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 14,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: AppColors.onDanger,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Folha "Trocar papel" — três RadioListTile, papel atual pré-selecionado. ───

class _RoleChangeSheet extends StatefulWidget {
  const _RoleChangeSheet({required this.currentRole});

  final String currentRole;

  @override
  State<_RoleChangeSheet> createState() => _RoleChangeSheetState();
}

class _RoleChangeSheetState extends State<_RoleChangeSheet> {
  late String _selected = widget.currentRole;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Trocar papel',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: _selected,
              onChanged: (v) => setState(() => _selected = v ?? _selected),
              child: Column(
                children: [
                  for (final role in const ['veterinarian', 'owner', 'reader'])
                    RadioListTile<String>(
                      value: role,
                      title: Text(roleLabel(role)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 10,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 14,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _selected),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Salvar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
