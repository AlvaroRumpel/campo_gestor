# Phase 2: Property & Paddock Structure - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-07
**Phase:** 02-property-paddock-structure
**Areas discussed:** Property management UX, Piquetes screen design, Role enforcement, Capacidade unit

---

## Property management UX

| Option | Description | Selected |
|--------|-------------|----------|
| NoAccessScreen gets CTA | Seamless onboarding CTA on zero-property screen | ✓ (part of Both) |
| Dedicated settings page | Separate /propriedades route | ✓ (part of Both) |
| Both | CTA + dedicated route | ✓ |

**User's choice:** Both — NoAccessScreen gets CTA + dedicated `/propriedades` route accessible from PropertySelector dropdown.

| Option | Description | Selected |
|--------|-------------|----------|
| Dedicated /propriedades route via PropertySelector | Button in header dropdown | ✓ |
| Inline in PropertySelector | Clutters header | |
| Modal/dialog from AppShell | Gear icon | |

| Option | Description | Selected |
|--------|-------------|----------|
| Criador vira proprietario | Full access for creator | |
| Criador vira veterinario | Vet = primary user = full access | ✓ |

**Notes:** User clarified the role model is inverted from typical expectation: veterinário is the primary user (manages multiple farms), proprietário is the farm owner with more restricted access.

| Option | Description | Selected |
|--------|-------------|----------|
| proprietario campo = texto livre | Name of the real landowner | ✓ |
| proprietario campo = FK auth.users | Linked to system user | |

| Option | Description | Selected |
|--------|-------------|----------|
| proprietario read-only | Only view piquetes | ✓ |
| proprietario partial CRUD | Create/edit but not delete | |
| proprietario same as vet | Full access | |

| Option | Description | Selected |
|--------|-------------|----------|
| Via PropertySelector dropdown | Button "Gerenciar fazendas" in header | ✓ |
| Extra NavRail item | Sixth destination | |
| Settings icon in AppShell | Secondary action in header | |

---

## Piquetes screen design

| Option | Description | Selected |
|--------|-------------|----------|
| Mobile-first | User correction on platform priority | ✓ |

**Notes:** User corrected that the app is mobile-first, despite CLAUDE.md stating "web primário". This is a significant design driver.

| Option | Description | Selected |
|--------|-------------|----------|
| Lista vertical com FAB | Material 3 mobile standard | ✓ |
| Cards em lista (1-2 cols) | Responsive cards | |
| Cards em grid | Visual grid | |

| Option | Description | Selected |
|--------|-------------|----------|
| Nome + área + capacidade | 3 core fields | ✓ |
| Nome + área + capacidade + UA atual | Requires Phase 3 data | |
| Só nome + área | Minimal | |

| Option | Description | Selected |
|--------|-------------|----------|
| Abre tela de detalhe /piquetes/:id | Full screen navigation | ✓ |
| Bottom sheet inline | No route | |
| Nada (só ícone de editar) | Tap-safe list | |

| Option | Description | Selected |
|--------|-------------|----------|
| Some da lista | WHERE deleted_at IS NULL | ✓ |
| Aparece como inativo | Grayed out with tag | |

---

## Role enforcement

| Option | Description | Selected |
|--------|-------------|----------|
| Ações não aparecem (hidden) | Clean UI for read-only users | ✓ |
| Ações disabled (grayed out) | Visible but unclickable | |
| Ações aparecem, erro ao clicar | Permission denied snackbar | |

| Option | Description | Selected |
|--------|-------------|----------|
| RLS bloqueia INSERT/UPDATE/DELETE para não-vets | Defense in depth | ✓ |
| RLS só isola por propriedade | Simpler schema | |

---

## Capacidade unit

| Option | Description | Selected |
|--------|-------------|----------|
| UA (Unidade Animal) | Aligns with domain model | ✓ |
| Headcount | Simpler integer | |
| Ambos (UA + headcount) | Two fields | |

| Option | Description | Selected |
|--------|-------------|----------|
| Obrigatório | All 3 fields required | ✓ |
| Opcional | NULL accepted | |

| Option | Description | Selected |
|--------|-------------|----------|
| Sim, nome + área + capacidade obrigatórios | Minimum for agronomic sense | ✓ |
| Só nome obrigatório | Fast entry, fill later | |

| Option | Description | Selected |
|--------|-------------|----------|
| Decimal NUMERIC(8,2) | 12.5 UA, fractional values | ✓ |
| Inteiro | Simpler but imprecise | |

---

## Claude's Discretion

- Design visual das telas de propriedades/piquetes
- Implementação interna do RPC gerar_numero_animal (lock strategy)
- Estrutura exata das RLS policies para piquetes
- Formulário (reactive_forms já no pubspec)
- Conteúdo da tela de detalhe do piquete (Phase 3 adiciona lotes)

## Deferred Ideas

- Gerenciamento de membros (convite de usuários à fazenda)
- UA atual por piquete (requer Phase 3)
- Lotes dentro do detalhe do piquete (Phase 3)
- Capacidade em headcount além de UA
