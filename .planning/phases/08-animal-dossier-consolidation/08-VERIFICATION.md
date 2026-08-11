---
phase: 08-animal-dossier-consolidation
verified: 2026-08-11T22:36:42Z
status: human_needed
score: 5/7 must-haves verified
behavior_unverified: 1 # baixa-banner overflow backstop (08-04): truncation proven, overflow-absence not directly asserted
overrides_applied: 0
gaps: [] # no FAILED truths — see human_verification and behavior_unverified_items below
behavior_unverified_items:
  - truth: "Baixa banner text (motivo + data + observação livre) wraps across multiple lines without overflowing the layout at 360px width (08-04 backstop, UI-SPEC overflow/long-text)."
    test: "Mount _BaixaBanner (or AnimalDetailScreen with an archived animal + long observation) at a 360px physicalSize and assert tester.takeException() is null."
    expected: "No RenderFlex/layout overflow exception is thrown by the banner itself."
    why_human: "The one test that reaches _BaixaBanner (private to animal_detail_screen.dart) pumps the whole AnimalDetailScreen, which also contains AnimalSanitaryHistorySection — a sibling widget with its own pre-existing, D-37-locked ~29px header overflow at 360px (documented in 08-04-SUMMARY.md 'Known Issues'). Because of that confound, the test deliberately does not assert tester.takeException() is null; it instead asserts the full observation text is found twice (findsNWidgets(2)), which proves no truncation/ellipsis but does not mechanically prove absence of visual overflow for the banner specifically. Source inspection (Container→Row→Expanded→Text, no maxLines/overflow set) suggests the banner itself does not overflow, but this is not test-proven in isolation."
human_verification:
  - test: "SC-1 timing UAT (D-07): open the ficha via exact-number search under DevTools 'Fast 4G' throttle and time from tap to fully painted (card + both history blocks, no spinners); also confirm the Supabase request count is 4."
    expected: "< 1s wall-clock and exactly 4 requests (per 08-04-PLAN.md Task 4 <how-to-verify>)."
    why_human: "Explicitly deferred by the user (08-04-SUMMARY.md 'Deferred: SC-1 4G UAT'). integration_test has no web support in this project and repository tests are deliberately shallow contract tests, so no automated harness can produce a real 4G wall-clock number. The request-count reduction (5→4, waterfall killed) IS code-verified; the <1s target is NOT."
  - test: "Baixa banner overflow at 360px, isolated from the known sanitary-section confound (see behavior_unverified_items above)."
    expected: "No visual overflow/clipping of the banner text at 360px, independent of the pre-existing sanitary header issue."
    why_human: "No isolated automated assertion currently proves this; see behavior_unverified_items for the confound."
---

# Phase 8: Animal Dossier Consolidation Verification Report

**Phase Goal:** Veterinário em campo abre a ficha do animal e vê em uma única tela todos os dados, lote atual, histórico reprodutivo completo e histórico sanitário completo — entregando o core value do produto.
**Verified:** 2026-08-11T22:36:42Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (Roadmap Success Criteria SC-1..SC-5)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| SC-1 | Ficha abre via busca por número (ANIM-05) ou clique na lista, em <1s sob 4G | ⏳ DEFERRED (human_needed) | Code-verifiable half PASSES: `AnimalInfoCard` now issues a single `ref.watch(loteWithPaddockByIdProvider(...))` instead of two chained watches (`animal_detail_screen.dart:155`), confirmed by `grep -c "ref.watch(loteWithPaddockByIdProvider("` = 1 and by the "Degradação parcial do card" widget test. The <1s wall-clock target under Fast-4G is explicitly **not measured** — Task 4 of 08-04-PLAN.md (`checkpoint:human-verify`, gate=`blocking`) was deferred by the user per 08-04-SUMMARY.md. Do not read this as a pass; fewer requests ≠ proven sub-1s. |
| SC-2 | Ficha exibe dados do animal, lote operacional atual, piquete atual, todos LoteATFs (com DGs), todas aplicações sanitárias | ✓ VERIFIED | `LotWithPaddockName`/`fetchLotWithPaddockName` (lote_repository.dart:178-220) embed the paddock name in one PostgREST select. `ReproductiveHistoryEntry.dgRecords` (atf_model.dart:91) carries the full per-ATF DG list, populated by `atf_repository.dart`'s `dgsByAtf` grouping (lines 209-224, `putIfAbsent`, `isLaterDg` comparator). `AnimalReproductiveHistorySection`'s `_ReproductiveHistoryRow` gates an `ExpansionTile` on `entry.dgRecords.length > 1` (line 199) revealing all DGs; 0/1-DG ATFs render the unchanged collapsed row. `AnimalSanitaryHistorySection` (untouched query, D-37) continues to render the full sanitary snapshot history. All confirmed by 349/349 passing tests, including `animal_reproductive_history_section_test.dart`'s DG-expansion group. |
| SC-3 | Histórico reprodutivo e sanitário são ordenados por data decrescente | ✓ VERIFIED | Pre-existing ATF-level descending order preserved (regression-guarded by `animal_detail_screen_test.dart`'s `populated: renders one row per entry, in the order supplied (insemination date descending)`, untouched by the 08-02 extraction). DG-level ordering inside the new expansion reuses the single canonical `isLaterDg` comparator (`atf_repository.dart` lines 223-224, `grep -c isLaterDg` ≥ 2) and is proven by Y-coordinate comparison in `animal_reproductive_history_section_test.dart`'s expansion-order test. |
| SC-4 | Animal com baixa registrada mostra status, motivo e data de baixa de forma proeminente | ✓ VERIFIED | `_BaixaBanner` (`animal_detail_screen.dart:302-351`) is the first `ListView` child when `animal.deletedAt != null` — full-width `errorContainer`, `Icons.info_outline`, motivo+data+observação in one wrapping `Text`. The card's old status `_KvRow` and its locals were removed (single source of truth, D-15). Reason-label switch moved (not duplicated) into the banner — confirmed by `grep -c "'Vendido'"` etc. = 1 each. 6/6 "Banner de baixa" widget tests pass, including active-animal-shows-no-banner and banner-above-card ordering. |
| SC-5 | Layout funciona em mobile web (largura mínima 360px) | ✓ VERIFIED for phase-8-owned surfaces, with one flagged pre-existing exception (see Anti-Patterns) | `_KvRow` wraps its `Row` in a `LayoutBuilder`, stacking below 400px (`animal_detail_screen.dart:381-404`); proven overflow-free at 360px via `AnimalInfoCard`-scoped widget tests (`tester.takeException()` is null). `AnimalInfoCard`'s action-button `Row`→`Wrap` fix (found by this phase's own first 360px test) also verified overflow-free. **Known, out-of-scope exception:** `sanitary_history_section.dart`'s header row (`"Histórico Sanitário"` + `"Mostrar estornadas"` + `Switch`) overflows ~29px at 360px when the whole `AnimalDetailScreen` is pumped narrow — pre-existing, and D-37 locks this file to the D-04 retry-button diff only this phase, so it could not be fixed here (documented in 08-04-SUMMARY.md "Known Issues", recommended as a follow-up quick task). Not treated as a Phase 8 failure per this verification's scope instructions. |

**Score:** 5/7 truths verified (1 present-but-behavior-unverified, 1 explicitly deferred human UAT)

### Plan-Level Must-Haves (representative sample, cross-checked against source)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| D-01 | Single embedded PostgREST select resolves lot + paddock name; zero second request | ✓ VERIFIED | `LoteRepository.fetchLotWithPaddockName` (`lote_repository.dart:178`), `.select('*, paddocks!inner(name)')`; consumed once in `AnimalInfoCard`. |
| D-03 | No provider in this ficha is `keepAlive` | ✓ VERIFIED | `grep -rn keepAlive` across the phase's touched provider files returns only a doc comment, no actual usage. |
| D-04 | Both history blocks (sanitary, reproductive) render error text + scoped "Tentar novamente" | ✓ VERIFIED | `sanitary_history_section.dart` (both `error:` branches, added in commit `13e10e3`) and `animal_reproductive_history_section.dart` (`error:` branch) both invalidate the **family instance** (`...Provider(id)`), never the bare family. Invalidation-scope tests (sibling provider call-count stays at 1) pass in both new test files. |
| D-11/D-37 | Reproductive block extracted to a public, id-only, self-resolving widget mirroring the sanitary block; sanitary block untouched beyond its two error branches | ✓ VERIFIED | `AnimalReproductiveHistorySection` (`lib/features/reproducao/presentation/animal_reproductive_history_section.dart`, `ConsumerWidget`, `{required this.animalId}`). Mechanically confirmed via `git log`/`git show --unified=0 13e10e3` that the **only** phase-8 commit touching `sanitary_history_section.dart` is scoped to the two `error:` branches; `sanitary_application_repository.dart` never appears in any phase-8 commit's diff. |
| D-17 | Exact-number search for an archived animal bypasses the "Mostrar arquivados" toggle; partial match still respects it; badge always shown for archived rows | ✓ VERIFIED | `animais_screen.dart`'s `.where(...)` computes `isExactNumberMatch` and excludes archived rows only when `!_showArchived && ... && !isExactNumberMatch`; `_AnimalListTile`'s badge now gates on `isArchived` alone (the `showArchived` param was removed). 4/4 "D-17" widget tests pass. |
| D-08/D-09 | ATF row shows bull name + implantation date; ExpansionTile (2+ DGs only) reveals every DG, desc-sorted, with date/chip/observation | ✓ VERIFIED | `_ReproductiveHistoryRow` (lines 165-208) and `_DgSubRow` (lines 217-260) in `animal_reproductive_history_section.dart`; `ExpansionTile` gated on `entry.dgRecords.length > 1`; shared `_dgResultColors` helper used by both the collapsed chip and the sub-row chip (single occurrence of `DgResult.doubtful`, confirmed). |
| Backstop | DG observation inside the expansion wraps without overflow at 360px | ✓ VERIFIED | `animal_reproductive_history_section_test.dart`'s "360px width backstop" test mounts the section in isolation (avoiding the sanitary-section confound), expands, and asserts `tester.takeException()` is null plus the observation text is found. |
| Backstop | Baixa banner text wraps without overflow at 360px | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | See `behavior_unverified_items` in frontmatter — truncation is proven, overflow-absence is not directly asserted due to a confounding pre-existing sibling-widget overflow. |
| Unresolved (planner assumption, not a gap) | `AnimalInfoCard`'s lote/piquete rows keep a silent `"—"` fallback on error, with no retry affordance | ✓ HONORED AS DECLARED | `animal_detail_screen.dart` lines 200 and 227: `error: (e, st) => const Text('—')` for both rows, no `TextButton`. This matches the plan's explicit, recorded scope boundary (08-04-PLAN.md `<planner_assumptions>` #1 / UI-SPEC's single `unresolved` row) — verified as intentionally honored, not flagged as a gap. |
| Prohibitions (5 across 08-01/08-03/08-04) | "MUST NOT" statements — no keepAlive cache; error state never indistinguishable from empty; baixa animal never unreachable by number search | Flagged — descriptor-less, disposed `unverified` per policy | All five prohibition entries in the phase's plan frontmatter carry `verification: null` (no `check_*` descriptor authored) — this is the expected spec-less fallback state per the verification contract, not a defect. Independently spot-checked and each invariant holds in source: no `keepAlive` usage found; both history blocks render error text *and* a retry button together (never blank); D-17's exact-match bypass keeps archived animals reachable and always badged. |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/features/lotes/data/lote_repository.dart` | `LotWithPaddockName`, `fetchLotWithPaddockName`, `loteWithPaddockByIdProvider` | ✓ VERIFIED | All three present; old `loteByIdProvider`/`fetchLot` left intact (`grep -c "final loteByIdProvider"` = 1). |
| `lib/features/reproducao/data/atf_model.dart` | `ReproductiveHistoryEntry.dgRecords/bullName/implantationDate` | ✓ VERIFIED | All three fields present with correct types. |
| `lib/features/reproducao/data/atf_repository.dart` | `fetchReproductiveHistory` extended, `putIfAbsent` grouping, `isLaterDg` reused | ✓ VERIFIED | Confirmed via source read. |
| `lib/features/reproducao/presentation/animal_reproductive_history_section.dart` | NEW public `AnimalReproductiveHistorySection`, `ExpansionTile`, retry | ✓ VERIFIED | File exists, wired, tested in isolation. |
| `lib/features/animais/presentation/animal_detail_screen.dart` | `_BaixaBanner`, adaptive `_KvRow`, single lote+piquete watch, no reproductive rendering logic | ✓ VERIFIED | All present; reproductive classes fully removed (composed via import instead). |
| `lib/features/sanitario/presentation/sanitary_history_section.dart` | Retry buttons only, D-37 boundary held | ✓ VERIFIED | `git show --unified=0 13e10e3` confirms the diff is scoped to the two `error:` branches only. |
| `lib/features/animais/presentation/animais_screen.dart` | D-17 exact-match bypass | ✓ VERIFIED | Present and tested. |
| `test/widget/sanitary_history_section_test.dart` | NEW retry test file | ✓ VERIFIED | Exists, 4/4 pass. |
| `test/widget/animal_reproductive_history_section_test.dart` | NEW isolated section test file | ✓ VERIFIED | Exists, 16/16 pass. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `loteWithPaddockByIdProvider` | `LoteRepository.fetchLotWithPaddockName` | `ref.watch` | ✓ WIRED | Confirmed in source. |
| `AnimalInfoCard` | `loteWithPaddockByIdProvider(animal.lotId)` | single `ref.watch`, both lote/piquete rows share it | ✓ WIRED | `animal_detail_screen.dart:155`. |
| `fetchReproductiveHistory` → `dgsByAtf` | `ReproductiveHistoryEntry.dgRecords` | in-memory grouping, zero extra request | ✓ WIRED | Confirmed. |
| `AnimalDetailScreen` (ListView) | `AnimalReproductiveHistorySection(animalId)` | composition, D-18 order (banner→card→reprodutivo→sanitário) | ✓ WIRED | `animal_detail_screen.dart:107`. |
| retry `TextButton` (sanitary, both variants) | `ref.invalidate(sanitary...Provider(id))` | family-instance invalidation | ✓ WIRED | Confirmed, scoped (sibling provider call count stays 1 in tests). |
| retry `TextButton` (reproductive) | `ref.invalidate(reproductiveHistoryByAnimalProvider(animalId))` | family-instance invalidation | ✓ WIRED | Confirmed. |
| `AnimaisScreen` exact-match filter | archived toggle bypass | in-memory `.where(...)` | ✓ WIRED | Confirmed and tested. |

### Data-Flow Trace (Level 4)

Not applicable in the usual API-route sense — this is a 100% Flutter phase with no new backend surface. Data flow was traced structurally above (single embedded PostgREST select, in-memory DG grouping) and confirmed to reach real, already-authorized Supabase reads, not static/hardcoded values.

### Behavioral Spot-Checks / Test Baseline

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full test suite | `flutter test` | 349/349 passing (matches the stated baseline: 312 at phase start → 349 now) | ✓ PASS |
| D-37 boundary (sanitary file untouched outside error branches) | `git show --unified=0 13e10e3 -- lib/features/sanitario/presentation/sanitary_history_section.dart` | Diff contained entirely within the two `error:` branches | ✓ PASS |
| No `supabase/` files touched in any phase-8 commit | `git show --name-only <each task commit>` \| grep -i supabase | Empty for all 12 task commits | ✓ PASS |
| `sanitary_application_repository.dart` absent from phase diff | `git log --all -- lib/features/sanitario/data/sanitary_application_repository.dart` | Last touched in Phase 6 commits, none in Phase 8 | ✓ PASS |
| Isolated section/retry test files | `flutter test test/widget/animal_reproductive_history_section_test.dart test/widget/sanitary_history_section_test.dart test/widget/animais_screen_test.dart` | 34/34 passing | ✓ PASS |
| Deviation (a): `lote_form_dialog_test.dart` edited despite absent from 08-01's `files_modified` frontmatter | Documented in 08-01-SUMMARY.md "Auto-fixed Issues" | Confirmed present in that SUMMARY | ✓ DOCUMENTED |
| Deviation (b): Riverpod 3.x auto-retry disabled via `ProviderScope(retry: ...)` in retry test files | `grep -n "retry:" test/widget/sanitary_history_section_test.dart test/widget/animal_reproductive_history_section_test.dart` | 4 occurrences, test-only | ✓ DOCUMENTED |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| ANIM-03 | 08-01, 08-02, 08-03, 08-04, 08-05 | Usuário pode visualizar ficha consolidada do animal (dados, lote atual, histórico reprodutivo, histórico sanitário) | ✓ SATISFIED | All 5 SCs code-verified except SC-1's wall-clock leg (deferred human UAT). REQUIREMENTS.md already marks ANIM-03 `[x]` and maps it to "Phase 8 — Complete". No orphaned requirement IDs map to Phase 8 beyond ANIM-03. |

ANIM-05 (busca por número) is referenced as SC-1's entry path but is owned by Phase 3, not Phase 8 — the search field and debounce already exist in `animais_screen.dart` and are exercised by this phase's D-17 fix; not a Phase 8 deliverable and not a gap here.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `lib/features/sanitario/presentation/sanitary_history_section.dart` | ~285 | Header `Row` (title + "Mostrar estornadas" + `Switch`) has no wrap/flex protection; overflows ~29px at 360px width | ℹ️ Info (pre-existing, out of scope) | D-37 locks this file to the 08-03 retry-diff only; cannot be fixed within Phase 8. Recommended as a follow-up quick task (already recorded in 08-04-SUMMARY.md "Known Issues"). Not counted as a Phase 8 gap per this verification's explicit scope instructions. |

No `TBD`/`FIXME`/`XXX`/`TODO`/`HACK`/`PLACEHOLDER` markers found in any file this phase modified.

### Human Verification Required

See `human_verification` in frontmatter. Summary:

1. **SC-1 4G timing UAT (D-07)** — deferred by explicit user decision. Reproduction steps are fully documented in 08-04-SUMMARY.md and 08-04-PLAN.md Task 4. What's proven: 4 parallel requests instead of 5 with the waterfall killed. What's not proven: the <1s wall-clock target.
2. **Baixa banner overflow at 360px, isolated from the sanitary-section confound** — the current test proves no truncation but not mechanically no-overflow for the banner specifically, due to a pre-existing sibling overflow bug in the same screen tree.

### Gaps Summary

No FAILED truths. Every artifact, key link, and D-37/D-11/D-01/D-04/D-08/D-09/D-17 must-have that could be mechanically checked passed, including the hard D-37 boundary (verified independently via `git show --unified=0` rather than trusting the SUMMARY narrative) and the full 349-test suite. The phase is blocked from a clean `passed` status only by two items that are legitimately outside mechanical verification's reach right now:

- SC-1's <1s-under-4G wall-clock target — explicitly and knowingly deferred by the user, not failed.
- The baixa-banner-overflow backstop — real but incomplete test evidence (truncation proven, overflow-absence not isolated from a known unrelated sibling bug).

Both are routed to `human_needed`, not `gaps_found`, because no artifact is missing, stub, or unwired, and no truth mechanically failed.

---

*Verified: 2026-08-11T22:36:42Z*
*Verifier: Claude (gsd-verifier)*
