/// Path constants for top-level routes.
///
/// Phase 0 added the 5 shell branches (dashboard..sanitario).
/// Phase 1 adds the auth routes (login, signup, reset-password, sem-acesso).
///
/// Shell screen convention (WR-03):
/// Every screen rendered inside the AppShell MUST handle the case where
/// [currentPropertyProvider] is still loading or has no value. Use `.when()`
/// or an explicit `.isLoading` check — never call `.requireValue` without
/// first checking `.hasValue`. The router redirect holds navigation until
/// [currentPropertyProvider] resolves, but widget rebuilds can still receive
/// an intermediate state.
abstract final class AppRoutes {
  // Auth (Phase 1) — outside the AppShell
  static const login = '/login';
  static const signup = '/signup';
  static const resetPassword = '/reset-password';
  static const noAccess = '/sem-acesso';

  // App shell branches (Phase 0)
  static const dashboard = '/dashboard';
  static const piquetes = '/piquetes';
  static const animais = '/animais';
  static const reproducao = '/reproducao';
  static const sanitario = '/sanitario';

  /// Top-level shell branches only — used by tests that count navigation items.
  static const all = <String>[
    dashboard,
    piquetes,
    animais,
    reproducao,
    sanitario,
  ];

  /// All auth routes — used by router redirect to detect "is on auth route".
  static const authRoutes = <String>[
    login,
    signup,
    resetPassword,
    noAccess,
  ];
}
