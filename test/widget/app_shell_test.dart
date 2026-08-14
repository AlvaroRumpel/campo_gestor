import 'package:campo_gestor/core/widgets/app_shell.dart';
import 'package:campo_gestor/core/widgets/property_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

GoRouter _buildTestRouter() => GoRouter(
      initialLocation: '/dashboard',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              AppShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(routes: [GoRoute(path: '/dashboard', builder: (ctx, _) => const Center(child: Text('Dashboard')))]),
            StatefulShellBranch(routes: [GoRoute(path: '/piquetes', builder: (ctx, _) => const Center(child: Text('Piquetes')))]),
            StatefulShellBranch(routes: [GoRoute(path: '/animais', builder: (ctx, _) => const Center(child: Text('Animais')))]),
            StatefulShellBranch(routes: [GoRoute(path: '/reproducao', builder: (ctx, _) => const Center(child: Text('Reprod.')))]),
            StatefulShellBranch(routes: [GoRoute(path: '/sanitario', builder: (ctx, _) => const Center(child: Text('Sanitário')))]),
            StatefulShellBranch(routes: [GoRoute(path: '/gastos', builder: (ctx, _) => const Center(child: Text('Gastos')))]),
          ],
        ),
      ],
    );

Future<void> _pumpAppShell(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(routerConfig: _buildTestRouter()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('AppShell renders NavigationBar at narrow viewport (360x800)', (tester) async {
    await _pumpAppShell(tester, const Size(360, 800));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Campo Gestor'), findsNothing);
    expect(find.text('Sair'), findsNothing);
    // Gastos is a desktop-only destination (redesign 2026-08-13, quick task
    // 260813-x4f) — the bottom nav stays at exactly 5.
    final navigationBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigationBar.destinations.length, 5);
  });

  testWidgets('AppShell renders icon rail (no title, no NavigationBar) at 800x600', (tester) async {
    await _pumpAppShell(tester, const Size(800, 600));
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(PropertySelector), findsOneWidget);
    expect(find.text('Campo Gestor'), findsNothing);
  });

  testWidgets('AppShell renders icon rail (no title, no NavigationBar) at 1024x768', (tester) async {
    await _pumpAppShell(tester, const Size(1024, 768));
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(PropertySelector), findsOneWidget);
    expect(find.text('Campo Gestor'), findsNothing);
  });

  testWidgets('AppShell renders 232px drawer with title and Sair at 1440x900', (tester) async {
    await _pumpAppShell(tester, const Size(1440, 900));
    // Redesign: custom 232px green drawer (logo + farm card + nav + Sair).
    expect(find.text('Campo Gestor'), findsOneWidget);
    expect(find.text('Sair'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(PropertySelector), findsOneWidget);
    expect(find.text('Selecionar fazenda'), findsOneWidget);
    // 6a branch (redesign 2026-08-13, quick task 260813-x4f): Gastos is
    // navegável no drawer, depois de Sanitário.
    expect(find.text('Gastos'), findsOneWidget);
  });
}
