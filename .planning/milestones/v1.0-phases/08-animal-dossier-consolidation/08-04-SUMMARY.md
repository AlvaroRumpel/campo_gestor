---
phase: 08-animal-dossier-consolidation
plan: 04
subsystem: ui
tags: [flutter, riverpod, layoutbuilder, widget-test]

# Dependency graph
requires:
  - phase: 08-animal-dossier-consolidation
    provides: "08-01 — LotWithPaddockName, fetchLotWithPaddockName, loteWithPaddockByIdProvider"
  - phase: 08-animal-dossier-consolidation
    provides: "08-02 — the ficha composition after the reproductive extraction"
  - phase: 08-animal-dossier-consolidation
    provides: "08-03 — the per-block retry pattern this plan does not touch"
  - phase: 08-animal-dossier-consolidation
    provides: "08-05 — DG expansion, exercised (not modified) by this plan's full-suite verification"
provides:
  - "_BaixaBanner — full-width errorContainer banner at the top of the ficha for archived animals (SC-4)"
  - "_KvRow adaptive breakpoint (LayoutBuilder, <400px stacks) — first row-level width breakpoint in the repo (SC-5)"
  - "AnimalInfoCard consumes loteWithPaddockByIdProvider — the lote→piquete waterfall is dead (D-01)"
  - "tester.view.physicalSize 360px widget-test harness — first width-constrained test in the repo, documented for reuse"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "LayoutBuilder on a leaf/row widget (not just the app-shell level) for a width breakpoint — _KvRow is the first instance in this repo"
    - "tester.view.physicalSize / devicePixelRatio / addTearDown(resetPhysicalSize) inside individual testWidgets bodies — first width-constrained widget test in this repo"
    - "Wrap(alignment: WrapAlignment.end) instead of Row(mainAxisAlignment: end) for a button row that must not overflow at narrow widths"

key-files:
  created: []
  modified:
    - lib/features/animais/presentation/animal_detail_screen.dart
    - test/widget/animal_detail_screen_test.dart

key-decisions:
  - "_BaixaBanner is a plain StatelessWidget, not Stateful — unlike _EncerrarBanner (Phase 5), it has no dismiss/action affordance, so there is no session-local state to hold"
  - "The baixa-reason switch (sale/death/discard/fallback) was MOVED from AnimalInfoCard into _BaixaBanner, not duplicated — D-13"
  - "_KvRow wraps its existing Row in a LayoutBuilder reading constraints.maxWidth (not MediaQuery) — the adaptive shell narrows the content column below screen width on wide viewports, so the local constraint is the correct signal (D-21)"
  - "AnimalInfoCard's two lote/piquete rows now derive from one ref.watch(loteWithPaddockByIdProvider(...)) instead of two chained watches — the piquete row has no AsyncValue of its own anymore"
  - "Width-sensitive Task 3 tests (no-overflow, label-stacks, long-name backstops) mount AnimalInfoCard directly via a new _buildInfoCard test helper, not the whole AnimalDetailScreen — see Deviations/Known Issues for why"

patterns-established:
  - "360px widget-test harness: addTearDown(tester.view.resetPhysicalSize); tester.view.physicalSize = const Size(360, 800); tester.view.devicePixelRatio = 1.0; — set inside individual testWidgets bodies, copyable in three lines"
  - "Row-level width breakpoint: wrap the widget's existing Row return in a LayoutBuilder, branch on constraints.maxWidth against the locked threshold, keep the wide-layout Row branch byte-identical"

requirements-completed: []

coverage:
  - id: D1
    description: "Archived animal shows a full-width errorContainer banner (motivo, date, observation) as the first ficha element, above AnimalInfoCard; active animal shows no banner and no duplicated status text in the card (SC-4, D-12..D-15)"
    requirement: "ANIM-03"
    verification:
      - kind: automated_ui
        ref: "test/widget/animal_detail_screen_test.dart — Banner de baixa group, 6/6 tests pass"
        status: pass
    human_judgment: false
  - id: D2
    description: "_KvRow stacks label above value below 400px width and keeps the existing 120px-label row at/above it; long lot/paddock names and long baixa observations don't overflow at 360px (SC-5, D-21)"
    requirement: "ANIM-03"
    verification:
      - kind: automated_ui
        ref: "test/widget/animal_detail_screen_test.dart — Layout adaptativo a 360px group, 5/5 tests pass"
        status: pass
    human_judgment: false
  - id: D3
    description: "AnimalInfoCard's Lote atual / Piquete atual rows resolve from a single loteWithPaddockByIdProvider read instead of two chained watches; a failed read degrades only those two rows to em-dash without hiding the animal's own fields (D-01)"
    requirement: "ANIM-03"
    verification:
      - kind: unit
        ref: "grep -n \"ref.watch(loteWithPaddockByIdProvider(\" — single occurrence in AnimalInfoCard"
        status: pass
      - kind: automated_ui
        ref: "test/widget/animal_detail_screen_test.dart — Degradação parcial do card group, 1/1 test passes"
        status: pass
    human_judgment: false
  - id: D4
    description: "DEFERRED — UNVERIFIED. SC-1 (<1s ficha open under Fast 4G throttle, 4 parallel requests) was NOT measured. The user explicitly deferred Task 4's UAT rather than running it. This is not a pass, not a fail — it is unmeasured. Do not infer a timing result from the request-count reduction (D3/T-08-01): fewer requests is necessary but not sufficient evidence for the <1s wall-clock target."
    verification: []
    human_judgment: true
    rationale: "This project's repository tests are deliberately shallow contract tests (query-builder mocking is explicitly called brittle in the test files' own header comments) and integration_test does not run on web in this project (STATE.md Phase 0 notes). SC-1's <1s-under-4G evidence can only come from a human timing the real network tab with DevTools 'Fast 4G' throttling. User decision: defer this UAT rather than run it now. Reproduction steps are recorded verbatim below for whoever runs it later."

# Metrics
duration: 35min
completed: 2026-08-11
status: complete
---

# Phase 8 Plan 4: Baixa Banner, Adaptive _KvRow, and Single Lote+Piquete Read Summary

**Full-width errorContainer banner replaces the card's duplicated status chip, `_KvRow` gets its first row-level width breakpoint via `LayoutBuilder`, `AnimalInfoCard` collapses the lote→piquete waterfall into one embedded read, and the repo gains its first 360px-constrained widget-test harness. SC-1's <1s-under-4G wall-clock target is UNMEASURED — deferred by explicit user decision, not verified.**

## ⚠ Open Item: SC-1 timing UAT deferred, not verified

**Tasks 1-4 as coded/tested are done. SC-1's human UAT (Task 4) was explicitly deferred by the user — it did NOT run.** Do not read `status: complete` above as "SC-1 passed." Two separate facts, kept separate:

- **PROVEN (code-verifiable, committed):** the ficha issues 4 parallel requests instead of 5 with a cascading piquete read — `AnimalInfoCard` now reads `loteWithPaddockByIdProvider` once instead of chaining `loteByIdProvider` → `paddockByIdProvider`. This is mechanically true from the diff and covered by `test/widget/animal_detail_screen_test.dart`'s "Degradação parcial do card" test.
- **NOT PROVEN (unmeasured):** the <1s wall-clock target under Fast-4G throttle. Fewer requests does not by itself prove sub-1s load time — that requires a human timing it. See "Deferred: SC-1 4G UAT" below for the exact reproduction steps.

## Performance

- **Duration (Tasks 1-3, coded/tested work):** ~35 min
- **Started:** 2026-08-11T21:47:00Z (approx.)
- **Tasks 1-3 completed:** 2026-08-11T22:17:00Z (approx.)
- **Tasks:** 3 of 4 complete; Task 4 (SC-1 UAT) deferred, not run
- **Files modified:** 2

## Accomplishments

- **Task 1 (SC-4, D-12..D-15):** New `_BaixaBanner` (`StatelessWidget`) renders as the first `ListView` child whenever `animal.deletedAt != null` — full-width `errorContainer` background, `Icons.info_outline`, motivo + date + observation in one wrapping `Text` (no `maxLines`, no truncation). The baixa-reason switch (sale→Vendido, death→Morto, discard→Descartado, fallback→Arquivado) was moved out of `AnimalInfoCard` into the banner, not duplicated. The card's `Status` `_KvRow` and its now-orphaned `statusLabel`/`statusBgColor`/`statusTextColor` locals were removed entirely.
- **Task 2 (D-21, D-01):** `_KvRow` now wraps its existing `Row` in a `LayoutBuilder`; below 400px it renders a `Column` (label above value, `SizedBox(height: 2)` between), at/above 400px the original 120px-label `Row` is unchanged. `AnimalInfoCard` swaps the two chained watches (`loteByIdProvider` → derived `paddockByIdProvider`) for a single `ref.watch(loteWithPaddockByIdProvider(animal.lotId))`; both "Lote atual" and "Piquete atual" rows now derive from the same `AsyncValue`. The now-unused `piquete_repository.dart` import was removed.
- **Task 3 (D-23):** 12 new widget tests across three groups (banner, 360px layout, partial degradation), plus the repo's first `tester.view.physicalSize` width-harness, documented as copyable. All 26 tests in the file pass; full suite (349 tests) and repo-wide `flutter analyze` (same 4 pre-existing unrelated issues as prior 08-0x plans) both green.

## Task Commits

Each task was committed atomically:

1. **Task 1: Banner de baixa no topo da ficha e saída da linha de Status do card (D-12..D-15, SC-4)** - `5903add` (feat)
2. **Task 2: Linha chave-valor adaptativa e leitura única de lote+piquete (D-21, D-01)** - `1b24153` (feat)
3. **Task 3: Testes de widget do banner e do layout a 360px, com o harness de largura reutilizável (D-23, SC-4, SC-5)** - `0f9e8b2` (test)

**Task 4: DEFERRED — UNVERIFIED (human_needed).** `checkpoint:human-verify`, gate=`blocking`. User explicitly chose to defer this UAT rather than run it now. See "Deferred: SC-1 4G UAT" below for what it measures and the exact reproduction steps.

**Plan metadata:** see final commit hash at the end of this document.

## Files Created/Modified

- `lib/features/animais/presentation/animal_detail_screen.dart` — `_BaixaBanner` added; card's Status row removed; `_KvRow` made adaptive via `LayoutBuilder`; the lote/piquete rows swapped to the single embedded-select provider; the action-button row switched from `Row` to `Wrap` (see Deviations).
- `test/widget/animal_detail_screen_test.dart` — 12 new tests (banner, 360px layout, partial degradation groups) plus a new `_buildInfoCard` test helper and the `loteWithPaddockBuilder` override hook on `_buildScreen`.

## Decisions Made

See `key-decisions` above. The most consequential one not fully spelled out in the plan: Task 3's width-sensitive "no overflow" assertions mount `AnimalInfoCard` directly (via a new `_buildInfoCard` helper) rather than the whole `AnimalDetailScreen`, because of a pre-existing, D-37-locked overflow bug discovered by this plan's own first-ever narrow-width test — see Deviations/Known Issues below.

## Deferred: SC-1 4G UAT (Task 4 — not run)

**What it would measure:** whether the ficha paints completely (card + both history blocks filled, no spinners) in under 1 second under DevTools "Fast 4G" throttle, and confirms exactly 4 Supabase requests fire (the waterfall being dead, per D-01/D3 above). This is the human-facing wall-clock proof; nothing in this plan's automated suite measures wall-clock time or live request counts (see rationale below).

**Why it is not automatable here:** this project's repository tests are deliberately shallow contract tests (query-builder mocking is explicitly called brittle in the test files' own header comments — not this plan's decision, a standing project convention), and `integration_test` has no web support in this project (STATE.md Phase 0 notes: `flutter run -d edge` was the manual fallback used for the equivalent SC-1 check in Phase 0). A timing assertion run on desktop against a real network would measure desktop-network latency, not 4G — not representative.

**Reproduction steps (verbatim, for whoever runs this later):**

1. Run the app in Chrome or Edge (dev web build).
2. Log in and select a property with real data.
3. Open DevTools → Network tab → enable "Fast 4G" throttle.
4. Clear the network log.
5. Go to the animal list and search by number for the heaviest animal available (one with an ATF that has a DG, plus at least one sanitary application).
6. Time from tap to fully painted ficha (card + both history blocks filled, no spinners).
7. Record: elapsed time and Supabase request count in the Network tab. **Target: <1s and 4 requests.**
8. Repeat from step 4 with an ARCHIVED animal (search by exact number, "Mostrar arquivados" off). Confirm it's found, the ficha opens, the red baixa banner shows reason/date/observation at the top, and both histories are still complete.
9. Still throttled, narrow the browser to 360px width (or DevTools device mode). Confirm no card row is cramped, label/value stack correctly, and the baixa banner text wraps without cutting off. **Known:** you will see `sanitary_history_section.dart`'s header row overflow here — pre-existing, not a regression from this plan, see "Known Issues" below.

**D-01 fallback, carried forward:** if request count > 4, the waterfall wasn't actually killed — investigate before retrying the timing check. If time > 1s WITH 4 requests confirmed, the documented next lever is the consolidated RPC/view that D-01 explicitly deferred pending exactly this condition (not a new decision — re-open D-01's original tradeoff, don't re-derive it).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] AnimalInfoCard's action-button Row overflowed by 345px at 360px width**
- **Found during:** Task 3, while writing the first 360px-width widget test in this repo
- **Issue:** The three action buttons (Editar animal / Dar baixa / Mover animal) were laid out in a `Row(mainAxisAlignment: end)` with no wrapping mechanism. At 360px available width (the SC-5 floor this plan is supposed to prove), the three buttons' combined intrinsic width overflowed the Row by 345px — undiscovered until now because no test had ever pumped this screen at a narrow width before.
- **Fix:** Replaced `Row(mainAxisAlignment: MainAxisAlignment.end, ...)` with `Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, ...)`. Same buttons, same end-alignment, same 8px gap at widths where they already fit (no visual change there); at 360px they now wrap onto multiple lines instead of overflowing.
- **Files modified:** lib/features/animais/presentation/animal_detail_screen.dart
- **Verification:** `test/widget/animal_detail_screen_test.dart` — "360px: no layout overflow is reported" (via `_buildInfoCard`) passes; full suite (349 tests) still green.
- **Committed in:** `0f9e8b2` (Task 3 commit — the fix and its proving test landed together)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** In-scope file (this plan already modifies `animal_detail_screen.dart`), no D-37 boundary involved, no scope creep — the same button row Task 1's own action block said to leave untouched while removing the Status row is untouched in *content*; only its layout container changed to fix a genuine, plan-blocking overflow bug this plan's own new test infrastructure surfaced.

## Known Issues (not fixed — out of this plan's scope)

**`sanitary_history_section.dart`'s header row overflows at 360px — D-37-locked, cannot be fixed by this plan.**

While writing Task 3's 360px tests, pumping the *whole* `AnimalDetailScreen` (not just `AnimalInfoCard`) at 360px reliably throws a second, unrelated `RenderFlex` overflow (29px) from `_SanitaryHistoryCardShell`'s header `Row` (`sanitary_history_section.dart:285` — the `"Histórico Sanitário"` title + `"Mostrar estornadas"` label + `Switch`, none of which is wrapped or truncated). This is genuinely present in production at narrow widths, not a test artifact — confirmed via a standalone `ProviderContainer` reproduction independent of any test harness quirks.

This plan's `<threat_model>` explicitly locks `sanitary_history_section.dart` to the Task-1-only D-04 retry-button diff from plan 08-03 ("no other line in that file changes" — the phase's own hard boundary, re-affirmed for Phase 8). Fixing this overflow (e.g. wrapping the header in a `Wrap`, or giving `"Mostrar estornadas"` a `Flexible`/smaller style) is out of scope for this plan by that explicit boundary.

**Consequence for Task 3's tests:** the width-sensitive "no overflow" assertions (`tester.takeException()` is null) were scoped to `AnimalInfoCard` mounted directly via a new `_buildInfoCard` test helper — proving what this plan's own Task 2 changed (`_KvRow` + the lote/piquete rows + the now-fixed button row) is overflow-free at 360px, without depending on the locked file. The one test that must reach the banner (`_BaixaBanner` is private to `animal_detail_screen.dart`, only reachable by pumping the whole screen) — "360px: a long baixa observation wraps without overflowing" — does NOT assert `tester.takeException()` is null for this reason; it asserts the banner's own text renders in full instead (findsNWidgets(2): once in the banner, once in the card's pre-existing Observação row).

**Consequence for Task 4's UAT (human-facing):** the developer running Task 4's step 9 (narrowing the browser to 360px) will visually see the sanitary section's header row cramped/overflowing in the real app. This is expected, pre-existing, and outside this plan — **not** a regression from Tasks 1-3. Recommend a follow-up quick task to give `_SanitaryHistoryCardShell`'s header row the same `LayoutBuilder`/stacking treatment `_KvRow` got in this plan, or a simpler `Flexible` wrap around the `"Mostrar estornadas"` label.

## Issues Encountered

- **`ListView`'s default `cacheExtent` initially looked like a bug, wasn't.** While writing the D-16 test ("archived animal: reproductive and sanitary blocks stay reachable"), `find.text('Histórico Sanitário')` returned 0 widgets at the test's default 800×600 viewport — reproducibly, regardless of provider mocking. Root cause: for an archived animal, `_BaixaBanner` adds extra height above `AnimalInfoCard`, pushing the sanitary card's `Element` past `ListView`'s viewport+cacheExtent window, so it is never built without scrolling — a test-viewport artifact, not a rendering bug (confirmed via direct `ProviderContainer` state inspection: the provider resolves normally; via `debugDumpApp()`: the widget genuinely isn't in the tree at that window size; via a taller `physicalSize`: the header appears immediately). Fixed by giving that one test a tall `physicalSize` (800×2000) instead of scrolling, since the test only needs to prove reachability, not exercise the D-21 breakpoint.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Tasks 1-3's code and tests are done and green: full test suite (349 tests) and repo-wide `flutter analyze` (4 pre-existing unrelated issues, 0 errors) both pass as of `0f9e8b2`. Phase 8's remaining plans do not depend on SC-1's timing number, so this plan is not a blocker for anything downstream.

**Still outstanding, not blocking:**

1. **SC-1's 4G UAT (Task 4)** — deferred by explicit user decision, not run. See "Deferred: SC-1 4G UAT" above for what it measures and the exact steps. Whoever picks this up later needs no rediscovery.
2. Optional follow-up: file the D-37-locked `sanitary_history_section.dart` header-overflow-at-360px finding as its own quick task (see "Known Issues").

---
*Phase: 08-animal-dossier-consolidation*
*Completed: 2026-08-11*
*SC-1 timing UAT: deferred, unverified — see "Deferred: SC-1 4G UAT" above*

## Self-Check: PASSED
Confirmed on disk: `lib/features/animais/presentation/animal_detail_screen.dart`, `test/widget/animal_detail_screen_test.dart`. Confirmed in git log: `5903add`, `1b24153`, `0f9e8b2`.
