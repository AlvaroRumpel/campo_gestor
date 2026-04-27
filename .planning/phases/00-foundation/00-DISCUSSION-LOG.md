# Phase 0: Foundation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-26
**Phase:** 00-foundation
**Areas discussed:** App shell layout, Folder structure, Supabase setup, Packages, Web renderer, Codegen baseline, Theme / brand

---

## App Shell Layout

### Navegação web

| Option | Description | Selected |
|--------|-------------|----------|
| Sidebar fixo | Painel lateral sempre visível com ícone + label | ✓ |
| NavigationRail colapsável | Ícones somente, expande ao hover | |
| Top AppBar + Drawer | Hamburger no topo | |

**User's choice:** Sidebar fixo

### Itens de navegação

| Option | Description | Selected |
|--------|-------------|----------|
| Dashboard, Piquetes, Animais, Reprod., Sanitário | 5 áreas alinhadas com módulos do app | ✓ |
| Inicio, Estrutura, Animais, Histórico | 4 itens genéricos | |
| Só 1 item placeholder | Shell mínima | |

**User's choice:** 5 items alinhados com módulos

### Mobile

| Option | Description | Selected |
|--------|-------------|----------|
| Bottom NavigationBar | Tabs na parte inferior, padrão Material 3 | ✓ |
| Drawer hamburger | Sidebar vira drawer oculto | |
| Mesmo sidebar (compact) | NavigationRail só ícones | |

**User's choice:** Bottom NavigationBar

### Header

| Option | Description | Selected |
|--------|-------------|----------|
| Nome da propriedade ativa + seletor | Dropdown para trocar propriedade | ✓ |
| Título da tela atual | Header dinâmico com página atual | |
| Logo + título fixo | Header simples com marca | |

**User's choice:** Nome da propriedade ativa + seletor

---

## Folder Structure

### Organização lib/

| Option | Description | Selected |
|--------|-------------|----------|
| Feature-first hybrid | lib/features/{feature}/ + lib/core/ | ✓ |
| Layer-first | presentation/, domain/, data/ | |
| Flat / sem estrutura agora | Organiza depois | |

**User's choice:** Feature-first hybrid

### Repository pattern

| Option | Description | Selected |
|--------|-------------|----------|
| Abstract Repository + Supabase impl | Interface Dart abstrata + implementação concreta | ✓ |
| Service classes simples | Concretas sem interface | |
| Claude decide | — | |

**User's choice:** Abstract Repository + Supabase impl

---

## Supabase Setup

### Ambiente dev

| Option | Description | Selected |
|--------|-------------|----------|
| CLI local + Docker | supabase init + supabase start, banco local | ✓ |
| Projeto hosted dev | supabase.com sem Docker | |
| Hosted + local depois | Começa hosted, migra | |

**User's choice:** CLI local + Docker
**Notes:** User não tinha Docker mas decidiu instalar. Motivo: limite de projetos atingido no Supabase free tier.

### Secrets / env vars

| Option | Description | Selected |
|--------|-------------|----------|
| dart-define + launch.json | Valores no VSCode launch.json, gitignored | ✓ |
| .env + flutter_dotenv | Arquivo .env gitignored | |
| Hardcoded em config.dart (gitignored) | Simples mas risco de vazar | |

**User's choice:** dart-define + launch.json

---

## Packages

| Option | Description | Selected |
|--------|-------------|----------|
| Tudo na Phase 0 | Stack completo instalado de uma vez | ✓ |
| Só o que a phase precisa | Incremental por fase | |
| Claude decide | — | |

**User's choice:** Tudo na Phase 0

---

## Web Renderer

| Option | Description | Selected |
|--------|-------------|----------|
| Auto (padrão Flutter) | CanvasKit desktop, HTML mobile | ✓ |
| CanvasKit fixo | Bundle maior, mais fiel | |
| WASM (experimental) | Experimental, não recomendado para MVP | |

**User's choice:** Auto

---

## Codegen Baseline

| Option | Description | Selected |
|--------|-------------|----------|
| Phase 0 junto com os packages | Instala + cria modelo exemplo para validar | |
| Phase 1 quando surgir o primeiro model real | Adia para primeira necessidade real | ✓ |

**User's choice:** Phase 1 — codegen configurado na Phase 0 mas primeiro model real na Phase 1

---

## Theme / Brand

### Paleta

| Option | Description | Selected |
|--------|-------------|----------|
| Paleta agrária (verde/terra) agora | Material 3 com seedColor verde-musgo/terra | ✓ |
| Material 3 defaults + decide depois | Placeholder teal/azul | |
| Dark mode + light mode | Ambos desde o início | |

**User's choice:** Paleta agrária agora

### Locale

| Option | Description | Selected |
|--------|-------------|----------|
| Sim, pt-BR desde o início | intl + flutter_localizations no main | ✓ |
| Não, adicionar quando necessário | Adiciona mais tarde | |

**User's choice:** pt-BR desde o início

---

## Claude's Discretion

- Cor exata do seedColor dentro da paleta "verde-musgo/terra"
- Breakpoint exato sidebar → bottom nav (padrão Material 3 600px)
- Sub-estrutura interna de lib/core/ além do definido

## Deferred Ideas

- Dark mode — pós-MVP
- CanvasKit/WASM — avaliar se performance exigir
- Codegen com modelo exemplo na Phase 0 — adiado para Phase 1
