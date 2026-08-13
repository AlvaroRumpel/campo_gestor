---
phase: quick
plan: 260813-p10
verified: 2026-08-13T00:00:00Z
status: passed
score: 7/7 must-haves verified (gap único corrigido no commit ef6dcc4)
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "Nenhuma cor literal fora de AppColors nos widgets novos"
    status: failed
    reason: >
      AnimalDetailPanel (100% new file, Task 2) hardcodes a literal color
      `Color(0x4DA32D14)` for the "Dar baixa" icon-button border instead of an
      AppColors token, contradicting the plan's own Task 2 instruction ("Toda
      cor sai de AppColors; todo número sai de monoStyle.") and the explicit
      must_haves.prohibitions entry / success_criteria line ("zero cor literal
      fora de AppColors"). The value mirrors a pre-existing literal already in
      animal_detail_screen.dart's _ActionBar (introduced in an earlier phase,
      commit c874c21, before this plan), but copying an existing anti-pattern
      into a new widget does not satisfy a "zero literal in new widgets"
      prohibition. Not documented in SUMMARY.md's Deviations section.
    artifacts:
      - path: lib/features/animais/presentation/animal_detail_panel.dart
        issue: "Line 265: `side: const BorderSide(color: Color(0x4DA32D14))` — literal, not an AppColors token"
    missing:
      - "Add an AppColors token (e.g. AppColors.dangerBorderSubtle or similar, matching the existing 0x4DA32D14 danger-30%-alpha border) and reference it from animal_detail_panel.dart (and, ideally, from animal_detail_screen.dart's _ActionBar, which carries the same literal pre-existing debt)."
---

# Quick Task 260813-p10: Animais mestre-detalhe desktop Verification Report

**Task Goal:** Animais mestre-detalhe desktop: em ≥1024px a lista de animais vira tabela densa com filtros em chips e painel lateral 380px com resumo da ficha (lista continua viva); <1024px comportamento atual intacto.

**Verified:** 2026-08-13
**Status:** passed (após correção)
**Re-verification:** Gap único (cor literal em animal_detail_panel.dart:265) corrigido pelo orquestrador no commit ef6dcc4 — `AppColors.danger.withValues(alpha: 0.30)` no lugar do literal; analyze limpo, 6/6 testes do desktop passando. Débito pré-existente igual em animal_detail_screen.dart (_ActionBar) permanece — fora do escopo desta task.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Em >=1024px a tela de animais mostra uma tabela densa com cabeçalho mono uppercase, não a lista agrupada mobile | ✓ VERIFIED | `AnimaisScreen` build() branches on `constraints.maxWidth >= Breakpoints.rail` (animais_screen.dart:131-133, 318-369); `AnimaisTableView` header row uses `_HeaderText` with `monoStyle(size: 10.5, weight: w700, letterSpacing: 0.8)` and literal uppercase labels ('CATEGORIA', 'RAÇA', 'LOTE', 'PIQUETE', 'UA', 'REPRODUÇÃO', 'CADASTRO') (animais_table_view.dart:288-308). `animais_desktop_test.dart` test 1 (1440x900) asserts `AnimaisTableView` found, mobile search hint absent. Test passes. |
| 2 | Clicar numa linha da tabela abre o painel lateral de 380px e a tabela continua visível e utilizável | ✓ VERIFIED | `_buildRow`'s `InkWell(onTap: () => onSelect(a.id))` (animais_table_view.dart:450-454) → `_selectedAnimalIdProvider` → `AnimalDetailPanel(width: 380, ...)` conditionally rendered in the `Row` (animais_screen.dart:359-367; animal_detail_panel.dart:101-102 `Container(width: 380, ...)`). `animais_desktop_test.dart` tests 2 and 3 tap a row, assert panel appears, table (`AnimaisTableView`) stays present, and closing the panel keeps the table. All pass. |
| 3 | Em <1024px o comportamento é byte-a-byte o atual: lista agrupada, chips de categoria, switch de arquivados | ✓ VERIFIED | `<1024px` branch returns the exact pre-existing `Column` (animais_screen.dart:180-315), unedited. `git diff --name-only` across all 3 task commits shows `test/widget/animais_screen_test.dart` was NEVER touched, and the full suite (`flutter test`, 375/375) passes it unedited — the strongest available proof of zero regression. |
| 4 | A coluna Reprodução mostra Prenhe/Vazia/Duvidosa/DG pendente/Fora do ATF derivado de dados reais, com no máximo 2 queries extras por propriedade | ✓ VERIFIED | `AtfRepository.fetchAnimalReproStatusByProperty` issues exactly 2 Supabase selects (`animal_atf_memberships` then `dg_records`, both filtered by `property_id`) and delegates to the pure `reduceAnimalReproStatus` (atf_repository.dart:388-416). `animal_repro_status_test.dart` covers all 7 behavior cases from the plan (absent membership, dgPendente, prenhe, vazia, duvidosa, later-DG-wins tie-break, cross-ATF DG ignored) — all pass. Table + panel both consume the single `animalReproStatusByPropertyProvider` (animais_table_view.dart:133-135; animal_detail_panel.dart:95-99). |
| 5 | Animal com baixa aparece na tabela riscado e esmaecido com badge do motivo — nunca é escondido quando o escopo 'Com baixa' está ativo | ✓ VERIFIED | `_buildRow`: `Opacity(opacity: isArchived ? 0.5 : 1, ...)`, `TextDecoration.lineThrough` on `#N`, `StatusChip('Baixa · ${_baixaLabel(...)}', kind: danger)` (animais_table_view.dart:376-382, 408-416, 450-454). `animais_desktop_test.dart` test 5 confirms `#5`/`Baixa · Vendido` hidden under "Ativos" scope, shown under "Com baixa" scope. Passes. |
| 6 | A timeline do painel é o MESMO widget da ficha (zero duplicação de lógica de eventos) | ✓ VERIFIED | `grep -rln "_TimelineEvent\b" lib/` returns only `animal_timeline.dart` — one definition, repository-wide. `AnimalDetailPanel` and `AnimalDetailScreen` both import and render `AnimalTimelineCard`/`AnimalTimelineFilterChips` from that single file (animal_detail_panel.dart:218-233; animal_detail_screen.dart post-extraction). `test/widget/animal_detail_screen_test.dart` — untouched by this plan's commits — passes in full, proving the extraction was behavior-preserving. |
| 7 | flutter analyze limpo e toda a suíte de testes verde | ✓ VERIFIED | `flutter analyze --no-fatal-infos`: 3 pre-existing `info`-level findings unrelated to this plan's files, 0 errors/warnings. `flutter test`: **375 passed, 0 failed** (full workspace run). |

**Score:** 6/7 truths verified (the 7th must-have — the "zero literal color" prohibition tied to these truths — failed; see Gaps below)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/features/animais/presentation/animais_table_view.dart` | Dense desktop table | ✓ VERIFIED | Exists, substantive (522 lines), wired into `animais_screen.dart`, consumes real providers |
| `lib/features/animais/presentation/animal_detail_panel.dart` | 380px master-detail panel | ✓ VERIFIED | Exists, substantive (313 lines), wired; contains the one literal-color gap noted above |
| `lib/features/animais/presentation/animal_timeline.dart` | Shared timeline widget | ✓ VERIFIED | Exists (486 lines per commit diffstat), single definition site, consumed by both ficha and panel |
| `test/widget/animais_desktop_test.dart` | 6 behavior-block test cases | ✓ VERIFIED | All 6 plan `<behavior>` cases present and passing |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `AnimaisScreen` | `Breakpoints.rail` | `constraints.maxWidth >= Breakpoints.rail` | ✓ WIRED | No magic `1024` literal in widget logic (only in doc comments) |
| `AnimaisTableView` | `animalListByPropertyProvider` | shared `ref.watch` in parent, passed as `filtered`/`base`/`propertyAnimals` | ✓ WIRED | Zero new fetch — same provider instance as mobile list |
| `AnimaisTableView` / `AnimalDetailPanel` | `animalReproStatusByPropertyProvider` | both `ref.watch` the same provider | ✓ WIRED | Single status source, no drift |
| `AnimalDetailPanel` | `AnimalTimelineCard` | direct widget composition | ✓ WIRED | `collapsedCount: 5` vs ficha's default `10` |
| `AnimalDetailPanel` | `AnimalEditDialog`/`MoverAnimalDialog`/`BaixaDialog` | `showAdaptiveForm` + provider invalidation | ✓ WIRED | Same dialogs, same invalidation set as the row's `PopupMenuButton` in the table |

### Prohibitions

| Prohibition | Status | Evidence |
|-------------|--------|----------|
| Nenhuma mudança de comportamento em larguras <1024px | ✓ RESOLVED | `animais_screen_test.dart` untouched, passing |
| Não adicionar dependência nova; data_table_2 permanece não importado | ✓ RESOLVED | `grep -rn "DataTable2" lib/` empty; `pubspec.yaml`/`pubspec.lock` untouched across all 3 task commits |
| Nenhuma cor literal fora de AppColors nos widgets novos | ✗ FAILED | `Color(0x4DA32D14)` literal in `animal_detail_panel.dart:265` (new file) — see Gaps |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full test suite | `flutter test` | 375 passed, 0 failed | ✓ PASS |
| Static analysis | `flutter analyze --no-fatal-infos` | 3 unrelated info-level findings, 0 errors/warnings | ✓ PASS |
| No new dependency | `grep -rn "DataTable2" lib/` | no results | ✓ PASS |
| Mobile regression proof | `git diff --name-only` across the 3 task commits | `test/widget/animais_screen_test.dart` not in the list | ✓ PASS |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `lib/features/animais/presentation/animal_detail_panel.dart` | 265 | Hardcoded `Color(0x4DA32D14)` literal instead of an `AppColors` token | ⚠️ Warning | Violates an explicit plan prohibition and success criterion; purely cosmetic/style debt, does not affect functional behavior (mirrors an already-existing pattern in the unmodified ficha `_ActionBar`) |

### Requirements Coverage

No formal `requirements:` IDs declared in PLAN frontmatter (`requirements: []`); coverage tracked via SUMMARY.md's `coverage:` block (D1/D2/D3), all `status: pass`. No orphaned REQUIREMENTS.md entries apply — this is a quick task, not a numbered roadmap phase.

## Gaps Summary

Functionally the phase goal is fully achieved: the desktop master-detail table+panel exists, is wired to real data with a bounded 2-query reproductive-status fetch, the timeline is a single shared implementation, the sub-1024px path is provably untouched (its test file was never edited across any of the 3 commits and still passes), and the entire 375-test suite plus `flutter analyze` are clean.

The one gap is narrow and cosmetic: `AnimalDetailPanel` — a wholly new file — contains one hardcoded color literal (`Color(0x4DA32D14)`, the "Dar baixa" button's border) instead of routing through `AppColors`, which directly contradicts both the plan's Task 2 action text ("Toda cor sai de AppColors") and the explicit `must_haves.prohibitions` / `success_criteria` line demanding zero literal colors in the new widgets. It was not caught by `flutter analyze` (no lint rule enforces this project convention) and was not surfaced in SUMMARY.md's Deviations section. The value matches a pre-existing literal already present (before this plan) in `animal_detail_screen.dart`'s `_ActionBar`, suggesting the executor mirrored existing debt into new code rather than introducing new debt from scratch — but the prohibition as written targets "widgets novos" specifically, so this still counts as a failure of that must-have.

**This looks intentional/low-risk.** To accept this deviation as-is, add to VERIFICATION.md frontmatter:

```yaml
overrides:
  - must_have: "Nenhuma cor literal fora de AppColors nos widgets novos"
    reason: "Single literal mirrors a pre-existing (pre-plan) border style already used in the unmodified ficha _ActionBar; cosmetic only, no functional impact."
    accepted_by: "<your name>"
    accepted_at: "<ISO timestamp>"
```

Otherwise, the fix is a one-line addition to `app_colors.dart` (a new token alongside `dangerChipBg`, e.g. `dangerBorderSubtle = Color(0x4DA32D14)`) plus swapping the two literal usages (`animal_detail_panel.dart:265` and, optionally, `animal_detail_screen.dart:385` to close the debt at the source) for that token.

---

*Verified: 2026-08-13*
*Verifier: Claude (gsd-verifier)*
