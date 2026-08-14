# Phase 10: Gestão de Membros e Ciclo de Vida da Propriedade - Context

**Gathered:** 2026-08-14
**Status:** Ready for planning
**Source:** Decisões colhidas via AskUserQuestion na sessão do review geral (2026-08-14)

<domain>
## Task Boundary

Fechar a maior lacuna SaaS do v1: hoje `property_members` só ganha linhas pelo RPC de criação de propriedade (criador vira `veterinarian`); os papéis `owner` e `reader` são inalcançáveis por qualquer fluxo legítimo, não existe convite, remoção, troca de papel nem saída, e o arquivamento de fazenda não tem confirmação forte nem restauração.

Requisitos: MEMB-01 (convite com aceite), MEMB-02 (gestão de membros), MEMB-03 (guarda de último vet), PROPV-01 (arquivar com confirmação forte), PROPV-02 (restaurar pela UI).

</domain>

<decisions>
## Implementation Decisions

### Modelo de convite (MEMB-01) — LOCKED
- **Convite com aceite**, não adição direta: tabela de convites pendentes (e-mail alvo + papel + propriedade + convidante + status pending/accepted/declined/revoked).
- **Sem e-mail transacional no MVP**: o convite aparece **in-app** para o convidado quando ele loga com o e-mail convidado (match por e-mail do auth.users). Quem convida informa o e-mail; se a pessoa ainda não tem conta, o convite fica pendente até ela se cadastrar com aquele e-mail.
- Convite revogável pelo gestor enquanto pending.
- Aceitar cria a linha em `property_members` (via RPC SECURITY DEFINER, nunca INSERT direto do client); recusar marca declined.

### Quem gerencia membros (MEMB-02) — LOCKED
- **Veterinário E proprietário** podem convidar, remover e trocar papel. Leitor só visualiza.
- **Sub-regra**: proprietário pode remover/rebaixar um veterinário **desde que não seja o último vet** (a guarda MEMB-03 cobre).
- Sair da fazenda (self-service) disponível a qualquer membro — bloqueado se for o último vet.

### Guarda de último vet (MEMB-03) — LOCKED
- **No banco** (trigger/validação nos RPCs): rejeitar remover, rebaixar ou sair do único `veterinarian` da fazenda. Tenant nunca fica sem admin.

### Arquivar/restaurar fazenda (PROPV-01/02) — LOCKED
- Arquivar: dialog com **confirmação forte — digitar o nome da fazenda**. Qualquer vet pode arquivar.
- Restaurar: tela de propriedades lista fazendas arquivadas (visíveis aos vets que eram membros) com ação de restaurar.
- **SEM trilha de auditoria** (archived_by etc.) — decisão explícita, não adicionar.
- **SEM mudança em `is_member_of`** — decisão explícita: a função continua ignorando `properties.deleted_at` (necessário para a restauração funcionar; o acesso pós-arquivo via API é risco aceito nesta fase).

### Convenções herdadas do projeto (não re-decidir)
- Toda escrita em `property_members` e na tabela de convites via **RPC SECURITY DEFINER** com `SET search_path = public`, validação de membership + papel, REVOKE de `anon`/`PUBLIC` (padrão da 20260814_10).
- Tabela de convites com `ENABLE + FORCE ROW LEVEL SECURITY`; leitura via policies (gestores veem convites da propriedade; convidado vê convites do próprio e-mail); escrita só via RPC (zero write policies — padrão dg_records).
- `property_id` imutável (trigger genérico `enforce_property_id_immutable` já existe — reusar na tabela nova).
- UI: papel negado vê controle **ausente**, nunca desabilitado (convenção role_gates.dart). pt-BR, padrões visuais do app (mestre-detalhe desktop, bottom sheet mobile via showAdaptiveForm, EmptyState com action).
- Forward-only migrations, nome `20260814_11_*` ou data corrente.

### Claude's Discretion
- Estrutura exata da tabela de convites (índices, unique parcial por (property_id, email) pending).
- Onde a UI de membros vive (ex.: dentro da tela de Propriedades ou tela própria) — seguir o padrão do app.
- Textos pt-BR das telas.
- Expiração de convite: não requerida; pode omitir no MVP.

</decisions>

<specifics>
## Specific Ideas

- Tela `/sem-acesso` hoje diz "Entre em contato com o proprietário da fazenda para receber acesso" — com convites in-app, essa tela deve passar a mostrar os convites pendentes do usuário logado (aceitar/recusar dali).
- `canManageExpenses` em role_gates.dart mostra o padrão de gate por papel; criar gate análogo `canManageMembers` (vet || owner).
- O papel `owner` finalmente vira alcançável — conferir que as policies existentes que citam `'owner'` (expenses) passam a funcionar como esperado.

</specifics>

<canonical_refs>
## Canonical References

- `supabase/migrations/20260504_01_auth_multitenancy.sql` — property_members, role_enum, is_member_of/get_role
- `supabase/migrations/20260814_09_multitenant_hardening.sql` e `20260814_10_medium_hardening.sql` — padrões de hardening vigentes (REVOKEs, triggers, policies)
- `lib/core/auth/role_gates.dart` — convenção de gates por papel
- `lib/features/auth/presentation/no_access_screen.dart` — tela sem-acesso a evoluir
- `lib/features/propriedades/` — tela de propriedades (arquivar/restaurar entra aqui)
- Review geral 2026-08-14 (F-4/F-6 do agente multi-tenant) — origem dos requisitos

</canonical_refs>
