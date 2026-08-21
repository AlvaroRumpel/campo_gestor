# Phase 3: Lots & Animals (Operational Core) - Context

**Gathered:** 2026-05-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Criar lotes operacionais com composição inicial em batch, gerar animais individualmente com numeração atômica, e disponibilizar lista global de animais com busca por número, filtros por categoria/lote/piquete, edição de ficha individual e baixa.

Phase 4 entrega movimentação. Phase 5/6 entregam histórico reprodutivo/sanitário. Phase 8 consolida a ficha completa.

</domain>

<decisions>
## Implementation Decisions

### Navegação de Lotes

- **D-01:** Lotes ficam dentro de `/piquetes/:id` — `PaddockDetailScreen` ganha seção de lotes (lista + FAB "Criar lote"). Não existe tela separada de lotes.
- **D-02:** Layout do `PaddockDetailScreen`: card de info do piquete (nome, área, capacidade) no topo, lista de lotes ativos abaixo, FAB role-gated para criar lote.
- **D-03:** Rota `LoteDetailScreen` = `/lotes/:loteId` como rota **raiz** (GoRoute de nível superior, fora do branch de piquetes). Acesso de qualquer contexto (paddock detail, animais, busca).
- **D-04:** `LoteDetailScreen` em Phase 3 mostra: header (nome do lote, piquete pai, contagem por categoria, UA total) + lista de animais ativos (número, categoria, lote). Tap no animal → `/animais/:id`. FAB para adicionar animal avulso (veterinário).

### Numeração do Animal

- **D-05:** Número único **por propriedade** (global). `UNIQUE INDEX animals_property_number_idx ON animals (property_id, number) WHERE deleted_at IS NULL` está correto. **Corrigir `generate_animal_number` RPC**: remover filtro por `category` — função atual gera por categoria (bug Phase 2) e conflita com o índice único global.
- **D-06:** Exibição: número inteiro simples (`42`, não `V-42`).
- **D-07:** **Override manual permitido**: auto-geração usa `MAX(number) + 1`. Ao criar animal avulso ou editar ficha, vet pode digitar número manualmente. Se o número pertence a animal arquivado (`deleted_at IS NOT NULL`), UNIQUE INDEX permite a reutilização (dois UUIDs distintos, mesmo número). Histórico do animal antigo preservado intacto.
- **D-08:** Batch usa `MAX(number)` global da propriedade (não sequência cronológica). Advisory lock em `generate_animal_number` garante que batches concorrentes não gerem duplicatas.
- **D-09:** Campo opcional **"Iniciar do número"** no formulário de criação do lote. Vazio = `MAX+1`. Preenchido = sistema gera a partir do número informado, **pulando os já ativos**, até completar a quantidade de cada categoria. Útil para animais que chegam com brincos físicos preexistentes.

### Formulário de Criação do Lote (Batch)

- **D-10:** Formulário mostra **6 categorias sempre visíveis** com contador numérico e raça opcional: Vacas, Novilhas, Terneiros, Terneiras, Touros, Bois, Novilhos. Quantidade `0` = não cria animais dessa categoria. Raça por categoria = search-select opcional (mesmo dropdown de raças do formulário individual).
- **D-11:** Obrigatório: nome do lote + soma de todas as categorias > 0 (não é possível criar lote vazio).
- **D-12:** Lote editável após criação: **somente o nome**. Piquete é imutável (mover lote entre piquetes = Phase 4). Composição muda via baixa de animais ou movimentações futuras.
- **D-13:** **Adicionar animal avulso ao lote existente = Phase 3**. `LoteDetailScreen` tem FAB "+ Animal" (role-gated, veterinário). Formulário: categoria (obrigatório), número (auto-gerado, over-ridável), raça (search-select opcional), EC chips 1–5 (opcional), observação (opcional).
- **D-14:** **Raça**: search-select com lista predefinida hardcoded no Flutter (não tabela no banco). Lista: Nelore, Angus, Brahman, Gir, Guzerá, Tabapuã, Canchim, Brangus, Simental, Charolês, Limousin, Hereford, Girolando, Wagyu, Caracu, Sindi, Pé-duro/Curraleiro.
- **D-15:** No batch, **raça é configurável por categoria** (opcional, aplicada a todos os animais da categoria). EC e observação são campos **somente na edição individual** da ficha.
- **D-16:** **Estado Corporal (EC 1–5)**: 5 chips/botões toggle em row. Toque = seleciona. Consistente com a escala do domínio.
- **D-17:** **Motivos de baixa (ANIM-04)**: Venda, Morte, Descarte. Enum no banco: `'sale'`, `'death'`, `'discard'`.

### Tela /animais (Busca e Filtro)

- **D-18:** `/animais` lista **todos os animais ativos da propriedade**. Header: contagem total + UA total. Filtros: chips de categoria (Vacas, Novilhas, etc.) + dropdowns Lote e Piquete. Barra de busca por número no topo.
- **D-19:** Item da lista: `#42 · Vaca` + linha secundária `Lote A · Piquete Norte`. Raça **não aparece na lista** — somente na ficha (`/animais/:id`).
- **D-20:** Busca por número: **filtro em tempo real com debounce** (≥300ms). Filtra animais cujo número contém o texto digitado. Tap → `/animais/:id`.
- **D-21:** Animais com baixa: **ocultos por padrão**. Toggle "Mostrar arquivados" os exibe com badge de motivo (Vendido / Morto / Descartado).
- **D-22:** **Ficha do animal Phase 3** (`/animais/:id`): número, categoria, raça, EC, observação, lote atual, piquete atual, data de cadastro. Ações: Editar (inline ou dialog), Dar baixa (dialog com motivo + data). Seções placeholder para Histórico Reprodutivo (Phase 5) e Histórico Sanitário (Phase 6) — não ficam completamente ausentes, indicam "disponível em breve".

### Claude's Discretion

- Layout interno do `LoteDetailScreen` (cards vs list tiles para animais).
- Estratégia de paginação/virtualização na lista de `/animais` para propriedades grandes.
- Estrutura exata do RPC de criação batch (se um único RPC cria lote + animais atomicamente, ou chamadas separadas no cliente).
- Animação/feedback visual durante geração batch (ex: progress indicator).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` §PROP-03, PROP-04, PROP-05, ANIM-01, ANIM-02, ANIM-04, ANIM-05, ANIM-06 — 8 requisitos desta fase
- `.planning/ROADMAP.md` §Phase 3 — goal, success criteria SC-1…SC-5

### Schema existente (Phase 2)
- `supabase/migrations/20260508_02_property_paddock.sql` — tabela `animals` skeleton, `generate_animal_number` RPC (a ser corrigido), ATF partial unique index, snapshot trigger

### Padrões de código estabelecidos
- `.planning/phases/01-auth-multi-tenancy-core/01-CONTEXT.md` — padrões arquiteturais (repository pattern, Riverpod AsyncNotifier, role gate pattern)
- `lib/features/piquetes/data/piquete_repository.dart` — padrão de repository a replicar para `LoteRepository` e `AnimalRepository`
- `lib/core/router/router.dart` — estrutura de rotas (StatefulShellBranch, sub-routes, root GoRoutes fora do shell)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `PaddockRepository` (`lib/features/piquetes/data/piquete_repository.dart`): padrão exato a replicar para `LoteRepository` e `AnimalRepository`
- `paddockListProvider` / `paddockByIdProvider`: padrão `FutureProvider` + `FutureProvider.family` a replicar
- `memberPropertiesProvider` role gate (`veterinarian`-only check): mesmo guard para FABs de lote e animal
- `PaddockFormDialog` (`lib/features/piquetes/presentation/paddock_form_dialog.dart`): padrão de AlertDialog com validação e pt-BR decimal — referência para `LoteFormDialog`
- `PaddockDetailScreen` (`lib/features/piquetes/presentation/paddock_detail_screen.dart`): tela a ser expandida com seção de lotes

### Established Patterns
- Repository nunca importa Supabase SDK diretamente — tudo via `SupabaseService`
- Estado assíncrono via `AsyncNotifier` / `FutureProvider` (Riverpod 3.x)
- Soft delete: `deleted_at timestamptz` + `.isFilter('deleted_at', null)` no query
- Role gate na UI: `veterinarian`-only sem `disabled` — controles simplesmente ausentes para leitores/owners
- pt-BR decimal: `FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))` + `replaceAll(',', '.')` antes de parse

### Integration Points
- `PaddockDetailScreen`: expandir com `Consumer` + `loteListByPaddockProvider(paddockId)` + FAB role-gated
- `router.dart`: adicionar GoRoute `/lotes/:id` (root-level, fora de qualquer branch) + GoRoute `/animais/:id` (sub-route do branch `/animais`)
- `AppRoutes` (`routes.dart`): adicionar `lotes`, `loteById`, `animalById` constants
- `AppShell`: tab `/animais` já existe como placeholder — substituir `AnimaisScreen` placeholder

</code_context>

<specifics>
## Specific Ideas

- "Iniciar do número" no batch é especialmente útil quando o produtor compra animais que chegam com brincos físicos já numerados (ex: lote de 20 novilhas com brincos #101-#120).
- Ao dar baixa, o animal não some imediatamente da tela — aparece com badge "Arquivado" até o próximo reload ou até o toggle ser desligado.
- O bug de `generate_animal_number` (filtra por `category`) deve ser corrigido como primeira tarefa da migration de Phase 3, antes de qualquer código Flutter que use a numeração.

</specifics>

<deferred>
## Deferred Ideas

- Filtro por raça em ANIM-06 — raça não aparece na lista, deixar filtro de raça para quando houver volume de dados que justifique.
- Histórico de baixas (animais vendidos com preço, comprador, etc.) — módulo contábil separado, fora do MVP.
- Importação em planilha para batch — fora do MVP.
- Mover animal individualmente entre lotes — Phase 4 (MOV-01).
- Mover lote inteiro entre piquetes — Phase 4 (MOV-02).

</deferred>

---

*Phase: 03-lots-animals-operational-core*
*Context gathered: 2026-05-14*
