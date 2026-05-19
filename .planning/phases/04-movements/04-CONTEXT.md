# Phase 4: Movements - Context

**Gathered:** 2026-05-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Mover animal individual entre lotes da mesma propriedade (MOV-01) e mover lote inteiro entre piquetes de forma atômica via RPC (MOV-02). Nenhuma nova entidade criada — apenas mudanças de `lot_id` (animais) e `paddock_id` (lotes).

Phase 3 entregou `animals.lot_id` e `lots.paddock_id` imutáveis durante criação/edição. Phase 4 implementa os únicos flows que os alteram.

</domain>

<decisions>
## Implementation Decisions

### Mover Animal Individual (MOV-01)

- **D-01:** Entry point: `AnimalDetailScreen` — 3º botão de ação (após "Editar" e "Dar baixa"), role-gated veterinarian. Botão ausente para animais arquivados (`deletedAt != null`), mesma lógica do botão Baixa (D-22 Phase 3).
- **D-02:** Picker de lote destino: dialog com lista de todos os lotes ativos da propriedade. Lote atual do animal excluído da lista. Provider novo: `loteListByPropertyProvider` (FutureProvider.family por propertyId).
- **D-03:** Cada item no picker: nome do lote + piquete pai + contagem de animais ativos. Ex: `"Lote Bravo — Piquete Norte (32 animais)"`. Requer query com JOIN ou count separado.
- **D-04:** Implementação: `UPDATE animals SET lot_id = :target WHERE id = :id` direto via PostgREST com RLS. Não precisa de RPC — operação de 1 linha, RLS valida que target_lot pertence à mesma propriedade.
- **D-05:** Pós-move: permanece na `AnimalDetailScreen`. Provider invalidation atualiza lote exibido. SnackBar: `"Animal movido para [nome do lote destino]"`.

### Mover Lote Inteiro (MOV-02)

- **D-06:** Entry point: `LoteDetailScreen` — botão "Mover para piquete" no header/card do lote, role-gated veterinarian. Botão ausente quando: lote arquivado (`deletedAt != null`) OU lote sem animais ativos (0 animais ativos).
- **D-07:** Dialog de confirmação: picker de piquete destino (lista de piquetes ativos da propriedade, piquete atual excluído) + texto informativo `"X animais serão transferidos."`. Botão confirmar destacado.
- **D-08:** Implementação: RPC `move_lot_to_paddock(p_lot_id, p_paddock_id)` em plpgsql — conforme business rule REQUIREMENTS.md ("atômico via RPC"). RPC valida: piquete destino pertence à mesma propriedade, lote ativo, piquete ativo, role = veterinarian.
- **D-09:** Piquete atual do lote excluído do picker de destino (evita mover para o mesmo piquete).
- **D-10:** Pós-move: permanece na `LoteDetailScreen`. Provider invalidation atualiza piquete exibido no header. SnackBar: `"Lote movido para [nome do piquete destino]"`.

### Provider Invalidation

- **D-11:** Após mover animal: invalidar `animalListByLotProvider(antigoloteId)`, `animalListByLotProvider(novoLoteId)`, `animalByIdProvider(animalId)`, `animalListByPropertyProvider`.
- **D-12:** Após mover lote: invalidar `loteListByPaddockProvider(antigoPiqueteId)`, `loteListByPaddockProvider(novoPiqueteId)`, `loteByIdProvider(loteId)`.

### Claude's Discretion

- Layout exato do dialog de seleção de lote (height, separator, scroll behavior).
- Se `loteListByPropertyProvider` usa JOIN com paddock name ou query separada.
- Estrutura interna do RPC `move_lot_to_paddock` (SECURITY DEFINER vs INVOKER).
- Animação/loading durante a operação atômica.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` §MOV-01, MOV-02 — 2 requisitos desta fase; business rule "Mover lote = operação atômica; falha parcial não permitida"
- `.planning/ROADMAP.md` §Phase 4 — goal, success criteria SC-1…SC-4

### Padrões de repositório e RPC (Phase 3)
- `lib/features/animais/data/animal_repository.dart` — updateAnimal (padrão UPDATE field-specific); AnimalNumberConflictException (padrão de exception tipada); providers FutureProvider.family
- `lib/features/lotes/data/lote_repository.dart` — createLotWithAnimals RPC call (padrão .rpc() com params dict); loteListByPaddockProvider; loteByIdProvider
- `supabase/migrations/20260514_03_lots_animals.sql` — padrão RPC SECURITY DEFINER com is_member_of() + get_role() check; pg_advisory_xact_lock; RAISE EXCEPTION com ERRCODE 42501

### Telas a modificar (Phase 3)
- `lib/features/animais/presentation/animal_detail_screen.dart` — onde adicionar 3º botão "Mover animal"; padrão de _canEdit e botões de ação
- `lib/features/lotes/presentation/lote_detail_screen.dart` — onde adicionar botão "Mover lote" no header; padrão de FAB/botão role-gated
- `lib/features/animais/presentation/baixa_dialog.dart` — padrão de dialog de ação destrutiva a replicar para MoverAnimalDialog e MoverLoteDialog

### Contexto anterior
- `.planning/phases/03-lots-animals-operational-core/03-CONTEXT.md` — D-12 (paddock imutável), D-22 (buttons AnimalDetailScreen), D-03 (rota LoteDetailScreen), role gate pattern

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `BaixaDialog` (`lib/features/animais/presentation/baixa_dialog.dart`): padrão StatefulWidget dialog com ação destrutiva — replicar estrutura para `MoverAnimalDialog` e `MoverLoteDialog`
- `loteByIdProvider` / `loteListByPaddockProvider`: providers existentes a invalidar após move lote
- `animalByIdProvider` / `animalListByLotProvider` / `animalListByPropertyProvider`: providers a invalidar após move animal
- `_canEdit` pattern (veterinarian gate): replicar para condicionar botão "Mover" em ambas as telas

### Established Patterns
- `ref.invalidate(provider)` após operação bem-sucedida — padrão estabelecido em LoteFormDialog
- SnackBar via `ScaffoldMessenger.of(context).showSnackBar(...)` — feedback pós-ação
- Repository nunca importa Supabase SDK diretamente — via SupabaseService
- Exception tipada (`AnimalNumberConflictException`) para erros de domínio

### Integration Points
- `AnimalDetailScreen`: adicionar botão "Mover" no bloco de ações (após Editar e Baixa), condicional `isActive && _canEdit`
- `LoteDetailScreen`: adicionar botão "Mover para piquete" no header card, condicional `lot.deletedAt == null && activeAnimalCount > 0 && _canEdit`
- Nova migration: RPC `move_lot_to_paddock`; UPDATE policy em `animals` para permitir `lot_id` change (verificar se policy atual cobre ou precisa ajuste)
- Novo provider: `loteListByPropertyProvider` (FutureProvider.family<List<Lot>, String>) para picker do move animal

</code_context>

<specifics>
## Specific Ideas

- O picker de lote destino precisa mostrar contagem de animais ativos — isso pode ser resolvido com uma query SELECT lots.*, COUNT(animals) WHERE animals.deleted_at IS NULL GROUP BY lots.id, ou com um DTO LotWithCount.
- O RPC `move_lot_to_paddock` só precisa atualizar `lots.paddock_id` — animais não têm `paddock_id` próprio, obtêm via JOIN. A operação é single-row UPDATE, mas encapsulada em RPC para cumprir a regra de negócio e centralizar validações.
- Business rule crítica: animal nunca existe sem lote. A operação de mover animal deve ser atômica: setar novo lot_id sem passar por estado intermediário sem lote.

</specifics>

<deferred>
## Deferred Ideas

- Histórico de movimentações (auditoria de quem moveu o quê quando) — pós-MVP, requer tabela de eventos.
- Mover múltiplos animais selecionados de uma vez — lote-level move (MOV-02) já cobre o caso bulk; seleção individual múltipla seria nova feature.
- Mover animal para lote de outra propriedade — explicitamente fora do escopo (business rule: mesma propriedade).

</deferred>

---

*Phase: 04-movements*
*Context gathered: 2026-05-19*
