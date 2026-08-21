import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/animais/data/animal_repository.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/reproducao/data/iatf_repository.dart';
import '../providers/current_property_provider.dart';
import '../theme/app_colors.dart';
import '../theme/breakpoints.dart';
import 'property_selector.dart';

/// Shell adaptativo do redesign: bottom nav 68px (<600px), rail de ícones
/// 76px (600–1439px) ou drawer verde de 232px (>=1440px, spec 4.14). O app
/// bar verde é responsabilidade de cada tela (CampoAppBar) — o shell só
/// provê navegação.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  /// Provided by [StatefulShellRoute.indexedStack] in [router.dart].
  final StatefulNavigationShell navigationShell;

  static const List<_NavItem> _navItems = [
    _NavItem(icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Início'),
    _NavItem(
        icon: Icons.grass_outlined,
        selectedIcon: Icons.grass,
        label: 'Piquetes',
        railLabel: 'Piquetes e lotes'),
    _NavItem(icon: Icons.pets_outlined, selectedIcon: Icons.pets, label: 'Animais'),
    _NavItem(
        icon: Icons.favorite_outline,
        selectedIcon: Icons.favorite,
        label: 'Reprodução'),
    _NavItem(
        icon: Icons.medical_services_outlined,
        selectedIcon: Icons.medical_services,
        label: 'Sanitário'),
    _NavItem(
        icon: Icons.payments_outlined,
        selectedIcon: Icons.payments,
        label: 'Gastos'),
    _NavItem(
        icon: Icons.grid_on_outlined,
        selectedIcon: Icons.grid_on,
        label: 'Planilhas'),
  ];

  /// Only the bottom nav (<600px) stays at 5 destinations — Gastos is a
  /// desktop-only (rail/drawer) destination (redesign 2026-08-13, quick task
  /// 260813-x4f). The rail and the 232px drawer below iterate `_navItems`
  /// whole and pick it up with no other change.
  static const int _mobileNavCount = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (width < Breakpoints.mobile) {
          // The bottom nav only offers the first 5 items (Gastos is
          // desktop-only, reachable below 600px only via deep link or the
          // dashboard card). When the active branch is /gastos (index 5),
          // no tab represents the current screen — NavigationBar still
          // needs a legal selectedIndex (it asserts on an out-of-range
          // value), so index 0 is used as the required-but-not-visible
          // value: its selected icon and indicator pill are suppressed so
          // it doesn't read as "Início" being selected.
          final outOfNav = navigationShell.currentIndex >= _mobileNavCount;
          final navigationBar = NavigationBar(
            selectedIndex: outOfNav ? 0 : navigationShell.currentIndex,
            onDestinationSelected: navigationShell.goBranch,
            destinations: _navItems
                .take(_mobileNavCount)
                .map(
                  (item) => NavigationDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(outOfNav ? item.icon : item.selectedIcon),
                    label: item.label,
                  ),
                )
                .toList(),
          );
          return Scaffold(
            body: navigationShell,
            bottomNavigationBar: outOfNav
                ? NavigationBarTheme(
                    data: const NavigationBarThemeData(
                      indicatorColor: Colors.transparent,
                    ),
                    child: navigationBar,
                  )
                : navigationBar,
          );
        }

        final rail = width < Breakpoints.drawer
            ? _IconRail(
                selectedIndex: navigationShell.currentIndex,
                onSelect: navigationShell.goBranch,
                items: _navItems,
              )
            : _DesktopRail(
                selectedIndex: navigationShell.currentIndex,
                onSelect: navigationShell.goBranch,
                items: _navItems,
              );

        return Scaffold(
          body: Row(
            children: [rail, Expanded(child: navigationShell)],
          ),
        );
      },
    );
  }
}

/// Rail de ícones (600–1439px): logo, avatar da fazenda, nav vertical
/// compacta com labels curtos, Sair. 76px de largura fixa.
class _IconRail extends ConsumerWidget {
  const _IconRail({
    required this.selectedIndex,
    required this.onSelect,
    required this.items,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final List<_NavItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeIatfCount = ref
            .watch(iatfListByPropertyProvider)
            .asData
            ?.value
            .where((s) => s.iatf.active)
            .length ??
        0;

    return Container(
      width: 76,
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.grass, size: 20, color: AppColors.onAccent),
          ),
          const SizedBox(height: 14),
          const PropertySelector(compact: true),
          const SizedBox(height: 18),
          // Expanded + scroll instead of a fixed Column + Spacer: the 6th
          // item (Gastos, redesign 2026-08-13) overflows a short viewport
          // (e.g. 800x600) when every item is laid out at full fixed height
          // — this keeps "Sair" pinned at the bottom when there's room and
          // scrolls the nav items instead of overflowing when there isn't.
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++)
                    _IconRailItem(
                      item: items[i],
                      selected: i == selectedIndex,
                      onTap: () => onSelect(i),
                      badgeCount:
                          items[i].label == 'Reprodução' && activeIatfCount > 0
                              ? activeIatfCount
                              : null,
                    ),
                ],
              ),
            ),
          ),
          _IconRailItem(
            item: const _NavItem(
                icon: Icons.logout, selectedIcon: Icons.logout, label: 'Sair'),
            selected: false,
            onTap: () async {
              await ref.read(currentPropertyProvider.notifier).clear();
              await ref.read(authRepositoryProvider).signOut();
            },
          ),
        ],
      ),
    );
  }
}

class _IconRailItem extends StatelessWidget {
  const _IconRailItem({
    required this.item,
    required this.selected,
    required this.onTap,
    this.badgeCount,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? AppColors.glassStrong : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 60,
            constraints: const BoxConstraints(minHeight: 54),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      selected ? item.selectedIcon : item.icon,
                      size: 23,
                      color: selected ? AppColors.onGreen : AppColors.onGreenMuted,
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        item.label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400,
                          color: selected
                              ? AppColors.onGreen
                              : AppColors.onGreenMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                if (badgeCount != null)
                  Positioned(
                    top: -2,
                    right: 2,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$badgeCount',
                        style: monoStyle(
                            size: 10,
                            weight: FontWeight.w700,
                            color: AppColors.onAccent),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Drawer fixo verde 232px (>=1440px): logo, card da fazenda, nav vertical
/// com labels completos e badges de contagem, Sair.
class _DesktopRail extends ConsumerWidget {
  const _DesktopRail({
    required this.selectedIndex,
    required this.onSelect,
    required this.items,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final List<_NavItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ponytail: animalListByPropertyProvider é observado só aqui (não pelo
    // rail de ícones nem pelo mobile), para essas faixas não pagarem esse
    // fetch. Trocar por um provider dedicado de contagem se o custo da lista
    // completa aparecer.
    final animalCount =
        ref.watch(animalListByPropertyProvider).asData?.value.length;
    final activeIatfCount = ref
        .watch(iatfListByPropertyProvider)
        .asData
        ?.value
        .where((s) => s.iatf.active)
        .length;

    return Container(
      width: 232,
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.grass,
                    size: 20, color: AppColors.onAccent),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Campo Gestor',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Card da fazenda ativa (mesmo seletor do app bar mobile)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.glassCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const PropertySelector(),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < items.length; i++)
            _RailItem(
              item: items[i],
              selected: i == selectedIndex,
              onTap: () => onSelect(i),
              trailing: _badgeFor(items[i].label, animalCount, activeIatfCount),
            ),
          const Spacer(),
          _RailItem(
            item: const _NavItem(
                icon: Icons.logout, selectedIcon: Icons.logout, label: 'Sair'),
            selected: false,
            onTap: () async {
              await ref.read(currentPropertyProvider.notifier).clear();
              await ref.read(authRepositoryProvider).signOut();
            },
          ),
        ],
      ),
    );
  }

  Widget? _badgeFor(String label, int? animalCount, int? activeIatfCount) {
    if (label == 'Animais' && animalCount != null && animalCount > 0) {
      return Text(
        '$animalCount',
        style: monoStyle(size: 12.5, color: AppColors.onGreenMuted),
      );
    }
    if (label == 'Reprodução' && activeIatfCount != null && activeIatfCount > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$activeIatfCount',
          style: monoStyle(
              size: 11, weight: FontWeight.w700, color: AppColors.onAccent),
        ),
      );
    }
    return null;
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.item,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? AppColors.glassStrong : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: 21,
                  color: selected
                      ? AppColors.onGreen
                      : AppColors.onGreenMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.railLabel ?? item.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected
                          ? AppColors.onGreen
                          : AppColors.onGreenMuted,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.railLabel,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String? railLabel;
}
