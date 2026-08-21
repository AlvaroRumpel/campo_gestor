---
status: complete
phase: 12-acesso-edicao-piquete-lote
source: 12-SUMMARY.md
started: 2026-08-21T05:40:00Z
updated: 2026-08-21T06:00:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Piquete clicável no board desktop
expected: Clicar no cabeçalho da coluna do quadro abre /piquetes/:id (detalhe do piquete).
result: pass

### 2. Menu do piquete no board
expected: Como veterinário, o cabeçalho da coluna mostra um menu ⋮ com Editar (abre o formulário preenchido) e Remover (vermelho).
result: pass

### 3. Editar/Remover no detalhe do piquete
expected: No detalhe do piquete, menu ⋮ no AppBar. Editar salva mudanças de nome/área/capacidade. Remover com lotes ativos bloqueia com mensagem "Mova ou arquive os lotes antes"; sem lotes, remove e volta pra lista.
result: pass

### 4. Editar nome/Arquivar lote no detalhe do lote
expected: Na tela do lote (/lotes/:id), menu ⋮ no AppBar com Editar nome (dialog só de nome) e Arquivar lote. Arquivar com animais ativos bloqueia com mensagem; sem animais, arquiva e navega ao piquete pai.
result: pass

### 5. Menu do lote no painel lateral (desktop)
expected: No painel lateral de 380px (selecionando um lote no quadro/tabela), menu ⋮ no header verde com as mesmas ações; arquivar fecha o painel.
result: pass

## Summary

total: 5
passed: 5
issues: 0
pending: 0
skipped: 0

## Gaps

[none yet]
