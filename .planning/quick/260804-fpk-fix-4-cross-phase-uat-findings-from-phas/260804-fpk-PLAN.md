---
phase: quick
plan: 260804-fpk
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/features/auth/presentation/signup_screen.dart
  - lib/features/auth/data/auth_repository.dart
  - lib/features/lotes/presentation/lote_form_dialog.dart
  - lib/features/lotes/presentation/lote_detail_screen.dart
  - test/features/auth/auth_repository_test.dart
  - test/features/auth/signup_screen_test.dart
  - test/widget/lote_form_dialog_test.dart
  - test/widget/lote_detail_screen_test.dart
autonomous: true
requirements: [F-04-01, F-04-02, F-04-03, F-04-04]

must_haves:
  truths:
    - "After a successful signup the user lands on /login with a SnackBar telling them to confirm their email"
    - "The Supabase confirmation email links back to the deployed origin, not localhost"
    - "A quantity in the lot-creation dialog can be typed directly; the +/- buttons still work and stay in sync with the typed value"
    - "The lot detail screen always offers a way out — pop when there is history, otherwise navigate to the lot's paddock"
    - "The full existing test suite still passes and the fixes are live on campo-gestor.pages.dev"
  artifacts:
    - lib/features/auth/presentation/signup_screen.dart
    - lib/features/auth/data/auth_repository.dart
    - lib/features/lotes/presentation/lote_form_dialog.dart
    - lib/features/lotes/presentation/lote_detail_screen.dart
    - test/features/auth/signup_screen_test.dart
  key_links:
    - "AuthRepository.signUp -> AppConfig.appOrigin (build-time --dart-define APP_ORIGIN) -> Supabase emailRedirectTo"
    - "_CategoryCompositionRow TextEditingController <-> parent _qtys map via onQtyChanged (two-way, no cursor fight)"
    - "LoteDetailScreen AppBar leading -> context.canPop() ? context.pop() : context.go('/piquetes/{paddockId}')"
---

<objective>
Fix the four cross-phase defects the user reported during the 2026-08-04 cloud UAT session
(recorded in `.planning/phases/04-movements/04-UAT.md` under `## Cross-Phase Findings`),
then rebuild and redeploy the web app.

Purpose: the app is live at campo-gestor.pages.dev and these four defects block basic
onboarding (signup dead-ends, confirmation email points at localhost) and daily lot work
(20 taps to enter 20 head, no way back from the lot screen).

Output: two auth fixes, two lotes fixes, regression tests for the branching logic, and a
redeployed build.

Root causes are already diagnosed and confirmed by code reading — implement the fixes, do
not re-investigate.

Out of scope (user already decided): F-04-05 (no lots list screen). Do NOT create a lots
list screen, do NOT register a `/lotes` route, do NOT add a 6th shell branch.
Also out of scope: the Supabase dashboard config for F-04-02 (see Task 1).
</objective>

<execution_context>
@F:/_geral/Projetos/campo_gestor/.claude/gsd-core/workflows/execute-plan.md
@F:/_geral/Projetos/campo_gestor/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.planning/phases/04-movements/04-UAT.md
@CLAUDE.md

@lib/features/auth/presentation/signup_screen.dart
@lib/features/auth/data/auth_repository.dart
@lib/core/config/app_config.dart
@lib/features/lotes/presentation/lote_form_dialog.dart
@lib/features/lotes/presentation/lote_detail_screen.dart
@lib/core/router/routes.dart
@test/features/auth/auth_repository_test.dart
@test/widget/lote_form_dialog_test.dart
@test/widget/lote_detail_screen_test.dart

Stack rules from CLAUDE.md that bind here: Riverpod 3.x (no BLoC/Provider/GetX), GoRouter
(no auto_route), supabase_flutter only (no dio). Do not add dependencies — every fix below
uses `flutter/material`, `go_router`, or `flutter/services` formatters already imported in
the target files. Test style is `flutter_test` + `mocktail` + `ProviderScope` overrides —
do not introduce a new test framework.
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Auth — signup success redirect (F-04-01) + email redirect origin (F-04-02)</name>
  <files>lib/features/auth/presentation/signup_screen.dart, lib/features/auth/data/auth_repository.dart, test/features/auth/auth_repository_test.dart, test/features/auth/signup_screen_test.dart</files>
  <behavior>
    - signup_screen_test: successful signUp shows a SnackBar with the confirm-your-email text AND the router location becomes /login.
    - signup_screen_test: an AuthException from signUp shows the exception message and the location stays /signup (existing error path must not regress).
    - auth_repository_test: signUp forwards the configured origin as the email redirect target; under `flutter test` with no --dart-define, AppConfig.appOrigin is the default `http://127.0.0.1:3000`, so that is the expected value (same convention the existing resetPasswordForEmail test already uses).
  </behavior>
  <action>
F-04-02 first, since the widget fix depends on nothing but this is the smaller edit.

In `lib/features/auth/data/auth_repository.dart`, pass `emailRedirectTo: AppConfig.appOrigin`
to the `_service.auth.signUp(...)` call. Do NOT add a static getter mirroring `resetRedirect` —
that getter exists only because it appends a `/reset-password` path segment; here the value is
`AppConfig.appOrigin` verbatim and a getter would be indirection with no transform. Update the
doc comment above `resetRedirect` (or add one line above `signUp`) noting that the signup
confirmation link uses the bare origin.

Then update `test/features/auth/auth_repository_test.dart`. IMPORTANT — the existing
`signUp delegates to GoTrueClient.signUp` test WILL break, and not in an obvious way: mocktail
matches on the exact set of named arguments, so the two-named-arg `when(...)` stub no longer
matches the now three-named-arg real call, the stub returns null, and the `await` blows up.
Add `emailRedirectTo: any(named: 'emailRedirectTo')` to the `when(...)` stub and assert the
concrete origin value in the `verify(...)`.

F-04-01: in `_SignupScreenState._submit` in `lib/features/auth/presentation/signup_screen.dart`,
add the missing success branch immediately after the awaited `signUp` call inside the `try`:
guard on `mounted` exactly as the existing catch branches do, show a SnackBar reading
"Confirme seu email para ativar a conta" via `ScaffoldMessenger.of(context)`, then
`context.go(AppRoutes.login)`. Both `go_router` and `AppRoutes` are already imported. The
existing `finally` block is already `mounted`-guarded, so it is safe after navigation — leave
it alone. Do not touch the catch branches, the form, or the validators.

Note the router already bounces a logged-in user with memberships off /login to /dashboard, so
this is correct whether or not email confirmation is enabled on the project.

New file `test/features/auth/signup_screen_test.dart`: mirror the existing test conventions —
`mocktail` mock (`class _MockAuthRepository extends Mock implements AuthRepository {}`)
injected through `ProviderScope(overrides: [authRepositoryProvider.overrideWithValue(...)])`.
Because the fix navigates, the harness needs a real router: use `MaterialApp.router` with a
tiny two-route `GoRouter` (`/signup` -> `SignupScreen`, `/login` -> a throwaway placeholder
Scaffold), `initialLocation: '/signup'`. Fill the three fields, tap "Criar conta", pump, then
assert the SnackBar text and the placeholder route content. `AuthResponse(session: null, user: null)`
is the success stub (this is exactly the email-confirmation-ON shape that caused the bug).
  </action>
  <verify>
    <automated>cd F:/_geral/Projetos/campo_gestor && flutter test test/features/auth/</automated>
  </verify>
  <done>signUp passes emailRedirectTo; the updated auth_repository_test asserts it; signup_screen_test proves both the success redirect + SnackBar and the unchanged AuthException path; all tests under test/features/auth/ pass.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Lotes — typeable quantity (F-04-03) + back button on lot detail (F-04-04)</name>
  <files>lib/features/lotes/presentation/lote_form_dialog.dart, lib/features/lotes/presentation/lote_detail_screen.dart, test/widget/lote_form_dialog_test.dart, test/widget/lote_detail_screen_test.dart</files>
  <behavior>
    - lote_form_dialog_test: typing a two-digit quantity into a category field and submitting passes that exact count through to createLotWithAnimals.
    - lote_form_dialog_test: after typing a quantity, tapping the increment button shows the value plus one in the field (proves the parent-state round trip re-syncs the controller).
    - lote_form_dialog_test: clearing the field leaves the dialog usable and the count at zero — submitting with everything cleared shows the existing "at least 1 animal" SnackBar rather than crashing.
    - lote_detail_screen_test: tapping the AppBar back button with no navigation history routes to the lot's paddock detail path.
    - lote_detail_screen_test: tapping it before the lot resolves (or when the lot is null) routes to the paddock list instead of crashing or doing nothing.
  </behavior>
  <action>
F-04-03 in `lib/features/lotes/presentation/lote_form_dialog.dart`: convert
`_CategoryCompositionRow` from `StatelessWidget` to a `StatefulWidget` and replace the
read-only qty `Text` with a `TextField`. Keep the decrement and increment `IconButton`s, their
`minWidth`/`minHeight` 44 constraints, their existing enable conditions, the category label,
and the breed dropdown exactly as they are. Widen the qty `SizedBox` from 32 to about 56 so a
three-digit value fits.

Two-way sync — this is the only tricky part, get it right:
  - The state class owns a `TextEditingController` seeded from `widget.qty` in the field
    initializer, and disposes it.
  - `onChanged` parses the raw text: empty text reports zero via `widget.onQtyChanged` WITHOUT
    rewriting the controller (otherwise the user can never clear the field); otherwise report
    the parsed integer.
  - Override `didUpdateWidget` to re-sync only when the controller's displayed value and
    `widget.qty` actually disagree, treating empty text as zero for that comparison. When they
    already agree — the normal case right after the user types — do nothing, so the cursor is
    never reset. When they disagree — a +/- tap happened — assign a full `TextEditingValue`
    with the text and a collapsed selection at the end of the text, not a bare `.text` write.
  - Enforce the existing 0..999 range with `inputFormatters` rather than a manual clamp:
    `FilteringTextInputFormatter.digitsOnly` plus `LengthLimitingTextInputFormatter(3)`. Digits
    only means non-numeric input never reaches the parser, and a 3-digit cap means the value can
    never exceed 999. This is the same formatter idiom already used by the
    "Iniciar do número" field a few lines below in this same file, and it removes the need for
    any clamp branch. `flutter/services` is already imported.
  - Give the field `keyboardType: TextInputType.number`, `textAlign: TextAlign.center`, and a
    dense bordered decoration consistent with the row.

F-04-04 in `lib/features/lotes/presentation/lote_detail_screen.dart`: give the `AppBar` at L33
a `leading: BackButton(onPressed: ...)`. In the handler: if `context.canPop()` then
`context.pop()` and return; otherwise read the paddock id off the already-watched `lotAsync`
via `asData?.value?.paddockId` and `context.go('/piquetes/$paddockId')`. When that id is null —
the lot provider has not resolved yet, or the lot is missing — fall back to
`context.go(AppRoutes.piquetes)` so the button is never dead and never crashes. Build the
paddock detail path as an inline string: that is the existing convention in this codebase
(`animal_detail_screen.dart` L258 and `piquetes_screen.dart` L183 both do it) and adding an
`AppRoutes.paddockDetail` helper would mean touching three unrelated call sites, which is out
of scope. `go_router` and `AppRoutes` are already imported here. Change nothing else on this
screen.

Tests. `test/widget/lote_form_dialog_test.dart`: `_FakeLoteRepository.createLotWithAnimals`
currently discards its arguments — add a nullable field on the fake that records the
`categoryQuantities` map it received so the submit assertion can read it back. Reuse the
existing `_buildApp` harness.

`test/widget/lote_detail_screen_test.dart`: the existing `_buildScreen` harness mounts a plain
`MaterialApp`, which has no GoRouter in the tree — `context.canPop()` would throw there. The
already-committed tests keep passing because the handler only runs on tap, so leave `_buildScreen`
untouched and add a second harness alongside it that uses `MaterialApp.router` with a small
`GoRouter` declaring `/lotes/:loteId` -> `LoteDetailScreen`, `/piquetes/:id` -> a throwaway
placeholder, and `/piquetes` -> another placeholder. Keep the same provider-override style
(`loteByIdProvider`, `animalListByLotProvider`, `paddockByIdProvider`, `memberPropertiesProvider`)
and the same sample data already defined at the top of the file. For the unresolved-lot case,
override `loteByIdProvider` to return null. Assert on the placeholder screens' content.

Do not test the canPop-true branch — that is go_router's own behavior, not ours.
  </action>
  <verify>
    <automated>cd F:/_geral/Projetos/campo_gestor && flutter test test/widget/lote_form_dialog_test.dart test/widget/lote_detail_screen_test.dart</automated>
  </verify>
  <done>Quantity is typeable and stays in sync with the +/- buttons across the 0..999 range; empty/invalid input cannot crash or corrupt the count; the lot detail AppBar has a working back button with a paddock fallback; both widget test files pass, including their pre-existing cases.</done>
</task>

<task type="auto">
  <name>Task 3: Full suite, web release build, Cloudflare Pages redeploy</name>
  <files>build/web (generated)</files>
  <action>
Run the full test suite first — Task 1 and Task 2 each only ran their own slice, and Task 1
touches `AuthRepository`'s public surface, which other fakes in the suite implement.

Then build the web release with EXACTLY these dart-defines (they are the deployed environment's
values — do not substitute, reorder does not matter but every one must be present, in particular
APP_ORIGIN, which is what makes the F-04-02 fix actually point at production):

flutter build web --release --dart-define=SUPABASE_URL=https://wrdwzychjhlpwpivfhhq.supabase.co --dart-define=SUPABASE_ANON_KEY=sb_publishable_bC3L_dNKeJ9jwUaaY1NsSA_xlmEtMoC --dart-define=APP_ORIGIN=https://campo-gestor.pages.dev

Then deploy:

npx wrangler pages deploy build/web --project-name=campo-gestor --branch=main --commit-dirty=true

`web/_redirects` already exists and is committed — the SPA fallback is in place. Do NOT re-add
or modify it.

In the SUMMARY, record as a REQUIRED MANUAL FOLLOW-UP (code cannot do it, and F-04-02 is only
half-fixed without it): in the Supabase dashboard for project wrdwzychjhlpwpivfhhq, set
Authentication > URL Configuration > Site URL to https://campo-gestor.pages.dev and add that
origin to the allowed redirect URLs. Until that is done Supabase will keep rewriting the
confirmation link back to localhost regardless of what the client sends.
  </action>
  <verify>
    <automated>cd F:/_geral/Projetos/campo_gestor && flutter test</automated>
  </verify>
  <done>`flutter test` passes with zero failures; `flutter build web --release` completes with all three dart-defines; wrangler reports a successful deployment to the campo-gestor project; the Supabase dashboard follow-up is written into the SUMMARY.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| client -> Supabase GoTrue | signup email + password + redirect target crosses here |
| user keyboard -> lot creation form | free-text quantity crosses into a batch INSERT sizing argument |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-Q-01 | Tampering | AuthRepository.signUp emailRedirectTo | medium | mitigate | Value is `AppConfig.appOrigin`, a compile-time `String.fromEnvironment` constant — never user input, so no open-redirect surface from the client. Supabase additionally rejects any redirect target absent from the project's allowed redirect URL list (the Task 3 manual follow-up). |
| T-Q-02 | Tampering | _CategoryCompositionRow quantity field | low | mitigate | Input constrained at the boundary by `FilteringTextInputFormatter.digitsOnly` + `LengthLimitingTextInputFormatter(3)`, capping the batch size at 999 per category; the empty/unparseable case degrades to 0 and is caught by the existing "at least 1 animal" submit guard. Animal numbering remains server-authoritative via the existing RPC. |
| T-Q-03 | Information disclosure | Signup success SnackBar | low | accept | The message is a fixed generic string with no account-existence signal, so it leaks nothing beyond what the signup form already implies. |

No package-manager installs in this plan — no legitimacy gate required.
</threat_model>

<verification>
1. `flutter test` — full suite green, including the pre-existing auth, lote form, and lote detail cases.
2. Manual smoke on the deployed build: sign up with a fresh email, confirm the redirect to /login and the SnackBar, and confirm the received email's link points at campo-gestor.pages.dev (this last one only after the Supabase dashboard follow-up).
3. Manual smoke: open a paddock, create a lot, type a two-digit quantity, verify the +/- buttons agree with the typed value; open a lot from an animal detail and confirm the back button returns to the lot's paddock.
</verification>

<success_criteria>
- All four findings (F-04-01, F-04-02, F-04-03, F-04-04) closed in code.
- F-04-05 untouched — no lots list screen, no /lotes route, no new shell branch.
- No new dependency in pubspec.yaml; no refactor of the router, the AppRoutes helpers, or surrounding widgets.
- `flutter test` passes.
- Build deployed to campo-gestor.pages.dev with APP_ORIGIN=https://campo-gestor.pages.dev.
- SUMMARY records the Supabase dashboard Site URL / redirect allowlist follow-up.
</success_criteria>

<output>
Create `.planning/quick/260804-fpk-fix-4-cross-phase-uat-findings-from-phas/260804-fpk-SUMMARY.md` when done
</output>
