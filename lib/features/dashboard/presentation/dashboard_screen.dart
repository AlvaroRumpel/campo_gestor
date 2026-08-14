import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/role_gates.dart';
import '../../../core/providers/current_property_provider.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/property_selector.dart';
import '../../../core/widgets/ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../../membros/data/membro_models.dart';
import '../../membros/data/membro_repository.dart';
import '../../membros/presentation/invite_banner.dart';
import '../../reproducao/data/atf_repository.dart';
import '../../sanitario/data/sanitary_calculations.dart';
import '../data/dashboard_providers.dart';

final NumberFormat _uaPerHaFmt = NumberFormat('0.00', 'pt_BR');

String _fmtUaPerHa(double? v) => v == null ? '—' : _uaPerHaFmt.format(v);

/// Início (spec 4.1 mobile / 4.14 desktop).
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.sizeOf(context).width >= 600;
    return isWide ? const _DesktopDashboard() : const _MobileDashboard();
  }
}

// ───────────────────────── Mobile (<600px) ─────────────────────────

class _MobileDashboard extends ConsumerWidget {
  const _MobileDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts =
        ref.watch(dashboardAlertsProvider).asData?.value ?? const [];
    // Ambos os tipos de alerta (DG pendente, UA acima da capacidade) só se
    // resolvem com uma ação vet-only (salvar DG, mover lote) — o banner
    // inteiro some para os demais papéis, sem filtrar por tipo.
    final isVet = isVeterinarian(
      ref.watch(currentPropertyProvider).asData?.value,
      ref.watch(memberPropertiesProvider).asData?.value,
    );
    // Convite é endereçado à pessoa, não à fazenda ativa — ao contrário do
    // _AlertsBanner (vet-only), aparece para qualquer papel.
    final invites =
        ref.watch(myInvitesProvider).asData?.value ?? const <MyInvite>[];
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const _MobileHeader(),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final invite in invites) ...[
                  InviteBanner(invite: invite),
                  const SizedBox(height: 12),
                ],
                if (isVet && alerts.isNotEmpty) ...[
                  _AlertsBanner(alerts: alerts),
                  const SizedBox(height: 12),
                ],
                const _LotacaoCard(),
                const SizedBox(height: 12),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _PrenhezCard()),
                    SizedBox(width: 10),
                    Expanded(child: _GastosCard()),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Header verde: seletor de fazenda + badge de papel + linha de KPIs.
class _MobileHeader extends ConsumerWidget {
  const _MobileHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpis = ref.watch(dashboardKpisProvider).asData?.value;
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Expanded(child: PropertySelector()),
                _RoleBadge(),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _HeaderKpi(
                    value: kpis == null ? '—' : '${kpis.activeAnimals}',
                    label: 'animais ativos',
                  ),
                ),
                Container(
                  width: 1,
                  height: 38,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  color: const Color(0x33F5F3EB),
                ),
                Expanded(
                  child: _HeaderKpi(
                    value: kpis == null ? '—' : formatUa(kpis.totalUa),
                    label: 'UA no rebanho',
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        kpis == null ? '—' : _fmtUaPerHa(kpis.uaPerHa),
                        overflow: TextOverflow.ellipsis,
                        style: monoStyle(
                          size: 15,
                          weight: FontWeight.w600,
                          color: AppColors.gold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'UA/ha média',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.onGreenSecondary,
                        ),
                      ),
                    ],
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

class _HeaderKpi extends StatelessWidget {
  const _HeaderKpi({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          overflow: TextOverflow.ellipsis,
          style: monoStyle(
            size: 34,
            weight: FontWeight.w600,
            color: AppColors.onGreen,
            height: 1.1,
          ),
        ),
        Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.onGreenSecondary,
          ),
        ),
      ],
    );
  }
}

/// Badge glass do papel do usuário na fazenda ativa ("Veterinário"…).
class _RoleBadge extends ConsumerWidget {
  const _RoleBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentPropertyProvider).asData?.value;
    final members = ref.watch(memberPropertiesProvider).asData?.value;
    final role = members
        ?.where((m) => m.property.id == current?.id)
        .map((m) => m.role)
        .firstOrNull;
    if (role == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.glassPill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        PropertySelector.roleLabel(role),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.onGreen,
        ),
      ),
    );
  }
}

// ───────────────────────── Banner "Precisa de você hoje" ─────────────────────────

class _AlertsBanner extends StatelessWidget {
  const _AlertsBanner({required this.alerts, this.desktop = false});

  final List<DashboardAlert> alerts;
  final bool desktop;

  static const _headerColor = AppColors.accentTextDark;

  @override
  Widget build(BuildContext context) {
    const header = Padding(
      padding: EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          Icon(Icons.pending_actions, size: 20, color: AppColors.accentDark),
          SizedBox(width: 8),
          Text(
            'PRECISA DE VOCÊ HOJE',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: _headerColor,
            ),
          ),
        ],
      ),
    );
    if (desktop) {
      return WarningBanner(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final a in alerts) _AlertCard(alert: a),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return WarningBanner(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          for (var i = 0; i < alerts.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 1, color: Color(0x40E8833A)),
            _AlertRow(alert: alerts[i]),
          ],
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.alert});

  final DashboardAlert alert;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go(alert.route),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Text(
                alert.figure,
                style: monoStyle(size: 20, weight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(alert.text, style: const TextStyle(fontSize: 14.5)),
            ),
            const Icon(Icons.chevron_right,
                size: 20, color: AppColors.accentDark),
          ],
        ),
      ),
    );
  }
}

/// Variante desktop: item como card branco r12 (spec 3.14).
class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});

  final DashboardAlert alert;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => context.go(alert.route),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minWidth: 220),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                alert.figure,
                style: monoStyle(size: 24, weight: FontWeight.w700),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(alert.text, style: const TextStyle(fontSize: 13.5)),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right,
                  size: 20, color: AppColors.accentDark),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Card Lotação por piquete ─────────────────────────

class _LotacaoCard extends ConsumerWidget {
  const _LotacaoCard({this.barHeight = 8});

  final double barHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final occAsync = ref.watch(paddockOccupancyProvider);
    return SectionCard(
      title: 'Lotação por piquete',
      trailing: Text(
        'UA / capacidade',
        style: monoStyle(size: 11, color: AppColors.textSecondary),
      ),
      child: occAsync.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (_, _) => ErrorRetry(
          message: 'Erro ao carregar piquetes.',
          onRetry: () => ref.invalidate(paddockOccupancyProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const Text(
              'Nenhum piquete cadastrado.',
              style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
            );
          }
          return Column(
            children: [
              for (var i = 0; i < list.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _PaddockRow(occupancy: list[i], barHeight: barHeight),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PaddockRow extends StatelessWidget {
  const _PaddockRow({required this.occupancy, required this.barHeight});

  final PaddockOccupancy occupancy;
  final double barHeight;

  @override
  Widget build(BuildContext context) {
    final over = occupancy.overCapacity;
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            occupancy.paddock.name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: CapacityBar(
            current: occupancy.currentUa,
            capacity: occupancy.paddock.uaCapacity,
            height: barHeight,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${formatUa(occupancy.currentUa)} / ${formatUa(occupancy.paddock.uaCapacity)}',
          style: monoStyle(size: 13),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 44,
          child: Text(
            _fmtUaPerHa(occupancy.uaPerHa),
            textAlign: TextAlign.right,
            style: monoStyle(
              size: 12,
              weight: FontWeight.w600,
              color: over ? AppColors.danger : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── Card Prenhez · ATFs ativos ─────────────────────────

class _PrenhezCard extends ConsumerWidget {
  const _PrenhezCard({this.large = false});

  /// Desktop: % em 40/700 e demais ATFs ativos listados após um divisor.
  final bool large;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final atfsAsync = ref.watch(atfListByPropertyProvider);
    return SectionCard(
      title: 'Prenhez · ATFs ativos',
      child: atfsAsync.when(
        loading: () => const SizedBox(
          height: 40,
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (_, _) => ErrorRetry(
          message: 'Erro ao carregar ATFs.',
          onRetry: () => ref.invalidate(atfListByPropertyProvider),
        ),
        data: (all) {
          final actives = all.where((s) => s.atf.active).toList();
          if (actives.isEmpty) {
            return const Text(
              'Nenhum ATF ativo.',
              style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
            );
          }
          final first = actives.first;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PrenhezMain(summary: first, large: large),
              if (large && actives.length > 1) ...[
                const Divider(height: 24),
                for (final s in actives.skip(1)) ...[
                  _PrenhezSecondaryRow(summary: s),
                  const SizedBox(height: 6),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PrenhezMain extends StatelessWidget {
  const _PrenhezMain({required this.summary, required this.large});

  final AtfSummary summary;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final dg = summary.dgSummary;
    final percent = dg.percent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: percent == null ? '—' : '$percent',
                style: monoStyle(
                  size: large ? 40 : 30,
                  weight: FontWeight.w700,
                  color: AppColors.primary,
                  height: 1.1,
                ),
              ),
              if (percent != null)
                TextSpan(
                  text: '%',
                  style: monoStyle(
                    size: 15,
                    weight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          percent == null
              ? 'aguardando DG · ${summary.atf.name}'
              : '${dg.pregnant} de ${dg.total} DGs · ${summary.atf.name}',
          style: const TextStyle(
            fontSize: 12.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: dg.total > 0 ? dg.pregnant / dg.total : 0.0,
            minHeight: 6,
            color: AppColors.primary,
            backgroundColor: AppColors.track,
          ),
        ),
      ],
    );
  }
}

class _PrenhezSecondaryRow extends StatelessWidget {
  const _PrenhezSecondaryRow({required this.summary});

  final AtfSummary summary;

  @override
  Widget build(BuildContext context) {
    final dg = summary.dgSummary;
    final percent = dg.percent;
    return Row(
      children: [
        Text(
          percent == null ? '—' : '$percent%',
          style: monoStyle(
            size: 15,
            weight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            percent == null
                ? '${summary.atf.name} · aguardando DG'
                : '${summary.atf.name} · ${dg.pregnant} de ${dg.total} DGs',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── Card Gastos · <mês> ─────────────────────────

class _GastosCard extends ConsumerWidget {
  const _GastosCard({this.large = false});

  final bool large;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthAsync = ref.watch(monthExpensesProvider);
    final monthName = DateFormat('MMMM', 'pt_BR').format(DateTime.now());
    return SectionCard(
      title: 'Gastos · $monthName',
      onTap: () => context.go(AppRoutes.gastos),
      trailing: const Icon(Icons.chevron_right,
          size: 20, color: AppColors.textSecondary),
      child: monthAsync.when(
        loading: () => const SizedBox(
          height: 40,
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (_, _) => ErrorRetry(
          message: 'Erro ao carregar gastos.',
          onRetry: () => ref.invalidate(monthExpensesProvider),
        ),
        data: (month) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formatCurrencyBrl(month.total),
              style: monoStyle(
                size: large ? 28 : 22,
                weight: FontWeight.w700,
                height: 1.1,
              ),
            ),
            if (month.perAnimal != null) ...[
              const SizedBox(height: 4),
              Text(
                '${formatCurrencyBrl(month.perAnimal!)} por animal',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Desktop (≥600px) ─────────────────────────

class _DesktopDashboard extends ConsumerWidget {
  const _DesktopDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts =
        ref.watch(dashboardAlertsProvider).asData?.value ?? const [];
    // Ambos os tipos de alerta (DG pendente, UA acima da capacidade) só se
    // resolvem com uma ação vet-only (salvar DG, mover lote) — o banner
    // inteiro some para os demais papéis, sem filtrar por tipo.
    final isVet = isVeterinarian(
      ref.watch(currentPropertyProvider).asData?.value,
      ref.watch(memberPropertiesProvider).asData?.value,
    );
    // Convite é endereçado à pessoa, não à fazenda ativa — ao contrário do
    // _AlertsBanner (vet-only), aparece para qualquer papel.
    final invites =
        ref.watch(myInvitesProvider).asData?.value ?? const <MyInvite>[];
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
        children: [
          const _DesktopHeader(),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 125,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final invite in invites) ...[
                      InviteBanner(invite: invite),
                      const SizedBox(height: 16),
                    ],
                    if (isVet && alerts.isNotEmpty) ...[
                      _AlertsBanner(alerts: alerts, desktop: true),
                      const SizedBox(height: 16),
                    ],
                    const _LotacaoCard(barHeight: 10),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                flex: 75,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PrenhezCard(large: true),
                    SizedBox(height: 16),
                    _GastosCard(large: true),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DesktopHeader extends ConsumerWidget {
  const _DesktopHeader();

  static String _greeting(DateTime now) {
    if (now.hour < 12) return 'Bom dia';
    if (now.hour < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  static String? _firstName(String? email) {
    final local = email?.split('@').firstOrNull;
    if (local == null || local.isEmpty) return null;
    return local[0].toUpperCase() + local.substring(1);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final property = ref.watch(currentPropertyProvider).asData?.value;
    final email = ref
        .watch(authNotifierProvider)
        .asData
        ?.value
        ?.session
        ?.user
        .email;
    final kpis = ref.watch(dashboardKpisProvider).asData?.value;

    final name = _firstName(email);
    final greeting =
        name == null ? _greeting(now) : '${_greeting(now)}, $name';
    final longDate =
        DateFormat("EEEE, d 'de' MMMM 'de' y", 'pt_BR').format(now);
    final subtitle =
        property == null ? longDate : '${property.name} · $longDate';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style:
                    const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        _DesktopKpi(
          value: kpis == null ? '—' : '${kpis.activeAnimals}',
          label: 'animais ativos',
        ),
        const SizedBox(width: 24),
        _DesktopKpi(
          value: kpis == null ? '—' : formatUa(kpis.totalUa),
          label: 'UA no rebanho',
        ),
        const SizedBox(width: 24),
        _DesktopKpi(
          value: kpis == null ? '—' : _fmtUaPerHa(kpis.uaPerHa),
          label: 'UA/ha média',
        ),
      ],
    );
  }
}

class _DesktopKpi extends StatelessWidget {
  const _DesktopKpi({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(value, style: monoStyle(size: 22, weight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
