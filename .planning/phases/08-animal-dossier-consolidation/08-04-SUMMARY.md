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
    description: "SC-1 (<1s ficha open under Fast 4G throttle, 4 parallel requests) — human UAT with DevTools throttling and a stopwatch"
    verification: []
    human_judgment: true
    rationale: "This project's repository tests are deliberately shallow contract tests (query-builder mocking is explicitly called brittle in the test files' own header comments) and integration_test does not run on web in this project (STATE.md Phase 0 notes). SC-1's <1s-under-4G evidence can only come from a human timing the real network tab. Task 4 (checkpoint:human-verify) is this UAT and has not run yet — pending human execution."

# Metrics
duration: pending (Task 4 not yet run)
completed: pending
status: blocked-on-checkpoint
---

# Phase 8 Plan 4: Baixa Banner, Adaptive _KvRow, and Single Lote+Piquete Read Summary (PARTIAL — Task 4 pending human UAT)

**Tasks 1-3 complete: full-width errorContainer banner replaces the card's duplicated status chip, `_KvRow` gets its first row-level width breakpoint via `LayoutBuilder`, `AnimalInfoCard` collapses the lote→piquete waterfall into one read, and the repo gains its first 360px-constrained widget-test harness. Task 4 (SC-1's 4G UAT checkpoint) has NOT run — this SUMMARY will be updated with its result before the plan is marked complete.**

## Status

**This SUMMARY covers Tasks 1-3 only.** Task 4 is a `checkpoint:human-verify` (`gate="blocking"`) that requires a human with Chrome DevTools "Fast 4G" throttling and a stopwatch — it cannot be executed by an agent. See the plan's own `<what-built>`/`<how-to-verify>`/`<resume-signal>` blocks in `08-04-PLAN.md` Task 4 for the exact UAT script.

STATE.md's plan counter and ROADMAP.md's plan-progress table have **not** been advanced — this plan is not yet complete. A continuation agent (or the same session, after the human runs the UAT) must: run Task 4's verification, append its results to this SUMMARY (tempo cronometrado + request count), flip `status: complete`, then run the normal state/roadmap/requirements updates and the final metadata commit.

## Performance

- **Duration (Tasks 1-3):** ~35 min
- **Started:** 2026-08-11T21:47:00Z (approx.)
- **Tasks 1-3 completed:** 2026-08-11T22:17:00Z (approx.)
- **Tasks:** 3 of 4 complete
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

**Task 4: NOT YET RUN** — checkpoint:human-verify, awaiting the developer.

**Plan metadata:** pending (this SUMMARY will get a `docs:` commit once Task 4's result is appended and `status: complete`)

## Files Created/Modified

- `lib/features/animais/presentation/animal_detail_screen.dart` — `_BaixaBanner` added; card's Status row removed; `_KvRow` made adaptive via `LayoutBuilder`; the lote/piquete rows swapped to the single embedded-select provider; the action-button row switched from `Row` to `Wrap` (see Deviations).
- `test/widget/animal_detail_screen_test.dart` — 12 new tests (banner, 360px layout, partial degradation groups) plus a new `_buildInfoCard` test helper and the `loteWithPaddockBuilder` override hook on `_buildScreen`.

## Decisions Made

See `key-decisions` above. The most consequential one not fully spelled out in the plan: Task 3's width-sensitive "no overflow" assertions mount `AnimalInfoCard` directly (via a new `_buildInfoCard` helper) rather than the whole `AnimalDetailScreen`, because of a pre-existing, D-37-locked overflow bug discovered by this plan's own first-ever narrow-width test — see Deviations/Known Issues below.

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

## Next Phase Readiness (blocked)

**This plan is not done.** Outstanding before it can be marked complete:

1. **Task 4** — a human must run the Fast-4G DevTools UAT described in `08-04-PLAN.md` Task 4's `<how-to-verify>`: open the ficha for a heavy animal (ATF with DG + sanitary application), confirm <1s / 4 requests, repeat for an archived animal (confirm the banner + both histories), and check the 360px layout visually (including the known sanitary-header overflow noted above, which is not this plan's regression).
2. Append Task 4's two measured numbers (time, request count) to this SUMMARY and flip `status: complete`.
3. Run the standard `state advance-plan` / `state update-progress` / `roadmap update-plan-progress` / `requirements mark-complete` sequence and the final metadata commit — none of that has run yet.
4. Optionally: file the D-37-locked sanitary-header-overflow finding as a follow-up quick task, since it's real, pre-existing, and will be visible in Task 4's own UAT.

No blockers for Tasks 1-3's own correctness: full test suite (349 tests) and repo-wide `flutter analyze` (4 pre-existing unrelated issues, 0 errors) are both green as of `0f9e8b2`.

---
*Phase: 08-animal-dossier-consolidation*
*Status: blocked-on-checkpoint (Task 4 pending human UAT)*

## Self-Check: PASSED
Confirmed on disk: `lib/features/animais/presentation/animal_detail_screen.dart`, `test/widget/animal_detail_screen_test.dart`. Confirmed in git log: `5903add`, `1b24153`, `0f9e8b2`.
