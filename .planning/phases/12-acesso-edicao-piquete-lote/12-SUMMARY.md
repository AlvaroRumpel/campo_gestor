# Phase 12 — Acesso e edição de piquete/lote — SUMMARY

**Executado:** 2026-08-21 · milestone v1.1
**Status:** completa — flutter analyze limpo, flutter test 574/574.

## O que foi entregue

### ACES-01 — board desktop clicável
- `piquetes_board_view.dart`: cabeçalho de `_PaddockColumn` ganhou `InkWell` (abre `/piquetes/:id`) e `PopupMenuButton` Editar/Remover (vet-only). Widget continua puro: 3 callbacks novos (`onOpenPaddock`/`onEditPaddock`/`onDeletePaddock`) wired em `piquetes_screen.dart`.

### ACES-02 — piquete editável do detalhe
- `paddock_actions.dart` (novo): `editPaddock` + `confirmDeletePaddock` extraídos de `piquetes_screen.dart` (pré-checagem de lotes ativos + catch 23514 preservados verbatim).
- `PaddockDetailScreen`: menu Editar/Remover no `DetailAppBar`; remover navega de volta a `/piquetes`.

### ACES-03 — lote editável fora do detalhe do piquete
- `lote_actions.dart` (novo): `editLotName` + `archiveLot` extraídos de `_lots_section.dart` (mesma lógica, agora retornam bool).
- `LoteDetailScreen`: menu Editar nome/Arquivar no `DetailAppBar`; arquivar navega ao piquete pai.
- `LoteDetailPanel` (painel desktop 380px): mesmo menu no header verde; arquivar fecha o painel.
- `_lots_section.dart` reduzido a chamadas dos helpers (fim da cópia privada).

## Verificação
- `flutter analyze`: 0 erros/warnings (5 infos pré-existentes).
- `flutter test`: 574/574.
