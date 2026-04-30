import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'property_selector.dart';

/// Adaptive shell widget rendering NavigationRail (>=600px) or NavigationBar
/// (<600px) per Material 3 guidance. Per D-01 (sidebar fixo no web), D-03
/// (bottom nav mobile), D-02 (5 destinations: Dashboard, Piquetes, Animais,
/// Reproducao, Sanitario), D-04 (header com PropertySelector).
///
/// Breakpoint 600px is the Material 3 standard
/// (m3.material.io/foundations/layout/applying-layout).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  /// Provided by [StatefulShellRoute.indexedStack] in [router.dart].
  final StatefulNavigationShell navigationShell;

  static const double _breakpoint = 600;

  static const List<_NavItem> _navItems = [
    _NavItem(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: 'Dashboard',
    ),
    _NavItem(
      icon: Icons.grass_outlined,
      selectedIcon: Icons.grass,
      label: 'Piquetes',
    ),
    _NavItem(
      icon: Icons.pets_outlined,
      selectedIcon: Icons.pets,
      label: 'Animais',
    ),
    _NavItem(
      icon: Icons.favorite_outline,
      selectedIcon: Icons.favorite,
      label: 'Reprod.',
    ),
    _NavItem(
      icon: Icons.medical_services_outlined,
      selectedIcon: Icons.medical_services,
      label: 'Sanitario',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _breakpoint;
        return Scaffold(
          appBar: AppBar(
            title: const PropertySelector(),
          ),
          body: isWide
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: navigationShell.currentIndex,
                      onDestinationSelected: navigationShell.goBranch,
                      labelType: NavigationRailLabelType.all,
                      destinations: _navItems
                          .map(
                            (item) => NavigationRailDestination(
                              icon: Icon(item.icon),
                              selectedIcon: Icon(item.selectedIcon),
                              label: Text(item.label),
                            ),
                          )
                          .toList(),
                    ),
                    const VerticalDivider(thickness: 1, width: 1),
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

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
