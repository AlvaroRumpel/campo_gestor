# Features Research — Campo Gestor (Gestão de Pecuária)

**Domain:** Pecuária de corte e reprodutiva — gestão de propriedades rurais
**Researched:** 2026-04-24
**Confidence:** MEDIUM (based on training data of agro-tech domain; WebSearch unavailable — flag for validation with real users/vets)
**Note:** Research below comes from general domain knowledge of Brazilian/LATAM livestock management software (Prodap SIGNUS, BoiGordo, Pecege, ConectaBoi, Gestagro, Fazenda em Mente, Rural Pro) and international references (CattleMax, Ranchr, Herdwatch, Cattle Manager). Claims marked LOW are unverified without primary research.

---

## Table Stakes (Must Have)

Features where users abandon the product if missing. Non-negotiable for MVP or early post-MVP.

### Estrutura & Cadastro

| Feature | Description | Complexity | Priority |
|---------|-------------|------------|----------|
| **Cadastro de propriedade** | Nome, localização textual (cidade/UF), área em ha, proprietário vinculado | Low | MVP |
| **Cadastro de piquetes** | Nome/identificador, área em ha, capacidade de suporte em UA, propriedade pai | Low | MVP |
| **Cadastro de lotes operacionais** | Nome, piquete atual, tipo (cria/recria/engorda/reprodutivo), status (ativo/inativo) | Low | MVP |
| **Cadastro individual de animal** | Número único por propriedade, categoria (vaca/touro/novilho...), data nascimento, peso, estado corporal, brinco/chip (opcional), lote atual | Med | MVP |
| **Numeração automática** | Geração de número sequencial por propriedade ao criar animal (lock no banco) | Med | MVP |
| **Categorias predefinidas com UA** | vaca (1.0), touro (1.5), boi (1.5), novilho/a (0.75), terneiro/a (0.5) | Low | MVP |
| **Estado corporal 1–5** | Escala visual padrão da pecuária (ECC) | Low | MVP |

### Movimentação de Animais

| Feature | Description | Complexity | Priority |
|---------|-------------|------------|----------|
| **Mover animal entre lotes** | Transferência individual com data registrada | Low | MVP |
| **Mover lote inteiro entre piquetes** | Operação em massa — fundamental no manejo diário | Low | MVP |
| **Composição atual do lote** | Listar animais ativos no lote com contagens por categoria | Low | MVP |
| **Entrada de animal em lote** | Adicionar animal existente ou criar novo diretamente no lote | Low | MVP |
| **Saída/baixa de animal** | Remover com motivo (venda/morte/transferência/abate) e data — soft delete preservando histórico | Med | MVP |

### Reprodutivo (ATF/IATF)

Fluxo crítico para pecuária reprodutiva. Este é o core value do produto.

| Feature | Description | Complexity | Priority |
|---------|-------------|------------|----------|
| **Criar Lote ATF** | Data de início, protocolo (opcional), veterinário responsável, animais selecionados (apenas vacas/novilhas) | Med | MVP |
| **Validação: 1 ATF ativo por animal** | Impedir inclusão de animal em ATF ativo se já está em outro | Med | MVP |
| **Registro de inseminação (D0/IATF)** | Data, touro/sêmen utilizado, observação por animal | Med | MVP |
| **Diagnóstico de Gestação (DG)** | Por animal: positivo/negativo/duvidoso, data, idade gestacional estimada, veterinário | Med | MVP |
| **% de prenhez do lote ATF** | Cálculo automático = (positivos / total diagnosticado) — indicador crítico do setor | Low | MVP |
| **Histórico reprodutivo por animal** | Timeline: todas IATFs, DGs, partos que o animal participou | Med | MVP |
| **Encerramento de Lote ATF** | Status finalizado preserva histórico; libera animais para novo ATF | Low | MVP |

### Sanitário

| Feature | Description | Complexity | Priority |
|---------|-------------|------------|----------|
| **Registrar aplicação sanitária** | Produto, dose, via (oral/injetável/tópica), data, veterinário, lote alvo | Med | MVP |
| **Snapshot de composição** | Congelamento da lista de animais do lote no momento da aplicação (imutável) | High | MVP |
| **Tipos: vacina, vermífugo, antibiótico, hormônio, suplemento** | Classificação padrão para filtros e relatórios | Low | MVP |
| **Histórico sanitário por animal** | Todas aplicações que incidiram sobre o animal (via snapshot) | Med | MVP |
| **Histórico sanitário por lote** | Todas aplicações no lote ordenadas por data | Low | MVP |
| **Campo "observações" na aplicação** | Texto livre (efeitos, lote de fabricação do produto, etc.) | Low | MVP |

### Gastos / Financeiro Básico

| Feature | Description | Complexity | Priority |
|---------|-------------|------------|----------|
| **Registrar gasto por piquete** | Categoria (insumo/manutenção/mão-de-obra/medicamento), valor, data, descrição | Low | MVP |
| **Total acumulado por piquete** | Soma simples por período | Low | MVP |
| **Gasto por categoria** | Breakdown dos custos por tipo | Low | MVP |

### Autenticação & Multitenancy

| Feature | Description | Complexity | Priority |
|---------|-------------|------------|----------|
| **Login email/senha** | Supabase Auth básico | Low | MVP |
| **Perfis: proprietário, veterinário, leitor** | Perfis simples (sem granularidade por módulo no MVP) | Med | MVP |
| **Veterinário vinculado a múltiplas propriedades** | Tabela de permissões N:N usuario↔propriedade | Med | MVP |
| **Seleção de propriedade ativa** | Seletor no topo quando usuário tem múltiplas propriedades | Low | MVP |
| **RLS (Row Level Security)** | Isolamento de dados por propriedade via Supabase RLS | High | MVP |

### Consulta & Listagens

| Feature | Description | Complexity | Priority |
|---------|-------------|------------|----------|
| **Listar animais com filtros básicos** | Por categoria, lote, piquete, status | Low | MVP |
| **Busca por número do animal** | Campo de busca rápida — uso frequente em campo | Low | MVP |
| **Ficha do animal** | Tela consolidada: dados, lote atual, histórico reprodutivo, histórico sanitário | Med | MVP |
| **Lista de lotes por propriedade** | Com contagem de animais e UA total | Low | MVP |

---

## Differentiators (Competitive Advantage)

Features que criam vantagem competitiva. A maioria dos concorrentes falha em pelo menos um destes.

### Experiência de Campo

| Feature | Description | Why It Differentiates |
|---------|-------------|------------------------|
| **Lançamento em lote rápido** | "Aplicar em todos do lote" com 2 taps — não forçar seleção individual | Prodap/BoiGordo exigem muitos cliques; fluxo veterinário em campo precisa ser rápido |
| **Histórico reprodutivo visual por animal** | Timeline clara mostrando ciclos, DG, parto lado a lado — não tabela | Concorrentes mostram planilhas; veterinário precisa identificar padrões visualmente |
| **Ficha do animal como tela central** | Um toque no número do animal leva para ficha completa consultável offline no browser | Muitos concorrentes enterram essa tela em 3+ níveis de menu |
| **Web-first responsivo** | Funciona bem no desktop (veterinário no escritório) E no celular (em campo) | Concorrentes ou são só mobile (BoiGordo) ou só desktop pesado (Prodap SIGNUS) |

### Core Value (Histórico Técnico do Animal)

| Feature | Description | Why It Differentiates |
|---------|-------------|------------------------|
| **Snapshot sanitário imutável** | Garante que mudanças de composição não reescrevem histórico | Diferencia de sistemas "vivos" que perdem rastreabilidade quando animais mudam de lote |
| **Número único por propriedade** | Veterinário referencia animal sem ambiguidade ("vaca 342" é única) | Muitos sistemas usam ID interno + brinco + número; confunde comunicação |
| **Lote ATF como entidade temporal independente** | Separa claramente "estrutura física" (piquete/lote) de "evento reprodutivo" (ATF) | Sistemas que misturam os dois geram confusão e relatórios ruins |

### Relatórios Técnicos

| Feature | Description | Why It Differentiates |
|---------|-------------|------------------------|
| **Indicadores reprodutivos padrão** | % prenhez, IEP (intervalo entre partos), taxa de concepção por ATF | Consultor veterinário precisa entregar esses números ao produtor — embutir automaticamente |
| **Lotação (UA/ha) por piquete em tempo real** | Cálculo vivo que atualiza ao mover lotes | Decisão-chave do manejo de pastagem — concorrentes costumam deixar como relatório pós-hoc |
| **Custo médio por animal por período** | Gastos do piquete / cabeças presentes × dias | Proprietário quer ver ROI por lote/piquete — feature frequentemente mal implementada |

### Papéis de Acesso

| Feature | Description | Why It Differentiates |
|---------|-------------|------------------------|
| **Perfil "leitor" para investidor/sócio** | Consulta de indicadores sem poder editar | Raro em concorrentes; família do proprietário ou sócios pedem acesso frequentemente |
| **Veterinário multifazenda nativo** | UX desenhada para trocar de fazenda fluidamente | Concorrentes forçam login/logout ou fazem multi-tenant mal |

---

## Anti-Features (Don't Build)

Armadilhas conhecidas no domínio. Deliberadamente excluídas para preservar foco e simplicidade.

| Anti-Feature | Why It's a Trap |
|--------------|-----------------|
| **Mapa e geolocalização de piquetes** | Já explícito em Out of Scope. Enorme complexidade (mapas, GPS, offline, sincronização de polígonos). Usuário desenha em papel/WhatsApp — não precisa no MVP. |
| **Histórico detalhado de composição passada do lote** | Já em Out of Scope. Rastreabilidade vem do histórico por animal (movimentações), não por "fotografias do lote no tempo". Tentativa de reconstruir composição histórica explode custos de storage e consultas. |
| **Estoque de medicamentos/insumos** | Requer lotes, validades, entradas/saídas, inventário físico. Vira sistema de estoque completo. MVP registra o CUSTO da aplicação, não o inventário. |
| **Compra e venda de animais com financeiro completo** | Já em Out of Scope. Requer notas fiscais, GTA, integração financeira, DRE — módulo contábil paralelo. Escopo separado. |
| **Permissões granulares por módulo** | Já em Out of Scope. 3 perfis resolvem 95% dos casos. RBAC granular vira projeto próprio com UI complexa. |
| **Offline-first com sincronização** | Já em Constraints. Sincronização de dados reprodutivos/sanitários com conflitos é problema NP-difícil. Assumir conectividade no MVP; revisitar com evidência real de fricção. |
| **Balança eletrônica / integração com leitor de brinco RFID** | Hardware, drivers, suporte, dispositivos variados. 0,1% dos usuários iniciais. V3+ com parceiro. |
| **Genealogia profunda (árvore de descendência multi-geração)** | Útil mas complexidade alta (grafo recursivo, UI de árvore). Parto gera apenas "mãe→cria" no MVP — árvore completa é V2+. |
| **Dashboard com gráficos avançados** | Já em Out of Scope. Tentação enorme ("vamos fazer um dashboard bonito"). Usuário real quer DADOS corretos acessíveis, não visualizações. Números em tabela bastam no MVP. |
| **Notificações push / alertas automáticos** | Requer serviço de push, preferências por usuário, agendamento, e-mail/SMS fallback. MVP mostra alertas na tela ao fazer login. |
| **Controle de pastagem (forrageira, altura de capim)** | Módulo agronômico separado. Pecuária extensiva precisa, mas é outro produto. Não misturar. |
| **Integração com ERP / contabilidade** | Requer conectores, mapeamentos, suporte a múltiplos ERPs. Exportar CSV resolve o caso real inicial. |

---

## V2+ Features (Valuable, Defer)

Features valiosas mas não MVP. Ordenadas por probabilidade de entrar em V2 vs V3+.

### Provável V2 (3–6 meses pós-MVP)

| Feature | Why Defer | Trigger for Building |
|---------|-----------|----------------------|
| **Registro de parto** | Fecha o ciclo reprodutivo (ATF → DG+ → parto → cria). MVP pode ter DG+ como "fim de ciclo", parto entra em V2. | >60% dos usuários têm DGs positivos com 9+ meses sem registro de nascimento |
| **Vinculação mãe↔cria** | Depende de parto. Genealogia de 1 geração. | Uma vez que parto existe, cria automática com vínculo |
| **Pesagens periódicas (histórico de peso)** | MVP guarda só peso atual/último. Histórico vira série temporal. | Proprietário pede curva de GMD (ganho médio diário) |
| **Exportação CSV/Excel** | Contador/consultor pede dados. | Primeiros 5 pedidos explícitos |
| **Relatório de sanitário por produto** | "Quantas doses de X usei este ano?" | Veterinário ou auditoria MAPA |
| **Calendário sanitário (protocolos agendados)** | Vacinação obrigatória (aftosa, brucelose) tem calendário. | Usuário perde janela de vacinação |
| **Protocolos reprodutivos reutilizáveis** | Template de ATF (D0/D8/D10/D11) para reaplicar. | Veterinário repete o mesmo protocolo 3+ vezes |
| **Anexos em registros** | Fotos de aplicação, laudos de DG, PDFs de exame. | Pedido recorrente de "anexar laudo" |
| **Relatório mensal/periódico em PDF** | Consultor envia ao proprietário. | Primeiro consultor que pede |

### Provável V3+ (6+ meses, demanda incerta)

| Feature | Why Defer | Trigger |
|---------|-----------|---------|
| **Geolocalização de piquetes (mapa)** | Visual, mas adiciona MapBox/Leaflet, offline complexity. | Demanda forte e recorrente |
| **Aplicativo offline-first com sync** | Só se conectividade em campo for bloqueante real. | >30% de usuários relatam fricção por sinal |
| **Integração com leitor de brinco / RFID** | Hardware-dependente. | Fazendas industriais começarem a usar |
| **GTA / Integração com órgãos oficiais (MAPA)** | Regulatório regional, muda. | Demanda governamental ou fiscal |
| **Módulo de pastagem (fenologia, altura)** | Produto adjacente. | Decisão estratégica de expandir |
| **Genealogia multi-geração (árvore)** | Complexo. | Usuários de reprodução de elite |
| **Nutrição / formulação de ração** | Produto adjacente. | Decisão estratégica |
| **Compra/venda de animais + GTA** | Módulo completo. | Proprietário pede formalmente |
| **Estoque de insumos** | Módulo completo. | Fazenda grande pede |
| **App mobile nativo dedicado** | Flutter web já entrega no MVP. | Performance web móvel insuficiente |
| **Módulo financeiro completo (DRE, fluxo caixa)** | Contábil. | Proprietário abandona concorrente contábil |
| **Integrações ERP** | Sob demanda. | Cliente grande exige |

---

## Competitor Analysis

Confidence LOW — baseado em conhecimento de treinamento, não em avaliação direta atualizada. Validar com pesquisa primária.

### Prodap / SIGNUS (BR, líder tradicional)
- **Well:** cobertura ampla (nutrição, reprodução, sanitário, financeiro), integração com consultoria técnica, indicadores zootécnicos robustos.
- **Poorly:** UX datada (sistema desktop/legado), curva de aprendizado alta, lentidão em campo, mobile secundário e fraco, preço elevado, implementação demorada.
- **Implicação:** ser "Prodap simples e moderno" é posicionamento viável.

### BoiGordo (BR, mobile-first)
- **Well:** entrada de dados rápida no celular, UX simples, preço acessível, adoção alta entre pequenos/médios produtores.
- **Poorly:** reprodutivo raso (foco em engorda/confinamento), relatórios limitados, fraco para propriedades de cria, multi-usuário limitado.
- **Implicação:** campo aberto no nicho "cria/recria com forte reprodutivo" — complementar, não competir de frente.

### Pecege / Fazenda em Mente (BR, gestão técnica)
- **Well:** relatórios gerenciais, custos detalhados, formação técnica associada.
- **Poorly:** foco em gestão contábil/gerencial, operacional em campo fraco, não atende veterinário em manejo diário.
- **Implicação:** "Pecege é para o dono no escritório; Campo Gestor é para o vet no curral."

### CattleMax (EUA, referência internacional)
- **Well:** histórico individual robusto, genealogia, relatórios, usabilidade sólida, suporte forte.
- **Poorly:** contexto americano (sem IATF brasileira, sem GTA, sem categorias UA), preço em dólar, sem PT-BR.
- **Implicação:** modelo de referência para UX de histórico individual; não concorre diretamente no Brasil.

### Herdwatch (EU/UK)
- **Well:** mobile, sincronização, compliance regulatória EU.
- **Poorly:** regulatório europeu, idioma, não cobre IATF brasileira.
- **Implicação:** referência de UX mobile.

### ConectaBoi / Rural Pro / Gestagro (BR, nicho)
- **Well:** cada um cobre nicho específico (confinamento, leite, reprodução).
- **Poorly:** fragmentação, cada um resolve uma parte, nenhum faz bem o pacote "operação + reprodução + sanitário + campo".
- **Implicação:** oportunidade de ser o pacote integrado bem feito para cria/recria + reprodução.

### Padrões que Concorrentes Fazem Mal (oportunidade)
1. **Onboarding lento:** cadastros extensos antes de ver valor. Oportunidade: onboarding guiado que cria propriedade+piquete+primeiro lote em 5 minutos.
2. **Multi-propriedade para vet:** frequentemente hack (login/logout). Oportunidade: seletor de propriedade nativo.
3. **Histórico individual enterrado:** dados existem mas ficha do animal é fraca. Oportunidade: ficha como tela central.
4. **Snapshot sanitário:** muitos reescrevem histórico ao mudar lote. Oportunidade: imutabilidade por design.
5. **Entrada de dados em campo:** poucos taps vs muitos. Oportunidade: fluxos de 2-3 taps para operações frequentes.

---

## Dependencies

Ordem técnica de construção — features a jusante dependem das a montante.

### Nível 0 (Fundação)
- Autenticação + perfis
- Cadastro de propriedade
- RLS / isolamento multi-tenant

### Nível 1 (Estrutura)
- Cadastro de piquete (depende de propriedade)
- Cadastro de lote (depende de piquete)
- Categorias + UA (constantes)

### Nível 2 (Animal)
- Cadastro de animal (depende de lote + categoria)
- Numeração única por propriedade (depende de propriedade + lock no banco)
- Ficha do animal (depende de cadastro)

### Nível 3 (Operação)
- Movimentação de animal entre lotes (depende de animal + lotes)
- Movimentação de lote entre piquetes (depende de lote + piquetes)
- Baixa de animal (depende de animal)
- Composição atual do lote (depende de movimentações)

### Nível 4 (Módulos de Valor)

**Branch Reprodutivo** (independente de Sanitário):
- Lote ATF (depende de animal + validação de não-sobreposição)
- Registro de inseminação (depende de Lote ATF)
- Diagnóstico de Gestação (depende de inseminação)
- % prenhez (depende de DG)
- Histórico reprodutivo do animal (depende de ATF + DG)

**Branch Sanitário** (independente de Reprodutivo):
- Snapshot de composição do lote (depende de lote + animais ativos)
- Registro de aplicação (depende de snapshot + lote)
- Histórico sanitário por animal (depende de snapshot)
- Histórico sanitário por lote (depende de aplicações)

**Branch Financeiro** (independente):
- Registro de gasto por piquete (depende de piquete)
- Totais por categoria/período (depende de gastos)

### Nível 5 (Indicadores)
- UA total por piquete (depende de animais + categorias)
- Lotação (UA/ha) por piquete (depende de UA + área do piquete)
- Custo por animal/período (depende de gastos + composição)

### Nível 6 (V2+)
- Parto (depende de DG positivo)
- Vínculo mãe↔cria (depende de parto + cadastro automático de cria)
- Histórico de peso (depende de animal + registros periódicos)
- Calendário sanitário (depende de aplicações + agendamento)
- Protocolos reutilizáveis (depende de ATF + template de produto)

### Dependências Críticas (não-óbvias)
- **Snapshot sanitário é pré-requisito do histórico por animal** — não dá para "calcular depois". Implementar corretamente desde a primeira aplicação.
- **Numeração única exige lock/sequence no banco** — não pode ser MAX+1 client-side (race condition em ambiente multi-usuário).
- **Soft delete é pré-requisito transversal** — todas entidades com histórico precisam desde o início; retrofit é doloroso.
- **RLS precisa estar desde o schema inicial** — adicionar RLS depois exige reescrever políticas e auditar dados.
- **Validação de ATF ativo único por animal** — constraint de banco + verificação na camada de aplicação.

---

## Confidence Assessment

| Area | Confidence | Reason |
|------|------------|--------|
| Table stakes (estrutura/cadastro) | HIGH | Alinhado com PROJECT.md e padrão universal de software de pecuária |
| Table stakes (reprodutivo) | HIGH | ATF/IATF/DG/% prenhez são fluxo estabelecido da pecuária brasileira |
| Table stakes (sanitário) | HIGH | Snapshot imutável é requisito explícito do projeto |
| Differentiators | MEDIUM | Baseados em padrões de UX e pain points conhecidos; precisam validação com usuários |
| Anti-features | HIGH | Alinhados com Out of Scope do PROJECT.md + armadilhas clássicas de software agro |
| V2+ roadmap | MEDIUM | Ordem provável; triggers reais virão de feedback pós-MVP |
| Competitor analysis | LOW | Baseado em conhecimento de treinamento; WebSearch indisponível — validar com pesquisa primária |

## Gaps to Address (validate later)

- **Pesquisa primária com 3–5 veterinários de campo** para validar fluxos críticos (ATF, aplicação sanitária, movimentação).
- **Avaliação hands-on dos concorrentes** (criar trials do Prodap/BoiGordo) para verificar pain points específicos.
- **Verificação regulatória** (GTA, MAPA, Defesa Agropecuária estadual) — pode haver obrigações que elevam algo de V2 para MVP.
- **Modelo de precificação** (por propriedade, por cabeça, por usuário) — afeta quais features são "bloqueadoras" de venda.
- **Necessidade real de offline** — a Constraint diz "não é requisito"; validar que usuários concordam em conectividade mínima.
