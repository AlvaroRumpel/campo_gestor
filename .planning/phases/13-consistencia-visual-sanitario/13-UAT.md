---
status: complete
phase: 13-consistencia-visual-sanitario
source: 13-SUMMARY.md
started: 2026-08-21T06:05:00Z
updated: 2026-08-21T06:30:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Históricos da ficha no padrão
expected: Cards de histórico reprodutivo/sanitário iguais aos demais (r16 sem borda), badges pill coloridos, toggle sem overflow em 360px.
result: pass

### 2. Chips selecionados legíveis
expected: Timeline da ficha do animal (Tudo/Reprodução/Sanitário) e filtros da seleção de animais do IATF: chip selecionado tem texto claro sobre fundo verde (legível), não texto escuro.
result: pass
note: aprovado, mas revelou issue colateral registrada como gap G-13-2 (header da lista colapsa com painel aberto).

### 3. Busca no Sanitário
expected: Aba Aplicações: campo de busca (300px no header desktop; full-width no mobile) filtra por nome da dose, lote ou nº exato de animal.
result: pass

### 4. Filtros do Sanitário em menu ancorado
expected: Desktop: chips Lote/Dose abrem menu popup preso ao chip (não mais painel deslizando de baixo); chip ativo vira pill verde com X pra limpar.
result: pass
note: usuário pediu padronizar o alternador Aplicações|Doses no estilo pill de Piquetes|Lotes — gap G-13-4 (cosmetic).

### 5. Listas não passam sob o FAB
expected: Mobile: lista de IATFs (Reprodução) e detalhe do piquete têm respiro no fim — último card não fica escondido atrás do botão flutuante.
result: pass

### 6. Gastos do piquete com AppBar padrão
expected: Tela de gastos de um piquete: AppBar igual às outras telas de detalhe (verde, compacto, título menor, seta de voltar) — não mais título grande branco.
result: pass

### 7. Registrar aplicação com fundo padrão
expected: Tela "Registrar aplicação" (sanitário): fundo bege como o resto do app, não branco puro.
result: pass

## Summary

total: 7
passed: 7
issues: 2
pending: 0
skipped: 0

## Gaps

- gap_id: G-13-2
  truth: "Com o painel lateral da ficha aberto, o header da lista de Animais continua legível (título/subtítulo em uma linha, toolbar acomodada)"
  status: resolved
  resolved_by: fix direto (animais_table_view header responsivo <900px: título com ellipsis + controles em Wrap)
  resolved_at: 2026-08-21
  reason: "User reported: quando abre a barra lateral olha como fica a interface, toda errada — screenshot mostra 'Animais' e '59 ativos · 42,3 UA · 5 com baixa' quebrando letra por letra e toolbar espremida"
  severity: major
  test: 2
  artifacts: []
  missing: []

- gap_id: G-13-4
  truth: "Alternador de duas abas segue um único padrão no app — Sanitário (Aplicações|Doses) usa o mesmo estilo pill de Piquetes|Lotes"
  status: resolved
  resolved_by: fix direto (SegmentPill compartilhado em ui.dart; Sanitário e Piquetes usam o mesmo)
  resolved_at: 2026-08-21
  reason: "User reported: 'pq isso é assim' sobre o SegmentedButton M3 (divisa interna reta); decisão: 'temos que manter um padrão'"
  severity: cosmetic
  test: 4
  artifacts: []
  missing: []
