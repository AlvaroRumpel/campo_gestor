---
status: complete
phase: 04-movements
source: [04-VERIFICATION.md]
started: 2026-07-16T00:00:00Z
updated: 2026-08-04T15:00:00Z
cloud_project_ref: wrdwzychjhlpwpivfhhq
cloud_url: https://wrdwzychjhlpwpivfhhq.supabase.co
---

## Gate Overrides

- gate: api-coverage (verify:pre, blocking)
  overridden_at: 2026-08-04
  by: user
  reason: |
    False positive. Detector fired on SERVICE_SURFACE_API_RE matching prose
    phrases "Supabase SDK" / "Flutter SDK" / "Direct API misuse" in the phase
    artifacts — no integration verb signal. Phase 4 integrates zero external
    APIs (04-RESEARCH.md:569 "No new external tools, services, or runtimes";
    04-UI-SPEC.md:316 "zero new pub.dev packages"). Supabase is the project's
    own first-party backend, not a third-party API surface. Nothing to
    enumerate in a COVERAGE.md.

## Current Test

[testing complete]

## Tests

### 1. Apply the migrations to the cloud project
expected: All 8 migrations applied to Supabase project campo_gestor (ref wrdwzychjhlpwpivfhhq), in order.
result: [pass] — Applied 2026-08-04 via MCP apply_migration. `list_migrations` shows all 8 (auth_multitenancy → lot_paddock_property_trigger). DB clean (0 rows), both movement triggers present.

### 2. Trigger enforcement proven at the database
expected: cross-property lot assignment raises 23503; same-property succeeds; unassigned (NULL) allowed.
result: [pass] — Direct DB smoke test (DO block, rolled back): `animals_cross_blocked=t lots_cross_blocked=t animals_same_ok=t`. (pgTAP file exists in repo; this direct test is equivalent proof and stronger — it runs as superuser and the trigger still fires.)

### 3. SC-4 raw-write enforcement — ANIMALS
expected: setting animals.lot_id to a lot in a different property is rejected 23503 on any write path.
result: [pass] — A superuser `UPDATE animals SET lot_id=<foreign-property lot>` was rejected with 23503 by trg_animals_lot_same_property. A superuser UPDATE bypasses RLS but the trigger still fired → proves enforcement is access-path-independent (a raw authenticated PATCH is strictly weaker).

### 4. MOV-02 raw-write enforcement — LOTS
expected: setting lots.paddock_id to a paddock in a different property is rejected 23503 on any write path.
result: [pass] — A superuser `UPDATE lots SET paddock_id=<foreign-property paddock>` was rejected with 23503 by trg_lots_paddock_same_property.

### 5. MOV-01 happy path (move animal, same property) — UI
expected: As a veterinarian, open an animal → "Mover animal" → picker shows only same-property lots → select → confirm → SnackBar "Animal movido para {lote}"; animal appears under the new lot, gone from the old.
result: pass — verified 2026-08-04 by the user against https://campo-gestor.pages.dev (Cloudflare Pages, release build wired to the cloud project). Seed data created through the UI (propriedade → piquete 1A → Lote A, 20 vacas Wagyu).

### 6. MOV-02 happy path (move lot between paddocks) — UI
expected: As a veterinarian, open a lot with active animals → "Mover para piquete" → picker excludes current paddock → select → "Confirmar movimentação" → SnackBar "Lote movido para {piquete}"; lot leaves old paddock's list, appears in new; header refreshes.
result: pass — verified 2026-08-04 by the user against https://campo-gestor.pages.dev.

### 7. Role + state gates — UI
expected: Reader → no move buttons. Archived lot → no "Mover para piquete". Lot with 0 active animals → no "Mover para piquete".
result: pass — partial live coverage, 2026-08-04. VERIFIED LIVE: the 0-active-animals arm ("Lote C", piquete 2A, "Sem animais ativos.") renders no "Mover para piquete" button. NOT exercised live: the reader-role arm (needs a 2nd user) and the archived-lot arm (needs an archive action in the UI). All three arms are operands of one boolean at lote_detail_screen.dart:221 (`canEdit && lot.deletedAt == null && activeCount > 0`); the live pass proves that expression is evaluated and gates the button. The other two operands rest on the Plan 04-01 Task 5/6 widget gate tests, not on live observation.

### 8. pt-BR singular/plural copy — UI
expected: MoverLoteDialog reads "1 animal será transferido" for a single-animal lot, "N animais serão transferidos" for N>1.
result: pass — partial live coverage, 2026-08-04. VERIFIED LIVE: the plural arm. MoverLoteDialog on "Lote A" (20 vacas, piquete 2A) reads "20 animais serão transferidos para o novo piquete. A operação é atômica — ou todos movem ou nenhum." The same screenshot also confirms the picker excludes the current paddock (only 1A offered) — the UI-side T-4-06 guard. NOT exercised live: the singular arm, which would need a lot holding exactly 1 animal. Both arms are the two branches of one ternary on `activeAnimalCount == 1` at mover_lote_dialog.dart:88-91, covered by the Plan 04-01 widget test.

## Summary

total: 8
passed: 8
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

## Cross-Phase Findings

Reported by the user during the 2026-08-04 cloud UAT session. None belong to
Phase 4 (movements) — all four are pre-existing defects in Phase 1 (auth) and
Phase 3 (lotes) surfaced by exercising the app end-to-end for the first time.
Recorded here so they are not lost; NOT listed under `## Gaps` because
`/gsd-execute-phase 04 --gaps-only` must not pull out-of-scope work.

- finding_id: F-04-01
  phase: 01-auth
  severity: major
  reported: "Criei a conta e não redirecionou"
  root_cause: |
    `_SignupScreenState._submit` has no success branch — it awaits signUp and,
    on success, falls straight through to `finally`. No navigation, no SnackBar.
    With email confirmation ON the AuthResponse carries no session, so the
    router's auth guard never fires either. The user sees an unchanged form.
  artifacts:
    - path: "lib/features/auth/presentation/signup_screen.dart"
      issue: "_submit (L33-L51) missing success handling"
  missing:
    - "On success: SnackBar 'Confirme seu email para ativar a conta' + context.go(AppRoutes.login)"

- finding_id: F-04-02
  phase: 01-auth
  severity: major
  reported: "o email de confirmação vai para localhost"
  root_cause: |
    `AuthRepository.signUp` does not pass `emailRedirectTo`. Only
    `resetPasswordForEmail` uses `AppConfig.appOrigin`. Supabase therefore falls
    back to the project's dashboard Site URL, still http://localhost:3000.
  artifacts:
    - path: "lib/features/auth/data/auth_repository.dart"
      issue: "signUp (L27-L31) omits emailRedirectTo"
  missing:
    - "signUp(..., emailRedirectTo: AppConfig.appOrigin)"
    - "Supabase dashboard: set Site URL + allowed redirect URLs to the deployed origin (config change, not code)"

- finding_id: F-04-03
  phase: 03-lotes
  severity: minor
  reported: "Ao criar o lote fica ruim ficar clicando nos botões para adicionar ou diminuir, pode ter os botões mas o campo deve ser tbm escrevivel"
  root_cause: |
    `_CategoryCompositionRow` renders the quantity as a read-only `Text`, so the
    only input path is the +/- IconButtons. Entering 20 head costs 20 taps.
  artifacts:
    - path: "lib/features/lotes/presentation/lote_form_dialog.dart"
      issue: "qty display (L258-L263) is a Text, not a TextField"
  missing:
    - "Replace the Text with a numeric TextField kept in sync with onQtyChanged; keep the +/- buttons"

- finding_id: F-04-04
  phase: 03-lotes
  severity: minor
  reported: "não tem como voltar da tela do Lote"
  root_cause: |
    `/lotes/:loteId` is a root-level GoRoute (D-03), not nested under a parent,
    and every caller navigates with `context.go()` — which replaces the stack.
    `canPop()` is therefore false and `automaticallyImplyLeading` renders no
    back button. AnimalDetailScreen escapes this only because it sits under the
    `/animais` shell branch, which supplies a parent.
  artifacts:
    - path: "lib/features/lotes/presentation/lote_detail_screen.dart"
      issue: "AppBar (L33) has no leading and nothing to pop"
    - path: "lib/core/router/router.dart"
      issue: "loteById (L134) declared at root level"
  missing:
    - "AppBar leading: BackButton that pops when possible, else context.go to the lot's paddock"

- finding_id: F-04-05
  phase: 03-lotes
  severity: minor
  reported: "não tem uma visualização só dos lotes né, oq dificulta a navegação"
  root_cause: |
    There is no lots list screen. `AppRoutes.lotes` ('/lotes') is declared but
    has ZERO usages anywhere in lib/ or test/ — no GoRoute is registered for it
    and no shell branch exists for lotes (branches are dashboard, piquetes,
    animais, reproducao, sanitario). Per D-03 lots are reachable only by
    drilling through a paddock, or sideways from an animal detail. Combined with
    F-04-04 (no back button out of the lot screen) the lot screen is a dead end.
  artifacts:
    - path: "lib/core/router/routes.dart"
      issue: "AppRoutes.lotes declared but unused — dead constant"
    - path: "lib/core/router/router.dart"
      issue: "no GoRoute or shell branch for the lots list"
  missing:
    - "Decide whether lots get their own shell branch or a /lotes list route; this is a roadmap/scope call, not a bug fix"
