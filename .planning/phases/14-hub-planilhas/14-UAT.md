---
status: complete
phase: 14-hub-planilhas
source: 14-SUMMARY.md
started: 2026-08-21T06:35:00Z
updated: 2026-08-21T06:35:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Menu Planilhas abre o hub
expected: Item "Planilhas" no rail desktop; tela com chips de entidade + Exportar/Importar + grade.
result: pass
note: "funciona, mas é completamente feio" — polimento registrado como gap G-14-1.

### 2. Grade de Lotes
expected: Chip Lotes: renomear um lote (célula Nome) e trocar o piquete (dropdown); barra escura de salvar aparece; salvar aplica e as telas de Piquetes/Lotes refletem.
result: pass

### 3. Grade de Piquetes
expected: Chip Piquetes: editar área (ha) e capacidade (UA); salvar aplica (semáforo de lotação do board reflete a capacidade nova).
result: pass

### 4. Grade de Gastos
expected: Chip Gastos: só gastos manuais listados (linhas sanitárias ficam de fora); editar valor/categoria/data e salvar aplica.
result: pass

### 5. Colar do Excel
expected: Numa grade do hub, selecionar célula e Ctrl+V com bloco copiado do Excel preenche várias células; valores inválidos marcam a célula em vermelho e bloqueiam salvar.
result: pass

### 6. Export e Import das entidades novas
expected: Exportar baixa .xlsx da entidade ativa. Importar abre o fluxo de 3 passos (com modelo baixável) para Lotes/Piquetes/Gastos; linha com erro (ex.: piquete inexistente) aparece no preview e nada é gravado se o servidor rejeitar.
result: issue
reported: "ao clicar em escolher arquivo esse erro acontece — Uncaught Error (stack minificado main.dart.js) no import de Piquetes"
severity: blocker

### 7. Hub no celular
expected: Mobile: hub mostra aviso "edição em grade é para telas maiores"; Exportar continua funcionando.
result: pass

## Summary

total: 7
passed: 6
issues: 2
pending: 0
skipped: 0

## Gaps

- gap_id: G-14-1
  truth: "Hub Planilhas com visual no padrão do app — sem dica duplicada, grade contida num card/surface com bordas"
  status: failed
  reason: "User reported: 'funciona, mas é completamente feio' — linha de dicas Ctrl+V aparece duas vezes, grade solta no fundo bege sem container"
  severity: cosmetic
  test: 1
  artifacts: []
  missing: []

- gap_id: G-14-6
  truth: "Clicar 'Escolher arquivo' no import abre o seletor de arquivo em todas as entidades"
  status: failed
  reason: "User reported: Uncaught Error (main.dart.js, stack minificado) ao clicar em Escolher arquivo no import de Piquetes"
  severity: blocker
  test: 6
  artifacts: []
  missing: []
