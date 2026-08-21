# Phase 13 — Consistência visual + Sanitário — SUMMARY

**Executado:** 2026-08-21 · milestone v1.1
**Status:** completa — flutter analyze limpo, flutter test 574/574.

## O que foi entregue

### VIS-01 — históricos pré-redesign migrados
- `sanitary_history_section.dart`: shell trocado de Card r12 com borda outline → `SectionCard` r16 padrão; badge retangular → `StatusChip` (Estornada = danger, Estorno = neutral); mensagens vazias em `AppColors.textSecondary`. Toggle "Mostrar estornadas" compactado com `FittedBox` (de quebra resolve o overflow de ~29px em 360px, débito D-37 do audit v1.0).
- `animal_reproductive_history_section.dart`: mesmo tratamento; chips `Chip` M3 → `StatusChip` com semáforo DG (Prenhe verde / Vazia vermelho / Duvidosa laranja — mesmo vocabulário do DG em massa); Ativo/Encerrado como StatusChip.

### VIS-02 — contraste de chips (WCAG)
- `chipTheme.labelStyle.color` agora é `WidgetStateColor`: selecionado = `onGreen` sobre `primary` (antes `ink` sobre `primary` ≈ 1.8:1). Conserta timeline do animal e filtros da seleção IATF sem tocar em cada tela.

### VIS-03 — radius de botão unificado
- Tema: Filled/Elevated/Outlined 12 → **14**; ~40 overrides `shape: RoundedRectangleBorder(r14)` por chamada removidos em 21 arquivos (tema vira a única fonte). Segmented continua 12; override r11 do sanitário removido.

### VIS-04 — FABs e paddings
- Decisão: FABs **não** ganharam gate `isDesktop` — nas telas apontadas pelo audit o FAB é a única affordance de criação (removê-lo mataria a função). Corrigido o problema real: bottom padding 96 nas listas de reprodução e detalhe do piquete (conteúdo não passa mais sob o FAB).

### VIS-05 — Sanitário alinhado
- Busca nova (única lista sem busca no app): desktop 300px no header, mobile full-width acima dos filtros; filtra por dose, lote ou nº de animal exato.
- Filtros lote/dose migrados para `FilterMenuChip` (o componente de Animais) — popup anexado nos dois breakpoints; **fim do bottom-sheet de filtro em desktop** e da 5ª duplicata de chip (altura 34 padronizada, inclusive período/animal).
- `RegistrarAplicacaoScreen` deixou de forçar fundo branco — herda o bone padrão.

### VIS-06 — confirmações destrutivas
- Decisão documentada (sem mudança de código): confirm simples sim/não = `AlertDialog` centrado; confirm com input (baixa com motivo, arquivar fazenda digitando nome, encerrar IATF) = `showAdaptiveForm`. O código já segue a regra.

### VIS-07 — Gastos
- `gastos_screen.dart`: AppBar cru substituído por `DetailAppBar` (título 14 `onGreenSecondary`, h48, back padrão — igual a todos os detalhes).

### VIS-08 — empty states desktop
- `EmptyState` no lugar de `Text` cru em: animais_table_view, lotes_table_view, sanitario_table_views, iatf_dg_table_view. (Dialogs de mover mantêm texto simples — proporcional ao espaço.)

## Verificação
- `flutter analyze`: 0 erros/warnings (5 infos pré-existentes).
- `flutter test`: 574/574.
