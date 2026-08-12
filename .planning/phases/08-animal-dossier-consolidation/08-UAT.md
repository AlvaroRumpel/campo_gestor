---
status: complete
phase: 08-animal-dossier-consolidation
source: [08-01-SUMMARY.md, 08-02-SUMMARY.md, 08-03-SUMMARY.md, 08-04-SUMMARY.md, 08-05-SUMMARY.md]
started: 2026-08-12T00:00:49Z
updated: 2026-08-12T00:04:00Z
---

## Current Test

[testing complete]

## Tests

### 1. LoteRepository.fetchLotWithPaddockName + loteWithPaddockByIdProvider resolvem lote e nome do piquete em um único select embedded do PostgREST, com loteByIdProvider intacto para os consumidores existentes
expected: same
result: pass
source: automated
coverage_id: 08-01-D1

### 2. ReproductiveHistoryEntry carrega a lista ordenada completa de dgRecords por ATF mais bullName/implantationDate, com o resumo lastDgResult/lastDgDate inalterado, vindo da query fetchReproductiveHistory existente sem requests extras
expected: same
result: pass
source: automated
coverage_id: 08-01-D2

### 3. AnimalReproductiveHistorySection é um widget público em lib/features/reproducao/presentation/, construtor id-only, resolvendo seu próprio provider — simétrico a AnimalSanitaryHistorySection
expected: same
result: pass
source: automated
coverage_id: 08-02-D1

### 4. animal_detail_screen.dart compõe o widget extraído e não declara mais nenhuma classe de renderização de histórico reprodutivo; os 6 testes de Histórico Reprodutivo passam sem edição no arquivo de teste
expected: same
result: pass
source: automated
coverage_id: 08-02-D2

### 5. Estado de erro do bloco sanitário (variantes animal e lote) renderiza a cópia de erro inalterada mais um TextButton "Tentar novamente" que invalida apenas a instância de família daquele bloco
expected: same
result: pass
source: automated
coverage_id: 08-03-D1

### 6. Fronteira D-37 mantida: o diff em sanitary_history_section.dart toca apenas os dois branches error:; sanitary_application_repository.dart ausente do diff
expected: same
result: pass
source: automated
coverage_id: 08-03-D2

### 7. AnimaisScreen busca por número exato encontra animal arquivado com o toggle "Mostrar arquivados" desligado; match parcial ainda respeita o toggle; todo animal arquivado exibido sempre carrega o badge de motivo da baixa
expected: same
result: pass
source: automated
coverage_id: 08-03-D3

### 8. Animal arquivado mostra banner errorContainer full-width (motivo, data, observação) como primeiro elemento da ficha, acima do AnimalInfoCard; animal ativo não mostra banner nem texto de status duplicado no card (SC-4, D-12..D-15)
expected: same
result: pass
source: automated
coverage_id: 08-04-D1

### 9. _KvRow empilha label acima do valor abaixo de 400px de largura e mantém a linha de label de 120px a partir dela; nomes longos de lote/piquete e observações longas de baixa não estouram em 360px (SC-5, D-21)
expected: same
result: pass
source: automated
coverage_id: 08-04-D2

### 10. Linhas Lote atual / Piquete atual do AnimalInfoCard resolvem de uma única leitura loteWithPaddockByIdProvider em vez de dois watches encadeados; leitura com falha degrada apenas essas duas linhas para travessão sem esconder os campos do próprio animal (D-01)
expected: same
result: pass
source: automated
coverage_id: 08-04-D3

### 11. Linha de ATF mostra nome do touro (quando presente) e data de implantação; ATFs com 0/1 DG renderizam a linha colapsada inalterada; ATFs com 2+ DGs ganham ExpansionTile revelando todos os DGs ordenados desc por data de exame, cada um com data/chip/observação, observação quebrando linha (sem truncar) em 360px
expected: same
result: pass
source: automated
coverage_id: 08-05-D1

### 12. Toque no texto do nome da ATF navega para /atf/:atfId com ou sem o chevron de expansão presente; toque no chevron expande e não navega
expected: same
result: pass
source: automated
coverage_id: 08-05-D2

### 13. Estado de erro do bloco reprodutivo renderiza a cópia de erro inalterada mais um TextButton "Tentar novamente" que invalida apenas reproductiveHistoryByAnimalProvider(animalId); testes de regressão de erro/read-only em animal_detail_screen_test.dart seguem verdes
expected: same
result: pass
source: automated
coverage_id: 08-05-D3

### 14. SC-1 — Abertura da ficha sob 4G (<1s, 4 requests)
expected: Com DevTools → Network em throttle "Fast 4G" e log limpo, buscar o animal pelo número exato e tocar no resultado. Do toque até a ficha totalmente pintada (card + ambos os históricos, sem spinner): menos de 1s de wall-clock, e exatamente 4 requests ao Supabase.
result: pass
coverage_id: 08-04-D4

### 15. Banner de baixa em 360px — sem overflow visual
expected: Com a janela do navegador em 360px de largura (DevTools device toolbar), abrir a ficha de um animal arquivado que tenha observação de baixa longa. O texto do banner (motivo + data + observação) deve quebrar em várias linhas dentro do banner vermelho, sem cortar, sem "..." e sem faixa listrada amarela/preta de overflow no próprio banner. Ignorar o overflow já conhecido no cabeçalho do Histórico Sanitário (pré-existente, fora do escopo da fase).
result: pass

## Summary

total: 15
passed: 15
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

[none yet]
