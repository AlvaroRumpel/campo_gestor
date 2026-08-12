# Campo Gestor — Plano de Teste Completo (QA)

**Versão do app:** v1.0 (milestone fechado em 2026-08-11)
**Plataforma primária:** Web (Flutter) — testar em Chrome desktop e em viewport mobile (<600px)
**Idioma do app:** Português (pt-BR)
**Objetivo deste teste:** encontrar bugs funcionais E problemas de usabilidade em todos os fluxos.

---

## 1. Contexto — o que é o app

Campo Gestor é um sistema de gestão de propriedades rurais (pecuária). A hierarquia de dados é:

```
Propriedade (fazenda) → Piquete (área de pasto) → Lote (grupo operacional) → Animal
```

Além disso existem duas entidades transversais:
- **Lote ATF** — ciclo reprodutivo de inseminação (independente do lote operacional)
- **Aplicação Sanitária** — registro de medicação com snapshot congelado da composição do lote

**Conceitos de domínio que o QA precisa saber:**

| Conceito | Significado |
|---|---|
| UA (Unidade Animal) | Peso-padrão. Vaca=1.0 · Terneiro=0.5 · Touro=1.5 · Boi=1.5 · Novilho=0.75 · Novilha=0.75 |
| Categorias de animal | vaca, terneiro, terneira, touro, boi, novilho, novilha |
| Estado corporal | Escala 1–5 (muito magro → muito gordo) |
| DG | Diagnóstico de Gestação (Prenhe / Vazia / Duvidosa) |
| ATF | Lote de inseminação. Aceita SOMENTE vacas e novilhas |
| Snapshot sanitário | Ao registrar aplicação, a composição do lote é congelada. IMUTÁVEL depois |
| Estorno | Aplicação sanitária não pode ser editada/apagada — só estornada (cria registro espelho) |
| Baixa | Arquivamento de animal (venda/morte/descarte) — soft delete, histórico preservado |

---

## 2. Perfis de usuário (CRÍTICO — testar os 3)

O papel é **por propriedade** (o mesmo usuário pode ser vet numa fazenda e leitor em outra).

| Papel | Pode |
|---|---|
| **Veterinário** | Tudo: criar/editar fazendas, piquetes, lotes, animais, ATF, DG, doses, aplicações, estornos, gastos |
| **Proprietário (owner)** | Somente **gastos** (criar/editar/excluir/restaurar). Todo o resto é leitura |
| **Leitor (reader)** | Só leitura em tudo |

**Convenção do app:** controle negado fica **ausente** (some), nunca desabilitado/acinzentado.

**Regra de teste:** cada fluxo de escrita abaixo deve ser executado com o veterinário E verificado que os controles NÃO aparecem para owner/reader (exceto gastos, onde owner também escreve). Isso é matriz obrigatória, não opcional.

### Setup de contas necessário

Criar no mínimo:
1. Usuário A — veterinário na Fazenda 1 e na Fazenda 2 (multi-propriedade)
2. Usuário B — proprietário na Fazenda 1
3. Usuário C — leitor na Fazenda 1
4. Usuário D — sem vínculo com nenhuma fazenda (para testar tela "sem acesso")

---

## 3. Autenticação e acesso

### 3.1 Cadastro (/signup)
- [ ] Criar conta com email válido + senha ≥6 → SnackBar "Confirme seu email para ativar a conta", volta ao login
- [ ] Email inválido (sem @, sem domínio) → erro "Digite um email válido"
- [ ] Senha <6 caracteres → erro "A senha deve ter pelo menos 6 caracteres"
- [ ] Confirmar senha diferente → "As senhas não coincidem"
- [ ] Link "Já tem conta? Entrar" leva ao login

### 3.2 Login (/login)
- [ ] Login válido → cai no /dashboard
- [ ] Senha errada → SnackBar "Email ou senha inválidos"
- [ ] Sem internet → mensagem de conexão (não trava, não tela branca)
- [ ] Botão mostra spinner durante o request; duplo-clique não dispara 2 logins
- [ ] Sessão persiste após F5 / fechar e reabrir aba

### 3.3 Redefinição de senha (/reset-password)
- [ ] Solicitar reset com email cadastrado → SnackBar de confirmação
- [ ] Email NÃO cadastrado → mesma mensagem neutra (não pode revelar se o email existe)
- [ ] Clicar no link do email → abre modo "Nova senha"; salvar senha ≥6 → loga e vai para home
- [ ] Nova senha <6 ou confirmação divergente → erros de validação

### 3.4 Usuário sem vínculo (/sem-acesso)
- [ ] Usuário D loga → cai em "Acesso não configurado"
- [ ] Botão "Criar minha fazenda" → abre /propriedades e PERMITE criar a primeira fazenda
- [ ] Após criar a 1ª fazenda → redirecionado ao dashboard
- [ ] Botão "Sair" → volta ao login

### 3.5 Logout
- [ ] Botão sair (ícone no AppBar) → volta ao /login
- [ ] Após logout, URL direta de tela interna (ex: /animais) → redireciona ao /login
- [ ] Logar com outro usuário na sequência → NÃO herda propriedade ativa do usuário anterior

### 3.6 Multi-propriedade e isolamento (CRÍTICO)
- [ ] Usuário A (2 fazendas): seletor no topo mostra as duas com o papel de cada uma
- [ ] Trocar de fazenda → TODAS as listas (piquetes, animais, ATFs, aplicações) mudam para os dados da fazenda selecionada
- [ ] Fazenda ativa persiste após F5
- [ ] **Isolamento:** dados da Fazenda 2 NUNCA aparecem enquanto Fazenda 1 está ativa (verificar em toda lista, dropdown, busca e detalhe)
- [ ] Deep link para recurso de outra fazenda (copiar URL de /lotes/:id da Fazenda 2, colar com Fazenda 1 ativa) → não vaza dado
- [ ] Usuário com 1 fazenda só: seletor vira texto simples + link "Gerenciar fazendas"

---

## 4. Fazendas (/propriedades)

- [ ] Listar fazendas com nome e "Proprietário: X" quando preenchido
- [ ] Criar: nome obrigatório; proprietário opcional
- [ ] Editar nome/proprietário → reflete na lista e no seletor do topo
- [ ] Remover → dialog de confirmação "não pode ser desfeita" → some da lista
- [ ] Remover a fazenda ATIVA → o que acontece? (verificar que o app não quebra; deve trocar de fazenda ou cair em sem-acesso)
- [ ] Owner e reader: FAB e menu de editar/remover AUSENTES
- [ ] Empty state: "Nenhuma fazenda cadastrada"

## 5. Piquetes (/piquetes)

- [ ] Listar: nome + "X ha · Y UA" (decimal com vírgula)
- [ ] Criar: nome, área (ha) e capacidade (UA) obrigatórios; aceita vírgula E ponto decimal ("8,5" e "8.5")
- [ ] Valor ≤ 0 → "Deve ser maior que zero"; texto não numérico → "Informe um número válido"
- [ ] Editar e remover (com confirmação) — vet only
- [ ] UA exibida no card = soma real dos animais ativos dos lotes do piquete (conferir manualmente com a tabela de UA)
- [ ] Tap no card → detalhe do piquete

### 5.1 Detalhe do piquete (/piquetes/:id)
- [ ] Card de info: nome, área, capacidade
- [ ] Card "Gastos" com total do mês → clicável para TODOS os papéis → abre /gastos/:paddockId
- [ ] Card de gastos com erro de rede → mostra "—" + botão refresh (nunca "R$ 0,00")
- [ ] Seção Lotes: cada card resume top-2 categorias ("3 Vacas · 2 Novilhas"), "(+N)" se mais, e UA total
- [ ] Lote sem animais → "Sem animais"
- [ ] FAB "Novo lote" — vet only
- [ ] URL inválida /piquetes/xxx → "Piquete não encontrado" (não tela branca)

## 6. Lotes

### 6.1 Criar lote (dialog no detalhe do piquete)
- [ ] Nome obrigatório
- [ ] Composição: 7 linhas (uma por categoria) com stepper −/+, digitação direta, raça opcional por categoria
- [ ] Total 0 animais → SnackBar "Informe ao menos 1 animal para criar o lote"
- [ ] Quantidade trava em 999 no + e em 0 no −
- [ ] Criar lote com composição (ex: 3 vacas + 2 novilhas) → animais gerados automaticamente com numeração sequencial POR CATEGORIA
- [ ] Campo "Iniciar do número": informar valor → numeração começa dali; conflito com número existente → mensagem de conflito clara
- [ ] Números NUNCA se repetem na mesma propriedade+categoria — nem depois de dar baixa em um animal (número não é reutilizado)
- [ ] Editar lote = só renomear

### 6.2 Detalhe do lote (/lotes/:id)
- [ ] Header: nome, piquete, chips por categoria com UA ("Vacas: 3 · 3,0 UA") + chip total
- [ ] Lista de animais: "#N · Categoria", raça/EC no subtítulo; tap → ficha do animal
- [ ] Botões "Mover para piquete" e "Registrar aplicação" — vet only, e só se o lote tem animais ativos
- [ ] FAB "Novo animal" — vet only
- [ ] Botão voltar funciona vindo por navegação E por URL direta (deve cair no piquete pai)

### 6.3 Mover lote entre piquetes (MOV-02 — atômico)
- [ ] Dialog lista piquetes EXCETO o atual; confirmar desabilitado até selecionar
- [ ] Mensagem indica nº de animais e que a operação é atômica
- [ ] Após mover: lote aparece no novo piquete, some do antigo, UA dos dois piquetes atualiza
- [ ] Único piquete na fazenda → "Nenhum outro piquete disponível"
- [ ] SnackBar "Lote movido para X"

## 7. Animais

### 7.1 Lista (/animais)
- [ ] Busca por número com debounce; botão limpar
- [ ] **Busca por número EXATO encontra animal arquivado mesmo com "Mostrar arquivados" desligado** (regra intencional); busca parcial respeita o toggle
- [ ] Filtros combinados: categoria (chips) + lote (dropdown) + piquete (dropdown) — testar combinações
- [ ] Barra de resumo "N animais · X UA total" atualiza conforme filtro
- [ ] Animal arquivado: chip Vendido/Morto/Descartado
- [ ] Empty states distintos: sem animais cadastrados vs. filtro sem resultado ("Tente ajustar os filtros")
- [ ] Ordenação por número

### 7.2 Criar animal individual (FAB no detalhe do lote)
- [ ] Categoria obrigatória; número auto-gerado mas editável
- [ ] Número duplicado → mensagem de conflito; ≤0 → erro de validação
- [ ] Raça e EC opcionais; EC via chips 1–5 desmarcáveis

### 7.3 Ficha do animal (/animais/:id) — CORE DO PRODUTO, testar a fundo
- [ ] Dados: número, categoria, raça, EC (n/5), lote atual (LINK), piquete atual (LINK), data de cadastro, observação
- [ ] Histórico reprodutivo: todos os ATFs com datas, touro, chip do resultado do DG ou "aguardando DG", chip Ativo/Encerrado; tap → detalhe do ATF
- [ ] ATF com mais de 1 DG → linha expansível mostrando todos os DGs com data e observação
- [ ] Histórico sanitário: aplicações com dose, data e lote CONGELADO no momento (mesmo que o animal tenha mudado de lote depois — verificar!)
- [ ] Históricos mostram no máx. 10 itens + botão "Ver todas" → abre /sanitario pré-filtrado por animal
- [ ] Animal com baixa: banner vermelho proeminente "Vendido em dd/MM/yyyy — obs" no topo; botões Dar baixa/Mover somem
- [ ] Botões Editar/Dar baixa/Mover — vet only
- [ ] Layout em 360px de largura: nada corta, labels empilham

### 7.4 Editar animal
- [ ] Número e categoria READ-ONLY; edita raça, EC, observação
- [ ] Nenhum campo obrigatório; salvar vazio funciona

### 7.5 Baixa
- [ ] Motivo obrigatório (Venda/Morte/Descarte) → sem seleção, SnackBar "Selecione o motivo da baixa"
- [ ] Data não permite futuro
- [ ] Após baixa: animal some das listas padrão, aparece com "Mostrar arquivados", histórico preservado, banner na ficha
- [ ] Animal baixado que estava em ATF ativo → como aparece no ATF? (linha some da seção DG; verificar consistência da contagem)

### 7.6 Mover animal (MOV-01)
- [ ] Lista lotes EXCETO o atual, com piquete e contagem
- [ ] Após mover: lote atual atualiza na ficha, contagens dos dois lotes atualizam, histórico preservado
- [ ] Um lote só na fazenda → "Nenhum outro lote disponível"

## 8. Reprodução (/reproducao)

### 8.1 Lista de ATFs
- [ ] Card: nome, datas implantação/inseminação, nº animais, % prenhez + barra de progresso de DGs realizados
- [ ] Switch "Mostrar encerrados"; chip "Encerrado" nos inativos
- [ ] FAB "Novo ATF" — vet only

### 8.2 Criar ATF
- [ ] Nome, data implantação, data inseminação obrigatórios; **inseminação < implantação → erro**
- [ ] Touro: dropdown com touros da fazenda OU "Outro / sêmen externo" (abre campo texto obrigatório)
- [ ] Após criar → navega direto ao detalhe do ATF

### 8.3 Seleção de animais do ATF
- [ ] Só vacas e novilhas aparecem como elegíveis
- [ ] "Lote base": selecionar pré-marca todos os elegíveis do lote
- [ ] Animal já em outro ATF ativo → aparece DESABILITADO com "já em {ATF}" (não escondido)
- [ ] Busca por número + filtro Vaca/Novilha
- [ ] Sair com seleção feita → confirma "Descartar seleção?"
- [ ] Barra inferior: contador de selecionados; botão desabilitado com 0

### 8.4 Detalhe do ATF (/atf/:id)
- [ ] Header: nome, badge Ativo/Encerrado, datas, touro (link se for animal da fazenda), % prenhez
- [ ] Composição: lista de animais; "+ Animais" e remover (X) — vet only e só com ATF ativo
- [ ] **Remover animal COM DG registrado → botão X não aparece**
- [ ] Registro de DG em massa: data da sessão (sem futuro), chips Prenhe/Vazia/Duvidosa por animal, data individual por animal, observação expansível
- [ ] "Salvar DGs" só habilita quando algo mudou
- [ ] % prenhez recalcula: prenhas ÷ total de DGs realizados × 100 — conferir a conta manualmente
- [ ] **DG editável mesmo APÓS encerrar o ATF** (correção permitida — comportamento intencional)
- [ ] Banner "Todos os animais têm DG registrado" aparece quando 0 pendentes → oferece Encerrar

### 8.5 Encerrar ATF
- [ ] Com DGs pendentes → aviso "Ainda há N animal(is) sem DG" mas NÃO bloqueia
- [ ] Após encerrar: animais ficam LIVRES para entrar em novo ATF; histórico preservado
- [ ] Tentar adicionar animal de ATF encerrado em novo ATF → deve funcionar

## 9. Sanitário (/sanitario — 2 abas)

### 9.1 Doses (aba 2)
- [ ] Criar: nome comercial obrigatório; dosagem mL/kg obrigatória >0; custo R$/kg opcional
- [ ] **mL/UA e R$/UA calculados automaticamente (×400) em tempo real** — conferir a conta
- [ ] Dose sem custo → chips de custo NÃO aparecem (nunca "R$ 0,00")
- [ ] Editar / Arquivar / Reativar — vet only; arquivada fica esmaecida com badge
- [ ] Dose arquivada não aparece no dropdown de nova aplicação

### 9.2 Registrar aplicação (fluxo de 3 passos — CRÍTICO)
**Passo 1 (dialog):** lote (travado se veio do detalhe do lote), dose, data
- [ ] Sem doses cadastradas → dropdown desabilitado + aviso "cadastre uma dose primeiro"
- [ ] Dropdown de lotes só mostra lotes COM animais ativos

**Passo 2 (seleção):** todos os animais do lote PRÉ-MARCADOS
- [ ] Desmarcar alguns; contador "N de M selecionados · X UA" atualiza
- [ ] Sair depois de desmarcar → confirma descarte

**Passo 3 (resumo):**
- [ ] Mostra dose, lote, data, totais (animais, UA, volume, custo se houver), nº de desmarcados
- [ ] Banner permanente: "Este registro é permanente e não pode ser editado ou apagado"
- [ ] **Duplicata:** registrar 2ª aplicação com mesma dose+lote+data → aviso + checkbox "Sim, registrar mesmo assim" obrigatório para destravar o botão
- [ ] Confirmar → SnackBar; aplicação aparece na lista, no histórico do lote e na ficha de CADA animal selecionado
- [ ] Animal DESMARCADO não ganha o registro no histórico dele

### 9.3 Snapshot imutável (regra de negócio central)
- [ ] Registrar aplicação; depois MOVER um animal para outro lote; a aplicação continua mostrando o lote e a composição ORIGINAIS
- [ ] Dar baixa num animal da composição → detalhe da aplicação continua íntegro
- [ ] Editar valor da dose depois → aplicações antigas mantêm o custo da época

### 9.4 Detalhe da aplicação (/aplicacoes/:id)
- [ ] Tudo vem do snapshot: dose, dosagem, custo, lote, composição com UA por animal
- [ ] Tap num animal da composição → ficha
- [ ] Lote deletado → nome vira texto (sem link), não quebra

### 9.5 Estorno
- [ ] Motivo OBRIGATÓRIO
- [ ] Estorno cria registro espelho; original ganha badge "Estornada", espelho ganha "Estorno"; ambos com link cruzado
- [ ] Aplicação já estornada → botão "Estornar" não aparece; estorno não pode ser estornado
- [ ] **Corrida:** dois usuários estornando a mesma aplicação → o segundo recebe erro claro + link "Ver estorno"
- [ ] Valores do estorno anulam os da original nos gastos do piquete (verificar soma)
- [ ] Aplicações estornadas aparecem riscadas nos históricos com o switch "Mostrar estornadas"

### 9.6 Lista de aplicações (aba 1)
- [ ] Filtros: lote, dose, período (date range), chip de animal (quando vem de "Ver todas" da ficha)
- [ ] Deep link /sanitario?animal=X e ?lote=X pré-filtram corretamente

## 10. Gastos por piquete (/gastos/:paddockId)

**Lembrete: aqui OWNER também escreve (único módulo).**

- [ ] Acessível pelo card "Gastos" no detalhe do piquete
- [ ] Filtros de período: Mês atual (default) / Mês passado / Últimos 3 meses / Ano / Personalizado — sempre reabre em "Mês atual"
- [ ] Total no topo em R$ + "N lançamentos" — conferir soma manualmente
- [ ] Lançar gasto: categoria obrigatória (8 opções), valor obrigatório >0 (formato "1.240,00"), data obrigatória, descrição opcional
- [ ] Lista unificada: gastos manuais + custos de aplicações sanitárias (badge "Sanitário", read-only, tap → detalhe da aplicação)
- [ ] Gasto sanitário sem custo → "—" (nunca R$ 0,00)
- [ ] Excluir gasto manual → confirmação com valor e data; linha fica riscada com "Mostrar excluídos"; excluído NÃO soma no total
- [ ] Restaurar gasto excluído → volta a somar
- [ ] Estorno sanitário abate o valor do total do período
- [ ] Owner: vê e usa FAB/editar/excluir. Reader: nada disso, mas VÊ a lista e o total
- [ ] Empty states: sem gastos vs. período sem resultado (+ botão "Limpar filtro")

## 11. Dashboard

- [ ] Estado atual: **placeholder** (só o texto "Dashboard"). Reportar como está — não é bug, é pendência conhecida. Avaliar impacto de usabilidade (primeira tela após login é vazia).

---

## 12. Testes transversais

### 12.1 Responsividade
- [ ] ≥600px: navegação lateral (rail); <600px: barra inferior — testar a transição redimensionando
- [ ] Largura 360px: ficha do animal, dialogs, tabelas — nada corta, sem scroll horizontal
- [ ] Dialogs longos (criar lote com 7 categorias) em tela baixa → scroll interno funciona

### 12.2 Navegação e URLs
- [ ] Back do navegador funciona em toda tela (nunca beco sem saída)
- [ ] F5 em QUALQUER rota profunda (/lotes/:id, /atf/:id, /aplicacoes/:id, /gastos/:id) → recarrega a tela certa, não volta pro dashboard
- [ ] ID inexistente em qualquer rota → "não encontrado" amigável, nunca tela branca/erro cru
- [ ] Abrir rota profunda em aba anônima → login → após logar deve voltar (ou ao menos não quebrar)

### 12.3 Concorrência e rede
- [ ] Duas abas abertas: mudar dado numa, verificar a outra após interação (stale aceitável, crash não)
- [ ] Desligar a rede no meio de um save → mensagem de erro clara, formulário NÃO perde os dados digitados, retry funciona
- [ ] Duplo-clique rápido em qualquer botão de confirmação → não cria registro duplicado

### 12.4 Dados e formatação
- [ ] Datas sempre dd/MM/yyyy; moeda "R$ 1.240,00"; decimais com vírgula
- [ ] Nomes longos (fazenda/lote/dose com 60+ caracteres) → ellipsis, sem overflow
- [ ] Caracteres especiais e emoji em campos de texto → salva e exibe sem quebrar
- [ ] Textos colados com espaços no início/fim

### 12.5 Usabilidade (avaliar e relatar, mesmo sem ser "bug")
- [ ] O usuário entende onde está? (títulos, breadcrumb implícito)
- [ ] Ações destrutivas sempre confirmadas e com cor de alerta?
- [ ] Feedback após cada ação (SnackBar/atualização visível)?
- [ ] Empty states orientam o próximo passo?
- [ ] Fluxo de aplicação sanitária em 3 passos é claro? Onde se perde?
- [ ] Quantos cliques para as tarefas mais comuns (achar um animal pelo número; registrar um DG; lançar um gasto)?
- [ ] Termos do domínio consistentes entre telas (ATF, DG, baixa, estorno)?

---

## 13. Como reportar

Para cada issue, registrar:

```
ID: QA-###
Tela/Rota: (ex: /atf/:id — seção DG)
Papel usado: veterinário | proprietário | leitor
Tipo: Bug | Usabilidade | Visual | Sugestão
Severidade: Bloqueador | Alto | Médio | Baixo
Passos para reproduzir: 1... 2... 3...
Resultado esperado:
Resultado obtido:
Print/vídeo: (obrigatório para visual/usabilidade)
Navegador + largura da janela:
```

**Severidade:**
- **Bloqueador:** perda de dados, vazamento entre fazendas, crash, fluxo impossível de completar
- **Alto:** cálculo errado (UA, % prenhez, totais), regra de negócio violada (snapshot mutável, animal em 2 ATFs, número duplicado)
- **Médio:** erro de fluxo com workaround, mensagem errada/ausente
- **Baixo:** visual, texto, alinhamento

**Prioridade de exploração (se o tempo for curto):** 3.6 isolamento multi-propriedade → 9 sanitário (snapshot/estorno/duplicata) → 8 reprodução (elegibilidade/DG/% prenhez) → 7.3 ficha do animal → 10 gastos → resto.
