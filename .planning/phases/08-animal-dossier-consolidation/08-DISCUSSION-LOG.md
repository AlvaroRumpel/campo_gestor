# Phase 8: Animal Dossier Consolidation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-11
**Phase:** 8-animal-dossier-consolidation
**Areas discussed:** Consulta e performance, Profundidade do reprodutivo, Destaque da baixa, Ordem e forma das seções, Layout em 360px, Ações a partir da ficha (+ testes e quebra em planos)

**Áreas oferecidas e não selecionadas na primeira rodada:** Layout mobile 360px (retomada depois, na rodada extra)

---

## Consulta e performance

### Forma da consulta (SC-1 <1s no 4G)

| Option | Description | Selected |
|--------|-------------|----------|
| Matar só o waterfall | Providers separados, piquete embutido na query do lote. 5 requests → 4 paralelos. D-37 intacto | ✓ |
| RPC consolidada | 1 round-trip, mas migration nova, quebra D-37, duplica lógica de 3 repositories | |
| Deixar como está e medir | Zero mudança; otimizar só se estourar 1s | |

**User's choice:** Matar só o waterfall → D-01

### Evidência do SC-1

| Option | Description | Selected |
|--------|-------------|----------|
| UAT com throttle 4G | DevTools "Fast 4G", abrir por busca de número e cronometrar. Mesmo caminho da SC-1 da Phase 0 | ✓ |
| Teste automatizado de tempo | `integration_test` não roda em web neste projeto — mediria em `-d windows` | |
| Contagem de round-trips | Critério estrutural, não é o que o SC-1 diz | |

**User's choice:** UAT com throttle 4G → D-07

### Estado de carregamento

| Option | Description | Selected |
|--------|-------------|----------|
| Render progressivo | Card aparece assim que o animal resolve; spinner por seção. Comportamento de hoje | ✓ |
| Skeleton | Melhor percepção, mas padrão novo no app | |
| Esperar tudo | Amarra o tempo da ficha ao bloco mais lento | |

**User's choice:** Render progressivo → D-02

### Cache

| Option | Description | Selected |
|--------|-------------|----------|
| Sempre refazer | Auto-dispose do Riverpod 3.x mantido; dado sempre fresco | ✓ |
| Manter em cache | Volta instantânea, mas risco de dado velho em campo | |

**User's choice:** Sempre refazer → D-03

### Erro de rede por bloco

| Option | Description | Selected |
|--------|-------------|----------|
| Botão "Tentar de novo" por bloco | Recuperação ao lado da mensagem (lição D-36 Phase 6) | ✓ |
| Um botão só na tela | Repuxa o que já carregou bem | |
| Manter como está | Bloco que falhou fica morto até o vet descobrir sozinho | |

**User's choice:** Retry por bloco → D-04

### Pull-to-refresh

| Option | Description | Selected |
|--------|-------------|----------|
| Não | Auto-dispose já cobre; padrão inexistente no app | ✓ |
| Sim | Útil com escrita concorrente, mas primeiro uso do padrão | |

**User's choice:** Não → D-05

### Truncamento assimétrico

| Option | Description | Selected |
|--------|-------------|----------|
| Deixar como está | Sanitário corta em 10, reprodutivo mostra tudo. Poucos ATFs por vida, muitas aplicações | ✓ |
| Cortar os dois em 10 | Simetria visual, mas exige destino para o "Ver todos" do reprodutivo | |
| Mostrar tudo nos dois | Scroll longo no celular, pesa o SC-1 | |

**User's choice:** Deixar como está → D-06

---

## Profundidade do reprodutivo

### DGs por ATF (SC-2)

| Option | Description | Selected |
|--------|-------------|----------|
| Todos os DGs, linha expansível | Resumo na linha, todos os DGs na expansão. Cumpre o SC-2 literal sem poluir o caso comum | ✓ |
| Todos sempre visíveis | Nada escondido, mas bloco cresce no celular | |
| Manter só o último DG | Zero trabalho, mas o verificador pode ler o SC-2 como não cumprido | |

**User's choice:** Linha expansível → D-08

### Campos extras por ATF (multi-seleção)

| Option | Description | Selected |
|--------|-------------|----------|
| Touro do ATF | Rótulo legível já resolvido na Phase 5 (WR-01/05-13) | ✓ |
| Data de implantação | Protocolo completo do ciclo junto com a inseminação | ✓ |
| Observação do DG | Texto que o vet escreveu ao registrar o DG | ✓ |
| Nada além dos DGs | Linha enxuta | |

**User's choice:** Touro + implantação + observação do DG → D-09

### Quando buscar os DGs

| Option | Description | Selected |
|--------|-------------|----------|
| Junto, na mesma query | Embed dos `dg_records`; expansão instantânea, payload de um animal só | ✓ |
| Só ao expandir | Ficha inicial mais leve, mas spinner na expansão e mais um provider | |

**User's choice:** Mesma query → D-10

### Extração do bloco

| Option | Description | Selected |
|--------|-------------|----------|
| Extrair para `reproducao/presentation` | Espelha o `AnimalSanitaryHistorySection` (D-37); bloco testável isolado | ✓ |
| Deixar privado onde está | Diff menor, mas a tela cresce e o bloco fica intestável | |

**User's choice:** Extrair → D-11

---

## Destaque da baixa

### Forma do destaque (SC-4)

| Option | Description | Selected |
|--------|-------------|----------|
| Banner no topo | `errorContainer` acima do card; padrão do banner de ATF encerrado (Phase 5) | ✓ |
| Card inteiro em cor de erro | Impossível não notar, mas prejudica a leitura dos dados | |
| Badge na AppBar | Sempre visível, mas o título já trunca em 360px | |

**User's choice:** Banner no topo → D-12

### Detalhe do motivo

| Option | Description | Selected |
|--------|-------------|----------|
| Motivo + data + observação | O CR-01 da Phase 5 anexa a observação da baixa ao `observation` | ✓ |
| Só motivo + data | Escopo literal do SC-4 | |

**User's choice:** Motivo + data + observação → D-13

### Outros efeitos do arquivamento (multi-seleção)

| Option | Description | Selected |
|--------|-------------|----------|
| Nada muda nos históricos | Histórico do animal vendido tem que continuar consultável | ✓ |
| Lote/piquete rotulados como "na época da baixa" | Só rótulo, sem dado novo | |
| Esconder ações de escrita | Já é o comportamento de hoje | |

**User's choice:** Nada muda nos históricos → D-16

### Busca por número alcança arquivado

| Option | Description | Selected |
|--------|-------------|----------|
| Sim, sempre | Buscar o número de um animal vendido é exatamente quando se quer o histórico | ✓ |
| Só com o toggle ligado | Consistente com `/animais`, mas devolve "nenhum resultado" no caso que importa | |

**User's choice:** Sim, sempre → D-17

### Linha "Status" do card

| Option | Description | Selected |
|--------|-------------|----------|
| Sai do card | Status de baixa num lugar só | ✓ |
| Fica só para animal ativo | Duas regras de renderização para o mesmo campo | |
| Fica sempre | Redundância numa tela de 360px | |

**User's choice:** Sai do card → D-15

### Visual por motivo

| Option | Description | Selected |
|--------|-------------|----------|
| Mesmo visual, texto diferente | O que importa é "esse animal saiu do rebanho" | ✓ |
| Ícone por motivo | Decisão de design que nenhuma outra tela tomou | |

**User's choice:** Mesmo visual → D-14

---

## Ordem e forma das seções

### Ordem dos blocos

| Option | Description | Selected |
|--------|-------------|----------|
| Card → Reprodutivo → Sanitário | Reprodutivo é curto e cabe sem rolar; sanitário é longo | ✓ |
| Card → Sanitário → Reprodutivo | Sanitário é a consulta mais frequente em manejo | |
| Ordem por recência | Ficha muda de forma entre animais; quebra memória muscular | |

**User's choice:** Ordem de hoje mantida → D-18

### Colapso

| Option | Description | Selected |
|--------|-------------|----------|
| Sempre abertos | O dossiê existe para mostrar tudo de uma vez | ✓ |
| Colapsáveis, abertos por padrão | Estado por seção e um toque a mais na leitura normal | |
| Colapsáveis, fechados | Contradiz o texto do SC-2 | |

**User's choice:** Sempre abertos → D-19

### Bloco vazio

| Option | Description | Selected |
|--------|-------------|----------|
| Aparece com mensagem | A ausência é informação; prova que consultou | ✓ |
| Some quando vazio | Ficha de touro jovem ficaria igual a erro de carregamento | |

**User's choice:** Aparece com mensagem → D-20

---

## Layout em 360px

| Option | Description | Selected |
|--------|-------------|----------|
| Empilhar abaixo de ~400px | `LayoutBuilder` no `_KvRow`; label em cima, valor embaixo na largura toda | ✓ |
| Só reduzir o label | 120px → 90px; nome longo ainda espremido | |
| Não mexer, só testar | "Cabe sem estourar" ≠ "lê bem no celular" | |

**User's choice:** Empilhar abaixo do limiar → D-21

---

## Ações a partir da ficha

| Option | Description | Selected |
|--------|-------------|----------|
| Não — travar como read-only | Mantém o D-13 da Phase 5; registrar por animal isolado é capacidade nova | ✓ |
| Sim, atalhos para os módulos | Os dois fluxos são de lote — o vet cairia numa tela de 50 animais | |

**User's choice:** Read-only travado → D-22

---

## Testes e execução

### Estratégia de teste

| Option | Description | Selected |
|--------|-------------|----------|
| Widget tests dos blocos + 360px | Cobre SC-2, SC-4, SC-5. Sem pgTAP — nenhum objeto de banco novo | ✓ |
| Só os blocos, sem 360px | Recorte menor, SC-5 sem rede automatizada | |
| Adicionar pgTAP mesmo assim | Nenhuma linha de SQL muda nesta fase | |

**User's choice:** Widget tests + 360px → D-23

### Quebra em planos

| Option | Description | Selected |
|--------|-------------|----------|
| 3 planos, 2 waves | W1 paralelo (dados / extração do bloco), W2 ficha + testes | ✓ |
| 1 plano só | Contexto de execução maior, zero paralelização | |
| 4+ planos | Overhead para mudanças que tocam os mesmos 3 arquivos | |

**User's choice:** 3 planos em 2 waves → D-24

---

## Claude's Discretion

- Forma exata do banner de baixa e sua posição precisa em relação ao card
- Mecânica da expansão dos DGs e formato da sub-linha de DG
- Limiar exato do `_KvRow` adaptativo e origem do breakpoint (`LayoutBuilder` vs `MediaQuery`)
- Forma do embed do piquete no lote (método novo vs estender o provider)
- Nomes de arquivo e classe do bloco reprodutivo extraído
- Como a busca por número exato passa por cima do toggle de arquivados
- Onde mora a ação de retry por bloco
- Como os widget tests fixam a largura de 360px

## Deferred Ideas

- Registrar DG ou aplicação sanitária a partir da ficha (e atalhos de navegação para esses fluxos)
- Exportar / compartilhar a ficha (PDF, print, link)
- Pull-to-refresh
- `keepAlive` / cache dos providers da ficha
- RPC/view consolidada da ficha (saída se o UAT de 4G reprovar)
- Corte + "Ver todos" no histórico reprodutivo
- Skeleton loading
- Ordenação dos blocos por recência
