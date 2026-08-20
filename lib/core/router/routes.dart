/// Path constants for top-level routes.
///
/// Phase 0 added the 5 shell branches (dashboard..sanitario).
/// Phase 1 adds the auth routes (login, signup, reset-password, sem-acesso).
/// Phase 2 adds /propriedades (property management, root-level outside shell).
/// Phase 7 adds /gastos/:paddockId (expenses by paddock, root-level outside shell).
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

  // Management (Phase 2) — outside the AppShell
  static const propriedades = '/propriedades';

  // Phase 3 detail routes — root-level (outside shell, D-03)
  static const lotes = '/lotes';
  static const loteById = '/lotes/:loteId'; // template — used by GoRoute path
  static const animalById = ':id'; // relative — sub-route under /animais shell branch

  static String loteDetail(String id) => '/lotes/$id';
  static String animalDetail(String id) => '/animais/$id';

  // Phase 5 detail route — root-level (outside shell, D-02): reproductive-
  // history rows on the animal ficha (D-14) link straight to an ATF.
  static const atfById = '/atf/:atfId'; // template — used by GoRoute path
  static String atfDetail(String id) => '/atf/$id';

  // Phase 6 detail route — root-level (outside shell, D-19): reachable from
  // three list origins (global aplicações list, lote history section, animal
  // ficha), so it cannot live inside any single shell branch.
  static const aplicacaoById = '/aplicacoes/:id'; // template — used by GoRoute path
  static String aplicacaoDetail(String id) => '/aplicacoes/$id';

  // Phase 7 detail route — root-level (outside shell, D-08): the expense
  // list needs deep-link + back-button context of its own paddock, and is
  // the fourth use of this pattern after loteById, atfById and
  // aplicacaoById. Coexists with `gastos` below (a two-segment root-level
  // route always wins its own match ahead of the shell).
  //
  // Redesign 2026-08-13: the "no 6a branch" call this comment used to
  // record was explicitly reverted by the user (quick task 260813-x4f).
  // `/gastos` is now the 6a shell branch with the property-wide
  // consolidated view (`GastosPropertyScreen`); `/gastos/:paddockId` stays
  // root-level as the deep-link target from a single paddock. The mobile
  // bottom nav still ships only 5 destinations — Gastos is a desktop-only
  // (rail/drawer) destination, never in the <600px NavigationBar.
  static const gastosById = '/gastos/:paddockId'; // template — used by GoRoute path
  static String gastosPorPiquete(String id) => '/gastos/$id';

  // Phase 10 detail route — root-level (outside shell, MEMB-02): the fifth
  // use of this pattern after loteById, atfById, aplicacaoById and
  // gastosById. `MembrosScreen` (10-05) is reachable from the property
  // card's context menu, not from a shell branch, so it follows the same
  // root-level convention as the others.
  static const membrosById = '/propriedades/:propertyId/membros'; // template — used by GoRoute path
  static String membros(String id) => '/propriedades/$id/membros';

  // Planilhas (feature import/export/grade) — root-level, fora do shell.
  static const importar = '/planilhas/importar/:entity'; // template
  static String importarFor(String entity, {String? atfId}) =>
      '/planilhas/importar/$entity${atfId == null ? '' : '?atf=$atfId'}';
  static const sanitarioGrade = '/sanitario/grade';

  // App shell branches (Phase 0)
  static const dashboard = '/dashboard';
  static const piquetes = '/piquetes';
  static const animais = '/animais';
  static const reproducao = '/reproducao';
  static const sanitario = '/sanitario';
  static const gastos = '/gastos';

  /// Top-level shell branches only — used by tests that count navigation items.
  static const all = <String>[
    dashboard,
    piquetes,
    animais,
    reproducao,
    sanitario,
    gastos,
  ];

  /// All auth routes — used by router redirect to detect "is on auth route".
  /// noAccess is intentionally excluded: after signOut from /sem-acesso the
  /// redirect must still land on /login (not stay put).
  static const authRoutes = <String>[
    login,
    signup,
    resetPassword,
  ];
}
