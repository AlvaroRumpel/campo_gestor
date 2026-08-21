# Phase 8: Animal Dossier Consolidation - Research

**Researched:** 2026-08-11
**Domain:** Flutter/Riverpod UI consolidation over existing Supabase-backed data (no new SQL)
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Consulta e performance (SC-1)**
- **D-01:** Matar só o waterfall, mantendo os providers separados. O piquete passa a vir embutido na query do lote (embed PostgREST) em vez de ser um segundo request disparado depois que `loteByIdProvider` resolve. 5 requests viram 4, todos em paralelo. O contrato D-37 da Phase 6 fica intacto. RPC consolidada foi apresentada e recusada.
- **D-02:** Render progressivo — o card do animal aparece assim que `animalByIdProvider` resolve; cada bloco de histórico mostra seu próprio spinner e preenche quando chega. Tela de loading única e skeleton foram recusados.
- **D-03:** Sem cache — auto-dispose do Riverpod 3.x mantido. `keepAlive` foi apresentado e recusado.
- **D-04:** Retry por bloco. Cada seção que falha mostra a mensagem + ação de recarregar só aquele provider. Ortogonal à retry policy app-wide do G-06-9.
- **D-05:** Sem pull-to-refresh.
- **D-06:** Truncamento assimétrico mantido: sanitário corta em 10 + "Ver todas", reprodutivo mostra tudo.
- **D-07:** SC-1 vira evidência via UAT humano com throttle 4G (DevTools "Fast 4G"), abrindo a ficha por busca de número e cronometrando. Teste automatizado de tempo foi recusado (`integration_test` não roda em web).

**Histórico reprodutivo (SC-2)**
- **D-08:** Todos os DGs, em linha expansível. A linha do ATF continua resumida (último DG); tocar na seta expande e lista todos os DGs.
- **D-09:** Cada linha de ATF mostra também touro do ATF e data de implantação; cada DG expandido mostra data + resultado + observação do DG.
- **D-10:** DGs vêm na mesma query. `fetchReproductiveHistory` embute os `dg_records` do animal em cada ATF.
- **D-11:** O bloco reprodutivo é extraído para `lib/features/reproducao/presentation/`, público, espelhando `AnimalSanitaryHistorySection`.

**Baixa (SC-4)**
- **D-12:** Banner no topo da ficha, acima do card, em `errorContainer` com ícone.
- **D-13:** O banner traz motivo + data + observação da baixa (a observação já vem anexada pelo CR-01 da Phase 5).
- **D-14:** Mesmo visual para os três motivos, mudando só o texto.
- **D-15:** A linha "Status" sai do card.
- **D-16:** Nada muda nos históricos para animal com baixa — reprodutivo e sanitário continuam completos e navegáveis.
- **D-17:** A busca por número encontra animal com baixa, sempre — a busca por número exato passa por cima do toggle "Mostrar arquivados".

**Layout e organização (SC-5)**
- **D-18:** Ordem mantida: card → reprodutivo → sanitário.
- **D-19:** Blocos sempre abertos, nunca colapsáveis.
- **D-20:** Bloco vazio aparece com mensagem.
- **D-21:** `_KvRow` empilha abaixo de ~400px de largura (`LayoutBuilder`).
- **D-22:** Os blocos de histórico continuam read-only para todo papel. Nenhuma ação de registrar DG ou aplicação sanitária a partir da ficha; nenhum atalho de navegação para esses fluxos.

**Testes e execução**
- **D-23:** Widget tests dos blocos + teste de largura 360px. Sem pgTAP — nenhuma linha de SQL muda nesta fase.
- **D-24:** 3 planos em 2 waves. W1 (paralelo): (a) camada de dados — embed do piquete + DGs completos + campos novos; (b) extração do bloco reprodutivo. W2: ficha (banner, expansão de DGs, retry por bloco, `_KvRow` adaptativo) + widget tests. Não há plano bloqueante de migration.

### Claude's Discretion
- Forma exata do banner de baixa (widget próprio vs `MaterialBanner` vs `Container` estilizado) e sua posição precisa em relação ao card.
- Mecânica da expansão dos DGs (`ExpansionTile` vs estado local com `AnimatedSize`) e o formato exato da sub-linha de DG.
- Limiar exato do `_KvRow` adaptativo (~400px é referência, não contrato) e se o breakpoint é lido de `LayoutBuilder` ou `MediaQuery`.
- Forma do embed do piquete no lote (novo método no `LoteRepository` vs estender `loteByIdProvider`) — desde que não crie um segundo request.
- Nomes de arquivo e classe do bloco reprodutivo extraído (`AnimalReproductiveHistorySection` é sugestão, simétrico ao sanitário).
- Como a busca por número exato passa por cima do toggle de arquivados (D-17): filtro na tela vs provider dedicado.
- Onde mora a ação de retry por bloco (botão inline vs `TextButton` abaixo da mensagem) — desde que invalide só o provider daquele bloco.
- Se os widget tests de 360px usam `TestWidgetsFlutterBinding` com `physicalSize` fixo ou `MediaQuery` override.

### Deferred Ideas (OUT OF SCOPE)
- Registrar DG ou aplicação sanitária a partir da ficha do animal (recusado no D-22).
- Atalhos de navegação da ficha para os fluxos de DG e aplicação (recusados junto com o D-22).
- Exportar / compartilhar a ficha (PDF, print, link) — nenhum REQ pede; relatórios são pós-MVP.
- Pull-to-refresh (recusado no D-05).
- `keepAlive` / cache dos providers da ficha (recusado no D-03).
- RPC/view consolidada da ficha (recusada no D-01) — saída se o UAT de 4G (D-07) reprovar.
- Corte + "Ver todos" no histórico reprodutivo (recusado no D-06).
- Skeleton loading (recusado no D-02).
- Ordenação dos blocos por recência (recusada no D-18).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ANIM-03 | Usuário pode visualizar ficha consolidada do animal (dados, lote atual, histórico reprodutivo, histórico sanitário) | All five success criteria mapped to existing code + specific gaps: SC-1 → Pattern 1 (piquete embed, D-01) + Validation Architecture (D-07 manual UAT); SC-2 → Pattern 2 (DG embed, D-10) + Code Examples (extracted section, D-08/D-11); SC-3 → already satisfied, see State of the Art / existing test coverage; SC-4 → Code Examples (baixa banner, D-12/D-13); SC-5 → Pattern 4 (`_KvRow` adaptive, D-21) + Pitfall 4 |
</phase_requirements>

## Summary

This phase does not build a new screen — `AnimalDetailScreen` (`lib/features/animais/presentation/animal_detail_screen.dart`) already composes `AnimalInfoCard`, `_ReproductiveHistorySection`, and `AnimalSanitaryHistorySection` end to end, and SC-3 (descending order in both history blocks) is already satisfied in the shipped code `[VERIFIED: codebase read]`. The work is five surgical gap-closures against the five success criteria, all scoped and decided in `08-CONTEXT.md`: kill the lote→piquete waterfall (D-01), surface every DG per ATF instead of just the latest (D-08/D-09/D-10), extract the reproductive block to its own public widget (D-11), replace the buried status chip with a top-of-screen baixa banner (D-12..D-15), and make `_KvRow` stack vertically under ~400px (D-21). Zero migrations, zero new packages, zero RLS changes — the first phase in the project's history where the planner should not create a blocking DB-apply plan.

Every one of the 24 decisions in `08-CONTEXT.md` is locked; this research's job is to ground each decision against the actual current code (line-accurate) and flag the two places where the codebase has no existing precedent to copy: `ExpansionTile`-style row expansion (D-08) and viewport-width-driven layout switching (D-21) are both first uses of their respective Flutter mechanism in this repository.

**Primary recommendation:** Treat this as 3 plans / 2 waves exactly as D-24 specifies — W1(a) data layer (piquete embed + DG-complete reproductive history), W1(b) reproductive-block extraction, W2 UI (banner, DG expansion, retry, adaptive `_KvRow`) + widget tests — and do not introduce a plan for "apply migration," since none exists this phase.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Ficha rendering (card, banner, sections) | Frontend (Flutter widget tree) | — | Pure presentation; all three sections already exist as widgets |
| Lote + piquete embed query | API / Backend (PostgREST embed via Supabase client) | Frontend (Riverpod provider) | Read is a single PostgREST nested-select; no new SQL object needed — RLS already covers `lots`/`paddocks` |
| DG history per ATF | API / Backend (PostgREST embed) | Frontend (repository mapping) | `dg_records` already has a SELECT policy scoped to the animal's property; embedding is a read-shape change only |
| Sanitary snapshot lookup | API / Backend (existing JSONB containment query, Phase 6) | — | **Untouched this phase** — D-37 contract forbids touching `sanitaryHistoryByAnimalProvider`/its repository method |
| Baixa status display | Frontend (derived from `Animal.deletedAt`/`baixaReason`/`baixaDate`/`observation`) | — | All fields already present on the `Animal` model; no query change |
| Mobile-width layout switching | Frontend (`LayoutBuilder`/`MediaQuery` in `_KvRow`) | — | Client-only responsive behavior |

## Standard Stack

### Core (already in `pubspec.yaml` — no additions)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter_riverpod | `>=3.0.0 <4.0.0` `[VERIFIED: pubspec.yaml]` | State management, `FutureProvider.family`, auto-dispose | Locked project-wide since Phase 0 |
| supabase_flutter | `^2.12.0` `[VERIFIED: pubspec.yaml]` | Postgres access via PostgREST | Locked; `AnimalRepository`/`LoteRepository`/`AtfRepository` already wrap it |
| freezed_annotation / json_serializable | `^3.0.0` / `^4.11.0` `[VERIFIED: pubspec.yaml]` | Immutable models (`Animal`, `Lot`, `AtfBatch`, `DgRecord`) | Locked; `ReproductiveHistoryEntry` extending with new fields follows the existing plain-class (non-Supabase-row) convention already used by `AtfMembershipView`/`LotWithPaddockCount` |
| go_router | `^17.2.0` `[VERIFIED: pubspec.yaml]` | Root-level routes `/atf/:atfId`, `/aplicacoes/:id`, `/animais/:id` | Locked; no new routes needed this phase |
| intl | `^0.20.0` `[VERIFIED: pubspec.yaml]` | `DateFormat('dd/MM/yyyy', 'pt_BR')` in both history sections | Locked |

### Supporting
None to add. This phase installs nothing new — confirmed by cross-referencing `08-CONTEXT.md` ("Fase 100% Flutter — nenhuma migration, nenhum objeto de banco novo") against `pubspec.yaml`, which already carries every package this phase touches.

### Alternatives Considered
Not applicable — CONTEXT.md already closed every stack-level decision (RPC vs. embed, cache vs. no-cache, skeleton vs. progressive render). See Decisions D-01 through D-24 for the recorded trade-offs; this research does not reopen them.

**Installation:** none.

## Package Legitimacy Audit

**Not applicable.** No packages are added, upgraded, or removed in this phase. Every dependency this phase touches (`flutter_riverpod`, `supabase_flutter`, `freezed_annotation`, `go_router`, `intl`) is already installed and in production use across Phases 0–7.

## Architecture Patterns

### System Architecture Diagram

```
User (vet, mobile browser, 4G)
        │
        ▼
 AnimaisScreen search (#127) ──or── AnimaisScreen list tap
        │
        ▼
 GoRouter → /animais/:id → AnimalDetailScreen.build()
        │
        ├─▶ animalByIdProvider(id) ───────────────┐
        │        (Supabase: animals by id)        │
        │                                          ▼
        │                              AnimalInfoCard renders
        │                              as soon as this resolves (D-02)
        │                                          │
        │        ┌─────────────────────────────────┼──────────────────────┐
        │        ▼                                  ▼                      ▼
        │  loteWithPaddock         reproductiveHistoryByAnimal   sanitaryHistoryByAnimal
        │  ByIdProvider(lotId)     Provider(animalId)            Provider(animalId)
        │  (NEW, D-01: 1 request   (EXTENDED, D-10: embeds       (UNCHANGED, D-37 contract —
        │   embedding paddocks     dg_records per ATF in the      Phase 6's GIN/jsonb_path_ops
        │   via PostgREST select)  same select)                   containment query)
        │        │                                  │                      │
        │        ▼                                  ▼                      ▼
        │  AnimalInfoCard's        AnimalReproductiveHistorySection  AnimalSanitaryHistorySection
        │  "Lote atual" /          (NEW public widget, D-11)         (existing, only gets D-04 retry)
        │  "Piquete atual" rows    · one row per ATF                 · corte em 10 + "Ver todas"
        │                          · tap → expand all DGs (D-08)
        │                          · tap row → /atf/:atfId
        │
        └─▶ if animal.deletedAt != null: baixa banner (D-12..D-15)
             rendered ABOVE AnimalInfoCard, sourced from the same
             animalByIdProvider payload — zero extra request
```

All four leaf providers (`animalByIdProvider`, the new lote+paddock provider, `reproductiveHistoryByAnimalProvider`, `sanitaryHistoryByAnimalProvider`) fire in parallel from `AnimalDetailScreen`/`AnimalInfoCard`'s `build()` — Riverpod resolves independent `ref.watch` calls concurrently, there is no `await` chain between them once the piquete embed removes the lote→piquete waterfall. Each renders progressively (D-02): the screen never gates on the slowest block.

### Recommended Project Structure

```
lib/features/
├── animais/presentation/
│   └── animal_detail_screen.dart   # AnimalDetailScreen, AnimalInfoCard, _KvRow (adaptive),
│                                    # baixa banner — loses _ReproductiveHistorySection (moved out)
├── reproducao/
│   ├── data/
│   │   ├── atf_model.dart          # ReproductiveHistoryEntry gains dgRecords/bullName/implantationDate
│   │   └── atf_repository.dart     # fetchReproductiveHistory embeds dg_records
│   └── presentation/
│       └── animal_reproductive_history_section.dart   # NEW FILE (D-11) — public widget,
│                                    # mirrors sanitary_history_section.dart's shell/shape
└── lotes/data/
    └── lote_repository.dart        # new fetchLotWithPaddockName / loteWithPaddockByIdProvider (D-01)
```

### Pattern 1: PostgREST nested-select embed to kill a waterfall (D-01)

**What:** Replace two sequential `FutureProvider.family` reads (lote, then piquete once lote resolves) with a single embedded select.
**When to use:** Any time a screen needs a parent row plus one FK-joined child row and currently fetches them as two dependent requests.
**Precedent already in this codebase** — copy this exact shape, do not invent a new one:
```dart
// Source: lib/features/animais/data/animal_repository.dart (fetchAnimalsByProperty, in-repo, VERIFIED)
final rows = await _service.client
    .from('animals')
    .select('*, lots!inner(name, paddock_id, paddocks!inner(id, name))')
    .eq('property_id', propertyId);
```
Applied to `LoteRepository` for D-01, the equivalent single-lot read is:
```dart
// New method, mirrors LotWithPaddockCount's "wrapper class, not a Supabase row" convention
// (lib/features/lotes/data/lote_repository.dart, LotWithPaddockCount)
Future<LotWithPaddockName?> fetchLotWithPaddockName(String id) async {
  final row = await _service.client
      .from('lots')
      .select('*, paddocks!inner(name)')
      .eq('id', id)
      .isFilter('deleted_at', null)
      .maybeSingle();
  if (row == null) return null;
  final map = row;
  final paddockJson = map['paddocks'] as Map<String, dynamic>;
  final clean = Map<String, dynamic>.from(map)..remove('paddocks');
  return LotWithPaddockName(
    lot: Lot.fromJson(clean),
    paddockName: paddockJson['name'] as String,
  );
}
```
`AnimalInfoCard` then watches one new family provider instead of `loteByIdProvider` + `paddockByIdProvider(paddockId)` chained — the paddock tap target still uses `lot.paddockId` (already on `Lot`), so no route logic changes, only the data-fetch shape.

### Pattern 2: Embedding a one-to-many child collection for expansion (D-10)

**What:** `fetchReproductiveHistory` currently issues two separate queries (`animal_atf_memberships` joined to `atf_batches`, and a flat `dg_records` list) then reduces DG records to "most recent per ATF" in Dart. D-10 keeps it a single logical fetch (still fine as 2 Supabase calls — that part of the shape is unchanged) but stops discarding all-but-the-latest DG; `ReproductiveHistoryEntry` must carry the full `List<DgRecord>` per ATF so the UI can expand it.
**Code change shape:**
```dart
// lib/features/reproducao/data/atf_repository.dart — fetchReproductiveHistory (VERIFIED, current code read)
// dgRecords is already fetched in full (`dgRows`) and grouped as lastDgByAtf.
// D-10 requires ALSO grouping the full list per ATF, not just the max:
final dgsByAtf = <String, List<DgRecord>>{};
for (final dg in dgRecords) {
  dgsByAtf.putIfAbsent(dg.atfBatchId, () => []).add(dg);
}
// then, per entry:
dgRecords: (dgsByAtf[atfBatchId] ?? const [])
    ..sort((a, b) => b.examDate.compareTo(a.examDate)), // desc per SC-3
```
This is additive to the existing `lastDgByAtf` computation (kept for the collapsed-row summary) — no removal of current logic, only a second grouping pass over data already in memory.

### Pattern 3: Section-local retry after auto-retry exhausts (D-04)

**What:** The app already has a global retry policy (`main.dart`, `providerRetryPolicy`, G-06-9) wired into `ProviderScope(retry: providerRetryPolicy)` — every provider gets `ProviderContainer.defaultRetry`'s exponential backoff automatically before the error ever reaches `.when(error: ...)`. D-04 is the layer *after* that: once the AsyncValue actually lands in `error`, the fix is a manual `ref.invalidate` scoped to just that provider family instance.
```dart
// Confirmed pattern via Context7 (rrousselgit/riverpod docs) [CITED: github.com/rrousselgit/riverpod/website/docs/tutorials/first_app.mdx]
error: (err, st) => Column(
  children: [
    Text('Erro ao carregar histórico sanitário.'),
    TextButton(
      onPressed: () => ref.invalidate(sanitaryHistoryByAnimalProvider(widget.animalId)),
      child: const Text('Tentar novamente'),
    ),
  ],
),
```
Critical detail: `ref.invalidate(providerFamily(id))` — invalidating the *family instance*, not the bare family — is what keeps the blast radius to one block, matching D-04's "só aquele provider" requirement.

### Pattern 4: Width-driven layout switch (D-21) — no existing precedent in this repo

**What:** `LayoutBuilder` reading `constraints.maxWidth` inside `_KvRow`, switching from `Row` (label 120px + value) to `Column` (label above, value below) below the chosen breakpoint.
**Why `LayoutBuilder` over `MediaQuery`:** `_KvRow` is nested inside `AnimalInfoCard`'s `Card` → `Padding`, which is itself inside a `ListView` with 16px horizontal padding. `MediaQuery.of(context).size.width` reads the *screen* width, not the row's actual available width — on a wider viewport with side navigation (the app already has an adaptive `NavigationRail`/`NavigationBar` shell per Phase 0), the content column is narrower than the screen. `LayoutBuilder` measures the actual constraint `_KvRow` receives, which is what determines whether "label 120px + value" visually cramps. `[ASSUMED — general Flutter layout guidance, not verified against this specific AppShell's constraint-narrowing behavior this session; low risk since either approach is a small, isolated diff to a private widget]`.
```dart
class _KvRow extends StatelessWidget {
  const _KvRow({required this.label, required this.value});
  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 400; // D-21: ~400px reference, not contract
        final labelWidget = Text(label, style: /* existing style */);
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [labelWidget, const SizedBox(height: 2), value],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 120, child: labelWidget),
            const SizedBox(width: 8),
            Expanded(child: value),
          ],
        );
      },
    );
  }
}
```

### Anti-Patterns to Avoid
- **Consolidated RPC/view for the ficha** — explicitly recused in D-01 and re-recorded as a Deferred Idea; do not propose this even as an optimization, it breaks the D-37 contract (`AnimalSanitaryHistorySection` must stay query-autonomous) and needs a migration this phase deliberately has none of.
- **Collapsing history sections by default** — recused in D-19; blocks are always-open. Do not add an `ExpansionTile` at the *section* level — the expansion in D-08 is scoped to individual DG rows *within* the reproductive section, not the section itself.
- **`keepAlive` on any ficha provider** — recused in D-03; every provider here stays default-`autoDispose`.
- **Touching `sanitary_history_section.dart`'s query or row-rendering functions** — only the retry affordance (D-04) may be added there; `_buildAnimalRow`, `visibleApplications`, `sanitaryHistoryByAnimalProvider` and its repository method are locked by the D-37 (Phase 6) contract this phase inherits.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Parallel data loading with per-section loading/error states | A custom "combine 4 futures" coordinator/`FutureGroup` | Independent `ref.watch(xProvider)` calls inside each section widget, each rendering its own `.when()` | Riverpod already parallelizes independent `watch` calls; each section already does this (D-02 says this is *already* the behavior) — a coordinator would be strictly more code for identical behavior |
| Retry-after-failure UI | A custom retry-state `StateNotifier` per section | `ref.invalidate(providerFamily(id))` inside the existing `error:` builder | `FutureProvider.family` auto-dispose + `invalidate` already gives "refetch just this instance" for free; a `StateNotifier` would duplicate what the family provider already tracks |
| Row expansion state (DGs per ATF) | Bespoke boolean-map-in-Riverpod-provider for "which rows are expanded" | Local `StatefulWidget` state (a `Set<String>` of expanded ATF ids, or per-row `ExpansionTile`) | Expansion state is pure UI/ephemeral (not shared across widgets, not persisted) — Riverpod state would be over-scoped for something `setState` already handles correctly, and the codebase has no precedent for provider-backed UI-only toggles (the sanitary section's `_showReversed` is already plain `setState`, confirming the local convention) |
| Responsive breakpoint detection | A custom `ResponsiveBuilder`/breakpoint enum system | `LayoutBuilder` directly in `_KvRow` | Single-widget, single-breakpoint need — a general-purpose responsive framework is unjustified for one row type in one screen |

**Key insight:** every "don't hand-roll" item above resolves to "the codebase already has the pattern next door — copy it," not "reach for a new package." This phase's discipline is reuse, not tooling.

## Common Pitfalls

### Pitfall 1: Breaking the D-37 contract by touching sanitary query/render code
**What goes wrong:** A plan modifies `sanitaryHistoryByAnimalProvider`, its repository method, or `_buildAnimalRow`/`visibleApplications` "while in the area" (e.g., to add a loading-skeleton or align styling with the new reproductive block).
**Why it happens:** The two history sections are visually adjacent and structurally similar, tempting a "make them consistent" pass.
**How to avoid:** The only permitted edit to `sanitary_history_section.dart` this phase is adding the D-04 retry button inside the existing `error:` branches of both `_AnimalSanitaryHistorySectionState` and `_LoteSanitaryHistorySectionState`. Everything else in that file is out of scope.
**Warning signs:** A diff touching `sanitary_application_repository.dart` or changing the JSONB containment query shape.

### Pitfall 2: `!inner` vs. plain embed silently dropping rows
**What goes wrong:** `paddocks!inner(name)` in the new lote+paddock embed will silently exclude the lot row entirely from the result if the paddock has been soft-deleted (`deleted_at IS NOT NULL`) but the FK still points at it — `!inner` performs an actual SQL INNER JOIN, and PostgREST/RLS row filtering applies to the joined table too.
**Why it happens:** `!inner` is required to *shape* the JSON as a nested object rather than an array (PostgREST default for to-one without `!inner` is still an array unless FK cardinality is inferred), but it also changes JOIN semantics.
**How to avoid:** Since `lot.paddockId` is a NOT NULL FK and paddocks are essentially never hard/soft-deleted while a lot still references them in this domain, `!inner` matches the existing precedent (`fetchAnimalsByProperty`, `fetchLotsWithCountByProperty` both already use `!inner` for the identical parent→paddock relationship) — reuse it, don't invent a `LEFT JOIN`-shaped alternative. Flag this only if a plan discovers stale-paddock lots in practice.
**Warning signs:** `AnimalInfoCard`'s "Piquete atual" row goes from showing "—" (current graceful-null behavior) to the *entire* "Lote atual" row disappearing too, once the embed lands — that would indicate `!inner` excluded the lot row, not just the paddock field.

### Pitfall 3: The "5→4 requests" claim (D-01/SC-1) is not unit-testable in this codebase's existing pattern
**What goes wrong:** A plan tries to write an automated test asserting "exactly 4 network calls fire" and gets stuck, because `LoteRepository`/`AtfRepository` tests in this project are shallow "contract" tests (`expect(repo.method, isA<Function>())`, see `test/features/lotes/lote_repository_test.dart`), not full Supabase-client mocks with call-counting.
**Why it happens:** Mocking the full PostgREST query-builder chain (`.from().select().eq().isFilter().order()`) is explicitly noted in this codebase as "brittle" (comment in `lote_repository_test.dart`), so the project has never done it.
**How to avoid:** SC-1's evidence is D-07 — a human UAT with DevTools "Fast 4G" throttle, timing the ficha open. Do not plan an automated request-count assertion; it would be new test infrastructure this phase's decisions explicitly did not request (D-23 scopes tests to widget tests + 360px only, "Sem pgTAP").
**Warning signs:** A plan task titled anything like "add network-call-count test" — reject it, redirect to the D-07 UAT checkpoint.

### Pitfall 4: `LayoutBuilder` breakpoint interacting badly with `ListView`'s intrinsic width
**What goes wrong:** `AnimalInfoCard` sits inside a `ListView` (unconstrained cross-axis by default matches parent width) inside a `Scaffold` body. `LayoutBuilder`'s `constraints.maxWidth` inside `_KvRow` will reflect the `Card`'s padded content width, which is correct — but if a future refactor wraps the card in something that gives it `IntrinsicWidth` or unconstrained horizontal sizing, `LayoutBuilder` will throw or report `double.infinity`.
**How to avoid:** Keep `_KvRow` a direct child of `Card > Padding > Column` as it is today; don't introduce `Wrap` or `IntrinsicWidth` around it.
**Warning signs:** A `LayoutBuilder` error in the widget test output about unbounded constraints — catch this in the 360px widget test itself (D-23) before it reaches UAT.

### Pitfall 5: Forgetting the archived-toggle bypass is search-only, not list-wide (D-17)
**What goes wrong:** A plan makes `AnimaisScreen`'s exact-number search bypass `_showArchived` by changing the underlying provider call (e.g., always passing `includeArchived: true` to `fetchAnimalsByProperty`), which the codebase already does at the provider level (`animalListByPropertyProvider` always fetches `includeArchived: true` and filters in-memory — confirmed in `animal_repository.dart`). The risk is instead in the *in-memory filter* inside `_AnimaisScreenState.build()`: `if (!_showArchived && a.deletedAt != null) return false;` unconditionally excludes archived animals regardless of query match, so an exact-number match on an archived animal is currently swallowed by this line even though the data is already in memory.
**How to avoid:** D-17's fix is a filter-logic change in `animais_screen.dart`'s `.where()` clause: when `_query` is a non-empty exact numeric match, skip the `_showArchived` exclusion for that one animal. This is a UI-only change — no provider signature changes needed, since `includeArchived: true` is already always fetched.
**Warning signs:** A plan proposing a new repository method or provider parameter for this — unnecessary, the data is already client-side.

## Code Examples

### Extracted reproductive section shell (D-11), mirroring the sanitary section's public-widget contract
```dart
// Target shape for lib/features/reproducao/presentation/animal_reproductive_history_section.dart
// Mirrors AnimalSanitaryHistorySection's D-37 "takes nothing but an animal id" contract
// (source: lib/features/sanitario/presentation/sanitary_history_section.dart, VERIFIED)
class AnimalReproductiveHistorySection extends ConsumerWidget {
  const AnimalReproductiveHistorySection({super.key, required this.animalId});
  final String animalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(reproductiveHistoryByAnimalProvider(animalId));
    // ... same outlined-Card shell (borderRadius 12, outline 38%, colorScheme.surface)
    // as _ReproductiveHistorySection today — body only gains the per-row expansion (D-08)
  }
}
```
Composition site (`animal_detail_screen.dart`) changes from `_ReproductiveHistorySection(animalId: animal.id)` to `AnimalReproductiveHistorySection(animalId: animal.id)` with an added import — the widget test's existing router harness (`animal_detail_screen_test.dart`, `_buildRoutedScreen`) needs its `reproductiveHistoryByAnimalProvider` override moved/re-verified against the new import path but the override target (the same provider) is unchanged.

### Baixa banner sourced from data already on `Animal` (D-12/D-13)
```dart
// All fields already exist on Animal (VERIFIED: animal_detail_screen.dart already
// reads animal.deletedAt, animal.baixaReason, animal.baixaDate, animal.observation)
if (animal.deletedAt != null)
  Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Icon(Icons.info_outline, color: colorScheme.onErrorContainer),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            // reasonLabel switch already exists in AnimalInfoCard (lines ~169-174,
            // per 08-CONTEXT.md D-13 "mover para o banner, não duplicar")
            '$reasonLabel em ${dateFmt.format(animal.baixaDate!)}'
            '${animal.observation != null ? " — ${animal.observation}" : ""}',
            style: TextStyle(color: colorScheme.onErrorContainer),
          ),
        ),
      ],
    ),
  ),
```
Note per D-13: the observation shown here is the *whole* `animal.observation` field, which per Phase 5's CR-01 already has the baixa note appended (not overwritten) — so this single field carries both any pre-existing free-text observation and the baixa-specific note, concatenated. Do not attempt to parse or split it.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| `_ReproductiveHistorySection` private, inline in `animal_detail_screen.dart` | `AnimalReproductiveHistorySection` public, own file under `reproducao/presentation/` | This phase (D-11) | Testable in isolation; symmetric with `AnimalSanitaryHistorySection` |
| Status shown as a small chip inside `AnimalInfoCard`'s last row | Status shown as a full-width banner above the card | This phase (D-12/D-15) | Removes duplicate baixa signaling; the "Status" `_KvRow` is deleted entirely |
| `_KvRow` fixed 120px label / expanded value, all widths | `_KvRow` switches to stacked layout below ~400px via `LayoutBuilder` | This phase (D-21) | First responsive-breakpoint widget in the codebase — precedent for future mobile-web work |
| ATF row shows only the latest DG (`lastDgResult`/`lastDgDate`) | ATF row shows latest DG in the collapsed state, all DGs on tap-to-expand | This phase (D-08/D-10) | `ReproductiveHistoryEntry` gains a `dgRecords: List<DgRecord>` field (or equivalent) plus `bullName`/`implantationDate` |

**Deprecated/outdated:**
- Nothing framework-level is deprecated. `flutter_riverpod` 3.x's `ProviderException` wrapping (introduced in Riverpod 3.0, confirmed via Context7) is already the live behavior in this codebase — no migration needed, just something to know when reading a stack trace during D-04's error-path testing: an error `.when(error: (err, st) => ...)` on a *dependent* provider (e.g., `AnimalInfoCard` reading a lote provider that itself failed) will surface as `ProviderException`, not the raw underlying error — retrying the dependent provider alone will not fix it; the *originating* provider must be the one invalidated. This matters for D-04's "retry por bloco" if any future block depends on another (none currently do in this phase's scope).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `LayoutBuilder` (not `MediaQuery`) is the correct breakpoint source for `_KvRow` given the `ListView`/`Card` nesting | Architecture Patterns, Pattern 4 | Low — `08-CONTEXT.md` explicitly leaves this to Claude's Discretion ("se o breakpoint é lido de `LayoutBuilder` ou `MediaQuery`"); either compiles and works for this specific screen since it isn't nested in a multi-column adaptive shell region. Worth a quick manual check during implementation, not worth blocking planning. |
| A2 | `paddocks!inner(name)` (not a plain/left embed) is the right join type for the new lote+paddock query | Common Pitfalls, Pitfall 2 | Low — matches two existing precedents in the same file family (`fetchLotsWithCountByProperty`, `fetchAnimalsByProperty`) exactly; if wrong, the fix is a one-line change from `!inner` to a plain embed. |

**If this table is empty:** N/A — two low-risk, discretion-scoped assumptions logged above; everything else in this research is either verified against the current codebase or already locked by `08-CONTEXT.md` decisions.

## Open Questions

1. **Exact file/class name for the new lote+paddock wrapper type**
   - What we know: the codebase's convention is a small `LotWithX` wrapper class (see `LotWithPaddockCount`), not extending `Lot` itself.
   - What's unclear: whether the planner names it `LotWithPaddockName` (proposed here) or something else — purely cosmetic.
   - Recommendation: use `LotWithPaddockName` unless the plan-checker/executor finds a better-fitting existing name; this is not a decision that needs user input (already covered by CONTEXT.md's "Claude's Discretion").

2. **Whether `AnimalInfoCard` needs its own retry affordance for the new lote+paddock provider**
   - What we know: D-04 says "cada bloco" gets retry; the sanitary and reproductive *history* blocks clearly qualify. `AnimalInfoCard` itself currently shows `'—'` silently on lote/piquete load error (no retry, no visible error state) rather than failing loudly.
   - What's unclear: CONTEXT.md's D-04 discussion focuses on the two history sections; it's ambiguous whether the info card's lote/piquete row should also grow a retry button, or whether the silent `'—'` fallback is acceptable there since the auto-retry policy (`main.dart`) already covers transient failure.
   - Recommendation: keep the current silent-`'—'`-on-error behavior for the lote/piquete rows inside `AnimalInfoCard` (no retry UI there) — D-04's examples and rationale ("Hoje os textos de erro são mortos") specifically target the two *history* sections' dead-end error text, not the info card's already-graceful null fallback. The planner should confirm this reading explicitly in the plan rather than silently deciding it, since it is a small scope boundary.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | All widget work | ✓ `[VERIFIED: pubspec.yaml environment.sdk]` | `^3.11.4` | — |
| Chrome/Edge DevTools "Fast 4G" throttle | D-07 UAT for SC-1 | ✓ (standard browser devtools, no install) | — | — |
| `flutter test` (widget test runner) | D-23 test suite | ✓ (used by all prior phases) | — | — |
| `integration_test` package | N/A this phase | ✓ installed but **no web support** `[VERIFIED: STATE.md Phase 0 Completion Notes]` | — | Manual UAT (already the project-wide pattern for timing-sensitive criteria) |

No missing dependencies — this phase requires nothing beyond what every prior phase has already used.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` + `mocktail` (already project-wide) |
| Config file | none — no `pytest.ini`-equivalent; Flutter test discovery is directory-based (`test/`) |
| Quick run command | `flutter test test/widget/animal_detail_screen_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ANIM-03 / SC-2 | ATF row shows all DGs on expand, not just latest | widget | `flutter test test/widget/animal_detail_screen_test.dart` (or new `animal_reproductive_history_section_test.dart`) | ❌ Wave 0/2 — extend or create alongside D-11 extraction |
| ANIM-03 / SC-3 | Both history blocks render newest-first | widget | already covered — see existing `'populated: renders one row per entry, in the order supplied'` test in `animal_detail_screen_test.dart` | ✅ existing, verify still green after D-11 move |
| ANIM-03 / SC-4 | Baixa banner shows reason/date/observation, absent for active animals | widget | `flutter test test/widget/animal_detail_screen_test.dart` | ❌ Wave 2 — new test group needed |
| ANIM-03 / SC-5 | No overflow at 360px width | widget | `flutter test test/widget/animal_detail_screen_test.dart` with `tester.view.physicalSize`/`devicePixelRatio` override | ❌ Wave 2 — **first width-constrained widget test in this codebase** (confirmed via grep: no existing test sets `physicalSize`) |
| D-04 (retry per block) | Failed block shows a retry action that invalidates only that provider | widget | `flutter test test/widget/animal_detail_screen_test.dart` | ❌ Wave 2 |
| ANIM-03 / SC-1 (<1s on 4G) | Ficha opens fast under throttled network | manual-only (D-07) | N/A — DevTools "Fast 4G" + stopwatch | N/A — deliberately not automated (see Pitfall 3) |

### Sampling Rate
- **Per task commit:** `flutter test test/widget/animal_detail_screen_test.dart` (+ new reproductive-section test file once it exists)
- **Per wave merge:** `flutter test` (full suite — 312+ tests as of Phase 7 completion per STATE.md)
- **Phase gate:** Full suite green before `/gsd-verify-work`; D-07's manual 4G UAT is a separate human checkpoint, not part of the automated gate

### Wave 0 Gaps
- [ ] 360px-width widget test harness — no existing test in `test/widget/` sets `tester.view.physicalSize`; the first plan that needs this should establish the pattern (e.g., `addTearDown(tester.view.resetPhysicalSize)` + `tester.view.physicalSize = const Size(360, 800)` + `tester.view.devicePixelRatio = 1.0`) once, for reuse by later plans/phases.
- [ ] `test/features/lotes/lote_repository_test.dart` — extend with a contract-test line for the new `fetchLotWithPaddockName` method, matching the file's existing "contract" style (method-exists assertions, not full query mocking).
- [ ] `test/features/reproducao/atf_repository_test.dart` — check current coverage of `fetchReproductiveHistory` before extending; if it exists it needs an update for the new `dgRecords` field.

*(No framework install needed — `flutter_test`/`mocktail` are already dev dependencies.)*

## Security Domain

`security_enforcement` is not disabled in `.planning/config.json`, so this section is included per protocol — but this phase has an unusually small security surface: **no new tables, RPCs, or RLS policies**, and every read this phase adds is a read-shape change (adding columns/embeds to an existing SELECT) against tables whose RLS policies are already verified in Phases 3, 5, and 6.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | Unchanged — `AnimalDetailScreen` already gated by existing session/route guards |
| V3 Session Management | No | Unchanged |
| V4 Access Control | Yes — read-only, unchanged | RLS on `lots`, `paddocks`, `animal_atf_memberships`, `dg_records` already enforces property-membership isolation (Phases 2/5); this phase only widens the *columns/embeds selected*, never grants new access. The new `paddocks!inner(name)` embed on `lots` follows the exact precedent (`fetchAnimalsByProperty`) already covered by existing RLS — no new policy needed. |
| V5 Input Validation | No new user input this phase (read-only ficha; existing `BaixaDialog`/`AnimalEditDialog` forms are untouched) | — |
| V6 Cryptography | No | Unchanged |

### Known Threat Patterns for this stack
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Over-fetching via a wider embed accidentally exposing cross-property data | Information Disclosure | Not a new risk — PostgREST embeds still evaluate RLS on the embedded table (`paddocks`) per-row; a `paddocks!inner(name)` embed cannot return a paddock the caller's RLS wouldn't already allow via `paddockByIdProvider` today. No mitigation code needed, just confirm (as this research did) that the embed target table already has the same RLS the direct-query path had. |
| Baixa banner leaking data to unauthorized roles | Information Disclosure | Not applicable — D-16 explicitly keeps all history/data visible to every role for archived animals (same as active), matching the existing read-only-for-all-roles pattern (D-13, Phase 5) already enforced at the RLS layer, not the UI layer. The UI never has to "hide" this data because RLS already scopes it to property members. |

## Sources

### Primary (HIGH confidence)
- `lib/features/animais/presentation/animal_detail_screen.dart` — direct read, current production code
- `lib/features/reproducao/data/atf_model.dart`, `atf_repository.dart`, `dg_record_model.dart` — direct read
- `lib/features/lotes/data/lote_repository.dart`, `lote_model.dart` — direct read
- `lib/features/animais/data/animal_repository.dart`, `animal_constants.dart` — direct read
- `lib/features/piquetes/data/piquete_repository.dart` — direct read
- `lib/features/sanitario/presentation/sanitary_history_section.dart` — direct read
- `lib/features/animais/presentation/animais_screen.dart` — direct read
- `lib/main.dart` (`providerRetryPolicy`) — direct read
- `pubspec.yaml` — direct read, confirms no new packages needed
- `test/widget/animal_detail_screen_test.dart`, `test/features/lotes/lote_repository_test.dart` — direct read, confirms existing test conventions and the absence of width-constrained or query-shape tests
- `.planning/phases/08-animal-dossier-consolidation/08-CONTEXT.md` — 24 locked decisions, canonical source for scope
- `.planning/STATE.md` — Riverpod 3.x confirmation, `integration_test` web-support gap, prior-phase precedent notes
- Context7 `/rrousselgit/riverpod` — `ref.invalidate` retry pattern, `ProviderException` wrapping in Riverpod 3.0 `[CITED: github.com/rrousselgit/riverpod]`

### Secondary (MEDIUM confidence)
- General Flutter `LayoutBuilder` vs. `MediaQuery` guidance for nested-constraint responsive widgets — standard Flutter SDK behavior, not verified against this specific `ListView`/`Card` nesting depth this session `[ASSUMED]`

### Tertiary (LOW confidence)
None used as load-bearing claims.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — zero new dependencies, every package version read directly from `pubspec.yaml`
- Architecture: HIGH — every pattern cited is either already live in this exact codebase or directly copied from an existing precedent in the same repo
- Pitfalls: HIGH — five pitfalls, four derived from direct code/test reads (D-37 contract, `!inner` join semantics already in use, test-infrastructure gap, `_showArchived` filter logic), one (`LayoutBuilder` nesting) flagged LOW-risk/ASSUMED explicitly

**Research date:** 2026-08-11
**Valid until:** 2026-09-10 (30 days — stable, no external API surface, only risk is drift if `08-CONTEXT.md` decisions change before planning)
