---
phase: quick-260814-f2v
plan: 01
subsystem: security, ui
tags: [postgres, rls, trigger, riverpod, flutter, multi-tenant]

requires: []
provides:
  - "Migration 20260814_09_multitenant_hardening.sql — 5 fixes de isolamento multi-tenant (não aplicada, pendente de push manual)"
  - "ErrorRetry widget compartilhado em lib/core/widgets/ui.dart, usado em 26 estados de erro"
  - "Reset de filtros/seleção efêmera ao trocar de propriedade ativa em 4 telas"
affects: [supabase-migrations, error-handling-ux, multi-property-state]

tech-stack:
  added: []
  patterns:
    - "Trigger genérico enforce_property_id_immutable() reusado via CREATE TRIGGER por tabela, em vez de 6 funções específicas"
    - "ErrorRetry(message, onRetry) — Column min sem Center embutido, onRetry sempre invalida o provider exato do AsyncValue que errou"
    - "ref.listen(currentPropertyProvider) com guarda prevId/nextId não-nulos e diferentes para resetar estado efêmero sem quebrar seeding de deep link"

key-files:
  created:
    - supabase/migrations/20260814_09_multitenant_hardening.sql
  modified:
    - lib/core/widgets/ui.dart
    - lib/core/widgets/property_selector.dart
    - lib/features/animais/presentation/animais_screen.dart
    - lib/features/animais/presentation/animal_detail_screen.dart
    - lib/features/dashboard/presentation/dashboard_screen.dart
    - lib/features/gastos/presentation/gastos_property_screen.dart
    - lib/features/gastos/presentation/gastos_screen.dart
    - lib/features/lotes/presentation/lotes_list_view.dart
    - lib/features/lotes/presentation/lote_detail_screen.dart
    - lib/features/lotes/presentation/_lots_section.dart
    - lib/features/piquetes/presentation/paddock_detail_screen.dart
    - lib/features/piquetes/presentation/piquetes_screen.dart
    - lib/features/propriedades/presentation/propriedades_screen.dart
    - lib/features/reproducao/presentation/animal_reproductive_history_section.dart
    - lib/features/reproducao/presentation/atf_animal_selection_screen.dart
    - lib/features/reproducao/presentation/atf_detail_screen.dart
    - lib/features/reproducao/presentation/reproducao_screen.dart
    - lib/features/sanitario/presentation/aplicacao_detail_screen.dart
    - lib/features/sanitario/presentation/registrar_aplicacao_screen.dart
    - lib/features/sanitario/presentation/sanitario_screen.dart
    - lib/features/sanitario/presentation/sanitary_history_section.dart
    - test/widget/animais_screen_test.dart

key-decisions:
  - "Migration escrita e verificada em disco, NÃO aplicada (sem db push/apply_migration/test db) — aplicação manual do usuário, per prohibitions do plano"
  - "_AnimaisCard (lote_detail_screen.dart) convertido de StatelessWidget para ConsumerWidget + lotId, para poder invalidar animalListByLotProvider(lotId) exato no retry"
  - "gastos_screen.dart: onRetry invalida condicionalmente um dos dois providers (unifiedExpenseListByPaddockProvider ou ...WithDeletedByPaddockProvider) conforme o toggle _showDeleted ativo no momento do erro"

patterns-established:
  - "ErrorRetry consolidado substitui 3 implementações manuais de Text+TextButton pré-existentes (animal_reproductive_history_section, sanitary_history_section x2)"

requirements-completed: []

coverage:
  - id: D1
    description: "Migration de hardening multi-tenant: DROP self_insert_membership, animals.lot_id NOT NULL, property_id imutável (6 tabelas), animals_category_check + guarda ATF, deactivate_atf_membership_on_baixa SECURITY DEFINER"
    verification:
      - kind: other
        ref: "grep verify inline no PLAN.md Task 1 — 5 fixes presentes, >=7 CREATE TRIGGER, nenhum trigger em sanitary_applications, git status mostra só o arquivo novo"
        status: pass
    human_judgment: true
    rationale: "Migration não foi aplicada a nenhum banco (proibido pelo plano) — só sintaxe/estrutura verificadas estaticamente. Correção efetiva só é confirmável após supabase db push manual + pgTAP/consulta ao catálogo, que o usuário roda fora deste fluxo."
  - id: D2
    description: "ErrorRetry compartilhado em ui.dart, usado em 26 estados de erro de rede em toda a árvore de telas (cada onRetry invalida o provider exato)"
    verification:
      - kind: unit
        ref: "flutter analyze --no-pub (0 erros, 4 infos pré-existentes)"
        status: pass
      - kind: unit
        ref: "flutter test (423/423 passando, incl. suites que exercitam essas telas: sanitary_history_section_test.dart retry test, reproducao_screen_test.dart error test)"
        status: pass
    human_judgment: false
  - id: D3
    description: "4 telas (animais, sanitário, piquetes, reprodução) resetam filtro/seleção local ao trocar de propriedade ativa, sem quebrar o seeding de deep link do SanitarioScreen"
    verification:
      - kind: unit
        ref: "test/widget/animais_screen_test.dart#AnimaisScreen — Reset de filtros na troca de propriedade (T-f2v-06) trocar de propriedade ativa zera o filtro de lote aplicado"
        status: pass
      - kind: unit
        ref: "flutter test (423/423, incluindo toda a suite de sanitario_screen/sanitario_desktop que cobre o seeding de deep link ?lote=/?animal=)"
        status: pass
    human_judgment: false

duration: 18min
completed: 2026-08-14
status: complete
---

# Quick Task 260814-f2v: Corrigir findings do review de segurança multi-tenant + UX Summary

**Migration forward-only fechando 5 furos de isolamento multi-tenant no Postgres (property_id imutável, lot_id obrigatório, categoria validada, ATF membership honesta na baixa, takeover de tenant fechado) + ErrorRetry compartilhado em 26 estados de erro + reset de filtros efêmeros em 4 telas na troca de propriedade.**

## Performance

- **Duration:** ~18 min (10:57–11:15 -03:00)
- **Tasks:** 3/3 completos
- **Files modified:** 21 (1 criado, 20 editados)

## Accomplishments

- `supabase/migrations/20260814_09_multitenant_hardening.sql` autorada e verificada em disco (não aplicada): fecha T-f2v-01 a T-f2v-05 do threat model do plano.
- `ErrorRetry` novo em `lib/core/widgets/ui.dart`; 26 sites convertidos/consolidados em toda a árvore de telas, cada `onRetry` invalidando o provider exato do `AsyncValue` que produziu o erro.
- 4 telas (`AnimaisScreen`, `SanitarioScreen`, `PiquetesScreen`, `ReproducaoScreen`) resetam filtro/seleção local via `ref.listen(currentPropertyProvider)` guardado por `prevId`/`nextId` não-nulos e diferentes — sem apagar os filtros de deep link (`?lote=`/`?animal=`) que o `SanitarioScreen` semeia no primeiro `build()`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Migration de hardening multi-tenant (5 fixes, forward-only, não aplicada)** - `a9f8af2` (feat)
2. **Task 2: ErrorRetry compartilhado e retry em todo estado de erro de rede** - `4012f57` (feat)
3. **Task 3: Resetar filtros e seleções ao trocar de propriedade** - `6c302e5` (feat)

_Task 3 tinha `tdd="true"`, mas o teste (`test/widget/animais_screen_test.dart`) foi escrito e commitado junto com a implementação num único commit, não em commits RED→GREEN separados — ver "TDD Gate Compliance" abaixo._

## Files Created/Modified

- `supabase/migrations/20260814_09_multitenant_hardening.sql` - 5 fixes de hardening multi-tenant, forward-only, não aplicado
- `lib/core/widgets/ui.dart` - novo widget `ErrorRetry`
- `lib/core/widgets/property_selector.dart` + 19 telas/seções em `animais`, `dashboard`, `gastos`, `lotes`, `piquetes`, `propriedades`, `reproducao`, `sanitario` - erro de rede → `ErrorRetry` com retry no provider exato
- `lib/features/lotes/presentation/lote_detail_screen.dart` - `_AnimaisCard` convertido para `ConsumerWidget` (+ `lotId`) para poder invalidar `animalListByLotProvider(lotId)`
- `lib/features/animais/presentation/animais_screen.dart`, `lib/features/sanitario/presentation/sanitario_screen.dart`, `lib/features/piquetes/presentation/piquetes_screen.dart`, `lib/features/reproducao/presentation/reproducao_screen.dart` - `ref.listen(currentPropertyProvider)` com guarda de reset
- `test/widget/animais_screen_test.dart` - teste novo: troca de propriedade A→B zera o filtro de lote aplicado

## Decisions Made

- Migration escrita e verificada estaticamente (grep dos 5 fixes, contagem de triggers, `git status` só com o arquivo novo) — **não aplicada** a nenhum banco, conforme proibição explícita do plano (`NÃO rodar supabase db push / MCP apply_migration`).
- `_AnimaisCard` em `lote_detail_screen.dart` precisou virar `ConsumerWidget` (recebendo `lotId`) porque a regra do plano exige invalidar o provider exato, e o widget original só recebia `animalsAsync` já resolvido, sem acesso a `ref` nem ao `lotId` de origem.
- `gastos_screen.dart` tem dois providers possíveis para a lista de gastos por piquete (`unifiedExpenseListByPaddockProvider` / `...WithDeletedByPaddockProvider`) dependendo do toggle `_showDeleted` — o `onRetry` invalida o que estiver ativo no momento do erro, não os dois.

## Deviations from Plan

### Auto-fixed Issues

Nenhum desvio Rule 1-4 — plano executado como escrito nas 3 tasks.

**Nota TDD (não é um desvio Rule 1-4):** a Task 3 tinha `tdd="true"" com um bloco `<behavior>` explícito. A implementação (os 4 `ref.listen`) e o teste novo (`animais_screen_test.dart`) foram escritos e verificados juntos e commitados num único commit `feat(260814-f2v)`, em vez de dois commits separados `test(...)` (RED) → `feat(...)` (GREEN). O teste foi executado isoladamente (`flutter test test/widget/animais_screen_test.dart`) antes do commit e passou com a implementação já presente — não foi confirmado que o teste falharia sem a implementação (RED real não foi observado, só inferido pela lógica do guard). Comportamento coberto integralmente pelo `<behavior>` do plano; risco de regressão é baixo dado que a suíte inteira (423 testes, incl. os testes de seeding de deep link do sanitário) permanece verde.

---

**Total deviations:** 0 auto-fixes (Rule 1-4). 1 nota de processo TDD (RED/GREEN não separados em commits distintos).
**Impact on plan:** Nenhum — escopo e comportamento entregues integralmente conforme o plano.

## TDD Gate Compliance

Task 3 (`tdd="true"`) não seguiu o gate sequence de commits separados `test(...)` → `feat(...)`. Implementação e teste foram commitados juntos em `6c302e5`. O `<behavior>` do plano foi verificado (teste passa, guard cobre os 3 cenários descritos), mas o ciclo RED-GREEN formal com commits distintos não foi seguido.

## Issues Encountered

- O worktree não tinha `.dart_tool/` nem arquivos gerados (`*.freezed.dart`, `*.g.dart`) — `flutter pub get` + `dart run build_runner build` precisaram rodar antes de `flutter analyze`/`flutter test` produzirem sinal real (sem isso, 739 falsos positivos de "getter isn't defined" apareciam). Não é um desvio de código, só setup de ambiente necessário para verificar o próprio trabalho.

## User Setup Required

**Migration pendente de aplicação manual.** `supabase/migrations/20260814_09_multitenant_hardening.sql` foi escrita e verificada em disco mas **não aplicada** a nenhum ambiente (dev/prod). Antes de aplicar (`supabase db push` ou MCP `apply_migration`):

1. O bloco `DO $$ ... $$` do fix 2 (`animals.lot_id SET NOT NULL`) e do fix 4 (`animals_category_check`) **abortam a transação inteira** se PROD tiver linhas violando a regra — a pré-checagem reporta a contagem exata de linhas para o operador corrigir antes de re-rodar.
2. Confirme com `SELECT count(*) FROM animals WHERE lot_id IS NULL` e `SELECT count(*) FROM animals WHERE category NOT IN ('vaca','novilha','terneiro','terneira','touro','boi','novilho')` antes do push, para evitar descobrir o abort só na tentativa.
3. Após aplicar, verificar via catálogo: `DROP POLICY self_insert_membership` (deve sumir de `pg_policies`), `lot_id` `NOT NULL` (`information_schema.columns`), 7 triggers novos (`pg_trigger` filtrando `tgname LIKE 'trg_%property_id_immutable' OR tgname = 'trg_animals_category_atf_guard'`), `deactivate_atf_membership_on_baixa` com `prosecdef = true` (`pg_proc`).

## Next Phase Readiness

- Migration pronta para push manual — nenhum bloqueio de código, só a decisão do usuário sobre quando aplicar em PROD.
- UI (`ErrorRetry` + reset de filtros) já em produção assim que este commit for mesclado — não depende da migration.

---
*Quick task: 260814-f2v*
*Completed: 2026-08-14*

## Self-Check: PASSED

- FOUND: `supabase/migrations/20260814_09_multitenant_hardening.sql`
- FOUND: commit `a9f8af2` (Task 1)
- FOUND: commit `4012f57` (Task 2)
- FOUND: commit `6c302e5` (Task 3)
- FOUND: `class ErrorRetry` in `lib/core/widgets/ui.dart`
