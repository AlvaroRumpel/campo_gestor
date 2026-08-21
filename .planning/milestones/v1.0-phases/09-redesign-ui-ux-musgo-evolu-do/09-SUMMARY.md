# Phase 9 — Redesign UI/UX "musgo evoluído" — SUMMARY (registro retroativo)

**Executado:** 2026-08-13/14 · fora do fluxo plan/execute (instrução direta do usuário: implementar o design importado do Claude Design)
**Fonte do design:** projeto Claude Design `0caf54e3-086f-46c7-a4c8-1f528faf6428`, arquivo `Campo Gestor - Redesign.dc.html` (20 frames, 1595 linhas, 100% lidas). Spec extraída completa em artefato de sessão (tokens, tipografia, anatomia por tela).
**Status:** completa — UAT visual aprovada pelo usuário no deploy em 2026-08-15 (fontes, breakpoints, sanitário de uma tela, dashboard com dados reais, DG em massa).

## O que foi entregue

### Fundação (`195b3cf`)
- Fontes empacotadas: Archivo 400–700 (UI) + IBM Plex Mono 400–700 (todo dado numérico) em `assets/fonts/` (sem google_fonts, conforme CLAUDE.md).
- `lib/core/theme/app_colors.dart`: tokens da paleta (primary `#3D5435`, bg `#F5F3EB`, CTA `#E8833A`, danger `#A32D14`, glass/gold/strip), `monoStyle()`, `capacityColor(ratio)` (semáforo ≥0.9 laranja, ≥1.0 vermelho).
- `lib/core/theme/app_theme.dart`: ThemeData M3 completo (cards r16 sem sombra, botões h48 r12, inputs foco verde, FAB laranja pill, sheets r22, dialogs r20, chips stadium).
- `lib/core/widgets/ui.dart`: StatusChip, SectionCard, EmptyState, CapacityBar, StackedBar, GlassTile, EcMeter, StatsStrip, FarmAvatar, ImmutabilityNotice, WarningBanner, `showAdaptiveForm` (sheet <600px / dialog 480px).
- `lib/core/widgets/campo_app_bar.dart`: CampoAppBar (shell) / DetailAppBar + FarmContextPill (detalhes). Shell sem AppBar próprio (fim do double-AppBar); rail verde 232px no desktop com logo/fazenda/Sair; bottom nav 68px com pill.
- Seletor de fazenda com avatar de iniciais, papel por fazenda e Sair no menu.

### Telas (`5a962e6`..`dd66146`)
- **Dashboard**: deixou de ser placeholder — KPIs reais (animais ativos, UA, UA/ha), banner "precisa de você hoje" (DGs pendentes por ATF, piquetes superlotados, com deep-links), lotação por piquete, prenhez, gastos do mês (novo `fetchExpensesByProperty`, aditivo). Desktop: header "Bom dia" + grid 2 colunas.
- **Animais**: lista densa agrupada PIQUETE·LOTE com faixa de totais; ficha com header verde (hero #N, badge UA circular, glass tiles), timeline única reprodutivo+sanitário (estorno riscado, navegação por evento), EC meter; baixa como sheet destrutivo (Venda/Morte/Descarte).
- **Piquetes/Lotes**: segmented Piquetes|Lotes — lote ganhou lista própria (dor #3 do APP_OVERVIEW resolvida); cards com semáforo de lotação; Novo lote com steppers e resumo live.
- **Reprodução**: cards ATF com borda de pendência e KPI bicolor; DG em massa com segments coloridos (Prenhe verde/Vazia vermelho/Duvidosa laranja), banner de sessão, payload só de linhas alteradas preservado; seleção com elegíveis pré-marcados e bloqueados com motivo.
- **Sanitário**: fluxo de registro de 3 passos → **uma tela** (`registrar_aplicacao_screen.dart`) com totais live e aviso de imutabilidade; detecção de duplicata mantida; `aplicacao_form_dialog` virou shim de entrada; dialogs de estorno conforme spec.
- **Gastos/Auth/Fazendas**: header hero R$ + breakdown por categoria (barra empilhada); login/signup/reset com identidade nova (AuthScaffold); fazendas com avatar.

## Decisões e mudanças de contrato visíveis
- **Vocabulário DG: Prenhe/Vazia/Duvidosa** (era Prenha/Não-prenha) — spec do design; testes atualizados.
- Nada de negócio mudou: snapshot imutável, gating por papel = ausência, numeração única, elegibilidade ATF, payload parcial de DGs — tudo pinado por testes que seguem passando.
- Adições de dados apenas aditivas: `fetchExpensesByProperty` (gastos), `loteWithPaddockListByPropertyProvider` (lotes), providers de dashboard.
- Itens de spec deliberadamente pulados (baratos de adicionar depois): "R$ por animal" no header de Gastos (exigiria query extra), trend "+18% vs mês anterior", card "Últimas aplicações" no desktop.

## Verificação
- `flutter analyze`: 0 erros/warnings novos (3 infos pré-existentes).
- `flutter test`: 360/360.
- Validação visual/UAT: **pendente** — usuário fará deploy e validação (próximo passo). Sugerido conferir: fontes carregando no web build, contraste em campo, breakpoints 360px/600px, fluxo sanitário novo, dashboard com dados reais da fazenda.

## Commits
`195b3cf` fundação · `5a962e6` dashboard · `c874c21` animais · `40085a2` piquetes+lotes · `a8349cd` reprodução · `f367b16` sanitário · `dd66146` gastos/auth/fazendas
