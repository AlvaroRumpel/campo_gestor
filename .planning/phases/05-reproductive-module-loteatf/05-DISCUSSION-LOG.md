# Phase 5: Reproductive Module (LoteATF) - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-04
**Phase:** 5-reproductive-module-loteatf
**Areas discussed:** Modelagem do touro, Navegação e escopo do ATF, Seleção de animais no ATF, Registro de DG, Encerramento e % prenhez, Histórico reprodutivo na ficha, Baixa de animal em ATF ativo, Isolamento multi-tenant

---

## Modelagem do touro (REPR-01)

| Option | Description | Selected |
|--------|-------------|----------|
| Texto livre | Igual proprietário na Phase 2. Zero schema novo, zero CRUD | |
| Animal da propriedade | FK para animals com category='touro'. Quebra com sêmen comprado de fora | |
| Você decide | Planner escolhe | |
| **Híbrido (free text)** | FK opcional para animal da propriedade OU campo livre quando o touro é de fora | ✓ |

**User's choice:** free-text — "Pode ser um animal da propriedade ou um campo livre caso seja de fora"
**Notes:** Vira `bull_animal_id uuid NULL` + `bull_name text NULL`; UI com search-select + opção "Outro / sêmen externo". Captado como D-05.

---

## Navegação e escopo do ATF

### Onde vive a lista de LoteATFs

| Option | Description | Selected |
|--------|-------------|----------|
| Branch /reproducao | Aba já existe vazia no AppShell; ATF é entidade property-level | ✓ |
| Dentro do piquete | Como lotes operacionais (D-01 Phase 3), mas ATF não pertence a piquete | |
| Dentro do lote operacional | Simplifica seleção, impede ATF misturando lotes | |

### Rota de detalhe

| Option | Description | Selected |
|--------|-------------|----------|
| /atf/:id root-level | Mesmo padrão de /lotes/:loteId (D-03); acessível de qualquer contexto | ✓ |
| Sub-rota /reproducao/:id | Mantém nav lateral destacada, mas gera beco sem saída vindo de fora | |

### Ativos vs encerrados

| Option | Description | Selected |
|--------|-------------|----------|
| Toggle "Mostrar encerrados" | Mesmo padrão de D-21 (animais arquivados) | ✓ |
| Duas abas | Mais explícito, mas introduz padrão de tabs inexistente no app | |
| Tudo junto por data | Simples, mas encerrados enterram os ativos | |

### Conteúdo do card

| Option | Description | Selected |
|--------|-------------|----------|
| Nome + datas + nº animais + % prenhez | Estado do ciclo de relance | ✓ |
| Nome + nº animais + status DG | Foco na ação pendente | |
| Você decide | Planner define | |

**Notes:** Captado como D-01 a D-04.

---

## Seleção de animais no ATF

### Fluxo de seleção

| Option | Description | Selected |
|--------|-------------|----------|
| Lista filtrada da propriedade | Checkbox por animal com busca e filtros; mais flexível | |
| Puxar lote operacional inteiro | Rápido no caso comum, trava ATF multi-lote | |
| Lote inteiro + adicionar avulsos | Começa de um lote e permite somar animais de outros | ✓ |

### Animal já em ATF ativo

| Option | Description | Selected |
|--------|-------------|----------|
| Aparece desabilitado com motivo | Linha acinzentada com o nome do ATF que o prende (SC-2) | ✓ |
| Some da lista | Mais limpo, mas o vet procura e não acha sem explicação | |
| Erro só na confirmação | Deixa o erro pro final, pior UX | |

### Editar composição depois

| Option | Description | Selected |
|--------|-------------|----------|
| Add/remove enquanto ativo | Realidade de campo: animal entra atrasado ou sai do protocolo | ✓ |
| Composição fechada na criação | Simples, mas ATF é ciclo em andamento, não snapshot | |
| Só adicionar, nunca remover | Prende animal que saiu do protocolo | |

### Onde valida "só vacas e novilhas"

| Option | Description | Selected |
|--------|-------------|----------|
| UI + CHECK no banco | Lição da Phase 4: PATCH cru contorna a UI | ✓ |
| Só na UI | Menos SQL, mas sem guarda final | |

**Notes:** Captado como D-06 a D-09.

---

## Registro de DG

### Formato da tela

| Option | Description | Selected |
|--------|-------------|----------|
| Lista em massa no ATF | Chips prenha/não-prenha/duvidosa por linha, salva de uma vez | ✓ |
| Dialog individual por animal | Mais espaço pra observação, 50 dialogs num ATF de 50 | |
| Massa + dialog pra detalhe | Cobre os dois casos, mais UI | |

### Data do DG

| Option | Description | Selected |
|--------|-------------|----------|
| Uma data pra sessão, editável por animal | DG é feito num dia só, com o vet na fazenda | ✓ |
| Sempre por animal | Mais preciso, digita a mesma data 50 vezes | |
| created_at não editável | Zero UI, quebra quando lança dias depois | |

### Múltiplos DGs por animal no mesmo ATF

| Option | Description | Selected |
|--------|-------------|----------|
| Sim, histórico de DGs | Duvidosa vira prenha no reexame; custa tabela dg_records | ✓ |
| Um só, editável | Schema mais simples, perde o rastro da mudança de resultado | |

### Registrar DG pela ficha do animal

| Option | Description | Selected |
|--------|-------------|----------|
| Não — só pela tela do ATF | Menos superfície de escrita; ficha fica leitura | ✓ |
| Sim, atalho na ficha | Útil pra correção pontual, duplica caminho de escrita | |

**Notes:** Captado como D-10 a D-13.

---

## Encerramento e % prenhez

### Modo de encerramento

| Option | Description | Selected |
|--------|-------------|----------|
| Manual + alerta em 100% dos DGs | Recomendação da decisão aberta #3 do research/SUMMARY.md | ✓ |
| Automático ao completar DGs | Fecha antes do reexame das duvidosas | |
| Só manual, sem alerta | ATF fica ativo pra sempre e trava os animais | |

### Efeito do encerramento

| Option | Description | Selected |
|--------|-------------|----------|
| active=false, libera pro próximo ATF | Partial unique index já existente solta o animal | ✓ |
| Também congela o ATF (read-only) | Exige reabertura pra corrigir digitação | |
| Você decide | Planner define | |

### Duvidosa no % prenhez

| Option | Description | Selected |
|--------|-------------|----------|
| Denominador sim, numerador não | Fórmula literal do SC-4 / REPR-04 | ✓ |
| Fora do cálculo | Diverge do requisito escrito | |
| Conta como prenha | Infla o índice | |

### Exibição com DGs pendentes

| Option | Description | Selected |
|--------|-------------|----------|
| % parcial + progresso dos DGs | "62% prenhez (31/50 DG · 12 pendentes)" | ✓ |
| Só o % | 62% de 50 e 62% de 5 parecem iguais | |
| Esconder até 100% | Contraria SC-4 | |

**Notes:** Captado como D-15 a D-18.

---

## Histórico reprodutivo na ficha (REPR-05)

| Option | Description | Selected |
|--------|-------------|----------|
| Lista de ATFs + último DG + link | Nome, data insem., badge do último DG, status; tap → /atf/:id | ✓ |
| Lista + todos os DGs expandidos | Mais informação, ficha longa em animal com 5 ciclos | |
| Só o ATF ativo atual | Entrega menos do REPR-05 | |

**Notes:** Captado como D-14. Timeline expandida foi para deferred (reconsiderar na Phase 8).

---

## Baixa de animal em ATF ativo

### Comportamento

| Option | Description | Selected |
|--------|-------------|----------|
| Sai do ATF, histórico preservado | membership active=false na mesma transação, sem dialog extra | ✓ |
| Avisa e pede confirmação | Mais seguro contra clique errado, uma tela a mais | |
| Bloqueia até encerrar o ATF | Vaca morre no meio do protocolo — não dá pra impedir | |

### Efeito no % prenhez

| Option | Description | Selected |
|--------|-------------|----------|
| Conta se tinha DG registrado | Mantém o % do ATF estável ao longo do tempo | ✓ |
| Sai do cálculo de vez | Muda o número retroativamente | |
| Você decide | Planner define | |

**Notes:** Captado como D-19 e D-20.

---

## Isolamento multi-tenant

| Option | Description | Selected |
|--------|-------------|----------|
| Padrão Phase 4 completo | property_id + RLS FORCE + trigger de isolamento + RPC SECURITY DEFINER | ✓ |
| RLS + trigger, sem RPC | 50 DGs viram 50 requests sem atomicidade | |
| Só RLS | Foi o que reabriu duas vezes no code review da Phase 4 | |

**Notes:** Captado como D-21.

---

## Claude's Discretion

- Nomes exatos de tabelas e colunas (`atf_batches` / `dg_records` são sugestões)
- Se `dg_records` referencia a membership ou o par (atf_batch_id, animal_id)
- Se o % prenhez é calculado em SQL (view/função) ou no cliente
- Layout interno do detalhe do ATF e escolha entre `data_table_2` e ListView
- Mecânica exata do alerta "todos os DGs preenchidos"
- Paginação/virtualização da lista de DG em ATFs grandes

## Deferred Ideas

- Ficha consolidada reprodutivo + sanitário — Phase 8 (ANIM-03)
- Timeline expandida de todos os DGs na ficha do animal — reconsiderar na Phase 8
- Congelar ATF encerrado como somente-leitura — só se virar requisito de auditoria
- Métricas reprodutivas agregadas (prenhez por touro/lote/safra) — pós-MVP
- Protocolo hormonal / cronograma de manejo IATF — módulo novo, sem REQ
- Repasse com touro de monta natural após o ATF — fora dos 5 REQs
