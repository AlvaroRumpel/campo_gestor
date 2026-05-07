# Phase 2: Property & Paddock Structure - Context

**Gathered:** 2026-05-07
**Status:** Ready for planning

<domain>
## Phase Boundary

Estruturar a fazenda: CRUD de propriedades e piquetes com RLS por perfil; protótipos críticos de backend (RPC numeração, JSONB snapshot, ATF partial unique index). Usuário consegue criar uma fazenda, adicionar piquetes e visualizar a estrutura da propriedade ativa.

Criação de lotes, animais e movimentações é Phase 3+.

</domain>

<decisions>
## Implementation Decisions

### Role Model (inversão confirmada pelo usuário)

- **D-01:** `veterinário` = usuário primário do sistema = acesso total (CRUD de tudo). É ele quem cria e gerencia fazendas de clientes.
- **D-02:** `proprietário` = dono da terra = acesso restrito/read-only para propriedades e piquetes. Usa o app para acompanhar, não gerenciar.
- **D-03:** `leitor` = read-only (mesmo nível que proprietário para esta fase).
- **D-04:** Quem cria uma fazenda no app ganha perfil `veterinário` nela via INSERT em `property_members`.
- **D-05:** `propriedades.proprietario` = campo de texto livre (nome do dono da terra). NÃO é FK para `auth.users`.

### Role enforcement na UI e banco

- **D-06:** Para perfis read-only (proprietário, leitor): ações de mutação (FAB, botões edit, delete) **simplesmente não aparecem** na UI — sem disabled, sem tooltip. UI limpa.
- **D-07:** RLS bloqueia INSERT/UPDATE/DELETE para não-veterinários no banco (defense in depth). Não confiar só na UI.
- **D-08:** Helper function `is_member_of(property_id)` já existe. Fase 2 precisa de helper adicional `get_perfil(property_id)` para checar nível de acesso nas policies.

### Property management UX

- **D-09:** `NoAccessScreen` (usuário com 0 fazendas) ganha CTA "Criar minha fazenda" — fluxo de onboarding sem precisar encontrar página de settings.
- **D-10:** Rota `/propriedades` para gerenciar fazendas existentes (criar, editar, soft-delete). Acessível via botão "Gerenciar fazendas" no dropdown do `PropertySelector` no AppShell header.
- **D-11:** Soft-delete em propriedades: registros com `deleted_at IS NOT NULL` somem da lista e do `PropertySelector`. `propriedades` table precisa de coluna `deleted_at timestamptz`.

### Piquetes screen design (mobile-first)

- **D-12:** App é **mobile-first** (correção de prioridade — web é suportado mas não é o driver de UX).
- **D-13:** Tela Piquetes: lista vertical (ListView) com FAB "+" para criar. Padrão Material 3 mobile.
- **D-14:** Cada item da lista mostra: nome, área (ha) e capacidade (UA).
- **D-15:** Tap em piquete → navega para `/piquetes/:id` (tela de detalhe). Edit/delete disponíveis só para `veterinário`.
- **D-16:** Soft-deleted piquetes somem da lista (`WHERE deleted_at IS NULL`). Sem modo "arquivados" nesta fase.

### Campos e schema de piquetes

- **D-17:** `piquetes.capacidade_ua` = `NUMERIC(8,2)` (UA decimal, ex: 12.5 UA). Alinha com valores fracionários de UA por categoria.
- **D-18:** Todos os 3 campos são **obrigatórios** ao criar piquete: `nome` (text), `area_ha` (NUMERIC(8,2)), `capacidade_ua` (NUMERIC(8,2)).
- **D-19:** `piquetes` precisa de `deleted_at timestamptz` para soft-delete.

### Protótipos críticos de backend (risk-retirement)

Estes são validações técnicas sem UI associada. Claude decide a implementação, mas devem existir e passar testes antes que fases seguintes dependam deles.

- **D-20:** RPC `gerar_numero_animal(p_propriedade_id uuid, p_categoria text)` — sequence atômico por (propriedade, categoria), testado com 2+ requests paralelos sem duplicata.
- **D-21:** Coluna JSONB `composicao_snapshot` em tabela de aplicações sanitárias (Phase 6 usa, mas índice/trigger criados aqui). Trigger `BEFORE UPDATE OR DELETE` bloqueia mutação no nível do banco.
- **D-22:** Partial unique index `WHERE ativo = true` para ATF uniqueness (um animal não pode estar em 2 ATFs ativos). Validado com teste que tenta inserir 2 ATFs ativos para o mesmo animal e recebe erro de banco.

### Claude's Discretion

- Implementação interna do `gerar_numero_animal` (SEQUENCE vs. `SELECT MAX() + 1 FOR UPDATE`, lock strategy).
- Design visual das telas de propriedades e piquetes — Material 3, pt-BR, consistente com login screens da Phase 1.
- Tela de detalhe do piquete (`/piquetes/:id`) — mostra info do piquete + botões de edit/delete para veterinário. Phase 3 adiciona lotes.
- Estratégia de formulário (reactive_forms já no pubspec).
- Estrutura exata das RLS policies para `piquetes` (seguir padrão da Phase 1 com `is_member_of` + perfil check).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & Roadmap
- `.planning/REQUIREMENTS.md` §PROP-01, PROP-02 — 2 requisitos desta fase
- `.planning/ROADMAP.md` §Phase 2 — success criteria (5 itens) e goal

### Codebase existente (Phase 0 + 1)
- `lib/core/widgets/app_shell.dart` — AppShell com NavigationRail/BottomNav, breakpoint 600px; Phase 2 não muda a estrutura
- `lib/core/widgets/property_selector.dart` — PropertySelector no header; Phase 2 adiciona "Gerenciar fazendas" ao dropdown
- `lib/core/providers/current_property_provider.dart` — `AsyncNotifier<Property?>` com `selectProperty()` e `clear()`; Phase 2 usa para filtrar piquetes por propriedade ativa
- `lib/core/router/router.dart` — rotas existentes; Phase 2 adiciona `/propriedades`, `/piquetes`, `/piquetes/:id`
- `lib/features/piquetes/presentation/piquetes_screen.dart` — stub vazio, Phase 2 implementa

### Schema existente
- `supabase/migrations/20260504_01_auth_multitenancy.sql` — tabela `propriedades` (id, nome, created_at), `property_members` (user_id, property_id, perfil), `perfil_enum`, `is_member_of()`. Phase 2 adiciona `deleted_at` a `propriedades` e cria `piquetes`.

### Context de Phase anterior
- `.planning/phases/01-auth-multi-tenancy-core/01-CONTEXT.md` — D-07 (profile enforcement deferred to Phase 2), D-08 (RLS FORCE ROW LEVEL SECURITY padrão)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `AppShell` + `NavigationRail`/`BottomNavigationBar`: adaptive shell já funcional; "Piquetes" destination já existe como stub
- `PropertySelector`: dropdown no header — Phase 2 adiciona opção "Gerenciar fazendas"
- `currentPropertyProvider`: já provê `Property?` ativa — piquetes filtram por `currentPropertyProvider.value?.id`
- `is_member_of(uuid)`: SECURITY DEFINER function já no banco — base para novas RLS policies
- `supabase_service.dart` + repository pattern: features não importam Supabase diretamente

### Established Patterns
- Features seguem `presentation/` + `data/` (ver `lib/features/auth/`)
- Estado assíncrono via `AsyncNotifier` / `AsyncValue` (Riverpod 3.x)
- GoRouter com rotas dentro do `StatefulShellRoute` para manter AppShell
- RLS: `ENABLE ROW LEVEL SECURITY` + `FORCE ROW LEVEL SECURITY` em toda tabela de domínio

### Integration Points
- `property_selector.dart`: adicionar "Gerenciar fazendas" que navega para `/propriedades`
- `no_access_screen.dart`: adicionar CTA "Criar minha fazenda" que navega para formulário de criação
- `router.dart`: novas rotas `/propriedades`, `/piquetes`, `/piquetes/:id` dentro do shell
- `current_property_provider.dart`: piquetes sempre scoped pelo `property_id` da propriedade ativa

</code_context>

<specifics>
## Specific Ideas

- `gerar_numero_animal` RPC deve ser testável via `supabase_test` com chamadas paralelas (`pg_background` ou `pgbench`) para validar ausência de duplicatas.
- Trigger de imutabilidade de snapshot JSONB: `RAISE EXCEPTION 'snapshot is immutable'` em qualquer tentativa de UPDATE/DELETE.
- ATF partial unique index: `CREATE UNIQUE INDEX animais_lote_atf_ativo_idx ON animais_lote_atf (animal_id) WHERE ativo = true`.

</specifics>

<deferred>
## Deferred Ideas

- Gerenciamento de membros (convidar/remover usuários de uma fazenda) — Phase 2 não inclui UI de convite; vínculo criado via seed/Studio
- Cálculo de UA atual por piquete (requer dados de lotes + animais — Phase 3)
- Exibir lotes dentro da tela de detalhe do piquete — Phase 3
- Capacidade em headcount além de UA — pós-MVP se demandado

</deferred>

---

*Phase: 02-property-paddock-structure*
*Context gathered: 2026-05-07*
