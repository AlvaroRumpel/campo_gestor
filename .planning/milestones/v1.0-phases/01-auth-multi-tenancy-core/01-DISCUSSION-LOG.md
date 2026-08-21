# Phase 1: Auth & Multi-tenancy Core - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-03
**Phase:** 01-auth-multi-tenancy-core
**Areas discussed:** Confirmação de email, Fluxo sem acesso, Persistência de propriedade ativa, Perfil na UI + recuperação de senha

---

## Confirmação de email

| Option | Description | Selected |
|--------|-------------|----------|
| Não — login imediato | Conta ativa após signup. Sem tela de verificação. Config local já tem enable_confirmations=false. | ✓ |
| Sim — email obrigatório | Supabase envia link. App mostra tela de espera. Requer SMTP em prod. | |
| Depende do ambiente | Dev sem confirmação, prod com. Feature flag. Mais complexo. | |

**User's choice:** Não — login imediato
**Notes:** Alinhado com config atual. MVP simples.

---

## Fluxo sem acesso

| Option | Description | Selected |
|--------|-------------|----------|
| Tela estática "sem acesso" | Mensagem explicando que precisa ser vinculado por proprietário. Sem ação do usuário. | ✓ |
| Pode criar propriedade aqui | Botão "Criar minha propriedade". Antecipa Phase 2. | |

**User's choice:** Tela estática "sem acesso"

---

## Vínculo inicial

| Option | Description | Selected |
|--------|-------------|----------|
| Via seed/admin — manual por ora | Phase 1 não tem UI de criar propriedade. Admin insere via SQL/Studio. | ✓ |
| Signup auto-cria propriedade | Ao se cadastrar, já cria propriedade no mesmo fluxo. Avança escopo. | |

**User's choice:** Via seed/admin — manual por ora

---

## Persistência de propriedade ativa

| Option | Description | Selected |
|--------|-------------|----------|
| Sim — persiste via SharedPreferences | Salva ID da propriedade ativa. Ao recarregar carrega direto. | ✓ |
| Não — volta ao seletor sempre | Cada reload limpa estado. Mais simples. | |

**User's choice:** Sim — persiste via SharedPreferences

---

## 1 propriedade — seletor ou direto

| Option | Description | Selected |
|--------|-------------|----------|
| Entra direto, sem seletor | Auto-seleciona a única propriedade. Seletor aparece só com 2+. | ✓ |
| Sempre mostra seletor | Comportamento consistente mas verboso. | |

**User's choice:** Entra direto, sem seletor

---

## Perfil na UI

| Option | Description | Selected |
|--------|-------------|----------|
| Não — só estrutura dados | property_members tem perfil. UI exibe perfil mas não bloqueia ações. Phase 2+ trata bloqueios. | ✓ |
| Sim — leitor já vira read-only | Implementa restrições por perfil no Phase 1. Antecipa todas as fases. | |

**User's choice:** Não — só estrutura dados

---

## Recuperação de senha

| Option | Description | Selected |
|--------|-------------|----------|
| Sim — incluso | Supabase envia email de reset. Flutter trata deep-link e exibe form de nova senha. | ✓ |
| Deferred — não agora | Admin reset via Supabase Studio. Simples mas incompleto para usuário real. | |

**User's choice:** Sim — incluso

---

## Claude's Discretion

- Design visual das telas (login/signup/reset) — Material 3, pt-BR
- Estrutura do authProvider Riverpod
- Estratégia de redirect no GoRouter
- Conteúdo da tela "sem acesso"

## Deferred Ideas

- Bloqueio de ações por perfil → Phase 2+
- Criação de propriedade no signup → Phase 2
- MFA / passkey → fora do MVP
- SSO / OAuth → fora do MVP
