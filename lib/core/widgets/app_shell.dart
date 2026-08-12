import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_repository.dart';
import '../providers/current_property_provider.dart';
import '../theme/app_colors.dart';
import 'property_selector.dart';

/// Shell adaptativo do redesign: bottom nav 68px (<600px) ou rail verde de
/// 232px (>=600px, spec 4.14). O app bar verde é responsabilidade de cada
/// tela (CampoAppBar) — o shell só provê navegação.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  /// Provided by [StatefulShellRoute.indexedStack] in [router.dart].
  final StatefulNavigationShell navigationShell;

  static const double _breakpoint = 600;

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
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _breakpoint;
        return Scaffold(
          body: isWide
              ? Row(
                  children: [
                    _DesktopRail(
                      selectedIndex: navigationShell.currentIndex,
                      onSelect: navigationShell.goBranch,
                      items: _navItems,
                    ),
                    Expanded(child: navigationShell),
                  ],
                )
              : navigationShell,
          bottomNavigationBar: isWide
              ? null
              : NavigationBar(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: navigationShell.goBranch,
                  destinations: _navItems
                      .map(
                        (item) => NavigationDestination(
                          icon: Icon(item.icon),
                          selectedIcon: Icon(item.selectedIcon),
                          label: item.label,
                        ),
                      )
                      .toList(),
                ),
        );
      },
    );
  }
}

/// Rail lateral verde 232px: logo, card da fazenda, nav vertical, Sair.
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
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

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
                      : const Color(0xCCF5F3EB),
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
                          : const Color(0xCCF5F3EB),
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
