# Campo Gestor — Visão do Produto para Redesign UI/UX

**Estado:** v1.0 funcional completa (30/30 requisitos entregues, 2026-08-11)
**Stack:** Flutter Web (Material 3, tema padrão pouco customizado) + Supabase
**Plataforma:** web-first responsivo; mobile (Android/iOS) secundário via mesmo código
**Idioma:** pt-BR
**Objetivo do redesign:** o app funciona, mas a UI é Material 3 "de fábrica" — sem identidade visual, sem hierarquia refinada, dashboard vazio. Queremos um redesign completo mantendo os fluxos e regras descritos aqui.

---

## 1. A ideia do produto

App de gestão de propriedades rurais focado em **pecuária**. O usuário estrutura a fazenda em piquetes (áreas de pasto), organiza os animais em lotes, e registra a vida de cada animal individualmente.

**Core value (o coração do produto):** *o histórico técnico do animal individual — reprodutivo e sanitário — acessível em campo por quem toma decisões.* A "ficha do animal" é a tela mais importante do app.

### Usuários

| Persona | Contexto | Papel no app |
|---|---|---|
| **Veterinário** | Atende VÁRIAS fazendas; é quem opera o sistema no dia a dia, muitas vezes no celular, no campo, sob sol | Admin: cria e edita tudo |
| **Proprietário da fazenda** | Quer acompanhar o rebanho e os custos | Só leitura + gestão de gastos |
| **Leitor** | Funcionário/consultor | Só leitura |

Nota importante de modelo: o papel é **por fazenda**. O mesmo usuário pode ser veterinário na Fazenda A e leitor na Fazenda B. O app tem um **seletor de fazenda ativa** no topo — tudo que se vê é da fazenda selecionada.

Decisão de produto invertida em relação ao óbvio: o **veterinário é o admin** (não o dono). O dono é usuário restrito. O contexto de uso prioritário é **mobile-first na prática** (vet no campo), embora a plataforma seja web.

### Modelo de dados (o que o usuário manipula)

```
Propriedade (fazenda)
 └─ Piquete (área de pasto: nome, hectares, capacidade em UA)
     └─ Lote (grupo operacional de animais)
         └─ Animal (número único, categoria, raça, estado corporal 1–5)

Transversais:
 • Lote ATF  — ciclo de inseminação (só vacas/novilhas), com DG por animal e % de prenhez
 • Aplicação Sanitária — medicação de um lote, com "snapshot congelado" da composição
 • Dose — catálogo de medicamentos (mL/kg, custo/kg; valores por UA calculados ×400)
 • Gasto — despesa vinculada a um piquete (8 categorias + custos sanitários automáticos)
```

**Vocabulário do domínio** (usar exatamente estes termos na UI):
- **UA** = Unidade Animal (vaca 1.0, touro/boi 1.5, novilho/a 0.75, terneiro/a 0.5) — métrica onipresente
- **DG** = diagnóstico de gestação: Prenhe / Vazia / Duvidosa
- **ATF** = lote de inseminação
- **Baixa** = arquivamento do animal (venda/morte/descarte) — nada é deletado de verdade
- **Estorno** = anulação de aplicação sanitária (registros sanitários são imutáveis)

---

## 2. Arquitetura de navegação atual

### Shell principal (após login)
- **≥600px:** NavigationRail lateral fixa + AppBar com seletor de fazenda e botão sair
- **<600px:** NavigationBar inferior (bottom nav)
- **5 destinos:** Dashboard · Piquetes · Animais · Reprod. · Sanitário

### Mapa de rotas

```
Fora do shell (telas cheias):
  /login  /signup  /reset-password  /sem-acesso
  /propriedades              — gestão de fazendas
  /lotes/:id                 — detalhe do lote
  /atf/:id                   — detalhe do ciclo reprodutivo
  /aplicacoes/:id            — detalhe da aplicação sanitária
  /gastos/:paddockId         — gastos de um piquete

Dentro do shell:
  /dashboard                 — HOJE É PLACEHOLDER (só o texto "Dashboard")
  /piquetes  → /piquetes/:id
  /animais   → /animais/:id  (ficha do animal — tela core)
  /reproducao
  /sanitario  (2 abas: Aplicações | Doses)
```

Observação estrutural: os detalhes (lote, ATF, aplicação, gastos) ficam **fora** do shell porque são alcançados de múltiplas origens. Não existe tela "lista de lotes" — lote só se alcança descendo pelo piquete (limitação conhecida, já questionada em teste de usuário).

---

## 3. Inventário de telas (estado atual)

### 3.1 Auth
- **Login:** card centralizado (max 400px), logo = ícone de grama + "Campo Gestor", email/senha, links para cadastro e reset. Visual genérico, sem branding.
- **Cadastro:** email, senha, confirmação. Exige confirmação por email.
- **Reset de senha:** 2 modos (solicitar por email / definir nova senha via link).
- **Sem acesso:** usuário logado sem fazenda vinculada; CTA "Criar minha fazenda".

### 3.2 Fazendas (/propriedades)
Lista simples de cards (nome + proprietário), FAB criar, menu editar/remover. Dialog de formulário com 2 campos.

### 3.3 Piquetes
- **Lista:** cards com nome + "8,5 ha · 12,0 UA".
- **Detalhe:** card de info (nome/área/capacidade) + card de gastos do mês (atalho para /gastos) + seção de lotes (cards com resumo de composição "3 Vacas · 2 Novilhas (+1) · 5,5 UA").

### 3.4 Lotes (/lotes/:id)
Header com chips de composição por categoria e UA total; ações "Mover para piquete" e "Registrar aplicação"; lista de animais (#número · categoria); seção de histórico sanitário do lote; FAB novo animal.
- **Criar lote** (dialog): nome + grade de composição com stepper por 7 categorias + raça opcional + número inicial opcional. Ao criar, o sistema **gera os animais em lote automaticamente** com numeração sequencial.
- **Mover lote** (dialog): picker de piquete destino; operação atômica.

### 3.5 Animais
- **Lista (/animais):** busca por número, chips de categoria, dropdowns de lote e piquete, barra "N animais · X UA total", switch "Mostrar arquivados". Linhas: "#12 · Vaca — Lote A · Piquete 3", chip vermelho de baixa quando arquivado.
- **Ficha (/animais/:id) — TELA MAIS IMPORTANTE DO PRODUTO:**
  - Banner vermelho de baixa no topo se o animal foi arquivado ("Vendido em 12/03/2026 — obs")
  - Card de dados: número, categoria, raça, estado corporal (n/5), lote atual (link), piquete atual (link), data de cadastro, observação
  - Botões (só vet): Editar · Dar baixa · Mover animal
  - **Histórico reprodutivo:** linha por ATF ("nome — insem. dd/MM · touro: X · resultado do DG · Ativo/Encerrado"), expansível quando há vários DGs
  - **Histórico sanitário:** linha por aplicação ("dose — data · lote da época"), riscada se estornada, máx. 10 + "Ver todas"
  - Projetada para funcionar a 360px de largura
- **Dialogs:** criar animal (categoria, número auto, raça, EC em chips 1–5, obs), editar (número/categoria travados), baixa (motivo em segmented button Venda/Morte/Descarte + data + obs), mover (picker de lote).

### 3.6 Reprodução
- **Lista (/reproducao):** cards de ATF com nome, "impl. 02/05 · insem. 12/05 · 18 animais", % de prenhez + barra de progresso de DGs feitos, switch "Mostrar encerrados".
- **Criar ATF** (dialog): nome, datas de implantação e inseminação, touro (dropdown de touros da fazenda OU "sêmen externo" com campo livre), observação.
- **Seleção de animais** (tela cheia): dropdown "lote base" que pré-marca elegíveis + busca avulsa com filtro Vaca/Novilha. Animal já em outro ATF aparece desabilitado com o motivo. Barra inferior com contador.
- **Detalhe (/atf/:id):** header com datas/touro/% prenhez; banner sugerindo encerrar quando todos os DGs estão feitos; seção composição (com adicionar/remover); **seção de DG em massa**: data da sessão + uma linha por animal com 3 chips (Prenhe/Vazia/Duvidosa), data e observação individuais, botão "Salvar DGs". DG segue editável após encerramento (correção).
- **Encerrar ATF** (dialog): libera os animais para novo ciclo; avisa se há DGs pendentes mas não bloqueia.

### 3.7 Sanitário (2 abas)
- **Aba Aplicações:** filtros (lote, dose, período, animal), switch estornadas; cards "dose — dd/MM · lote · N animais · X UA · R$ Y", badges Estornada/Estorno.
- **Aba Doses:** cards com nome, princípio ativo, chips de dosagem (mL/kg e mL/UA calculado) e custo (R$/kg e R$/UA); arquivar/reativar.
- **Fluxo de registro (3 passos):**
  1. Dialog: lote + dose + data
  2. Tela cheia: checklist de animais do lote, todos pré-marcados, contador "N de M · X UA"
  3. Dialog resumo: totais, aviso **"registro permanente, não pode ser editado ou apagado"**, detecção de duplicata (mesma dose+lote+data) com checkbox de confirmação forçada
- **Detalhe (/aplicacoes/:id):** tudo vem do snapshot congelado (dose, valores, composição da época); botão "Estornar" (motivo obrigatório) — estorno cria registro espelho com links cruzados entre original e estorno.

### 3.8 Gastos (/gastos/:paddockId)
Por piquete. Chips de período (Mês atual default / Mês passado / 3 meses / Ano / Personalizado), dropdown de categoria, total grande em R$ + contagem de lançamentos. Lista unificada: gastos manuais (editáveis, com lixeira/restaurar) + custos sanitários automáticos (badge "Sanitário", read-only, linkam para a aplicação). **Único módulo onde o proprietário também edita.**

### 3.9 Dashboard
**Placeholder vazio.** É a primeira tela após o login e hoje não mostra nada. Maior oportunidade do redesign (v2 prevê indicadores: UA/ha por piquete, custo por animal, DGs pendentes...).

---

## 4. Padrões de UI vigentes (o que o redesign pode manter, melhorar ou substituir)

| Padrão atual | Descrição |
|---|---|
| Permissão = ausência | Controle que o papel não pode usar **some** (nunca aparece desabilitado) |
| CRUD em dialogs | Todos os formulários são `AlertDialog` sobre a lista; só seleções de animais são telas cheias |
| Cards em lista | Toda listagem é ListView de cards; nenhuma tabela de dados |
| Empty states com CTA | Todo vazio tem título + orientação ("Crie um lote para começar...") |
| Feedback via SnackBar | Toda ação confirma com SnackBar; erros de formulário inline |
| Destrutivo = vermelho + confirmação | Baixa, estorno, remover: botão em cor de erro + dialog de confirmação |
| Imutável = banner de aviso | Aplicação sanitária avisa permanência antes de confirmar |
| Formato pt-BR | dd/MM/yyyy, vírgula decimal, R$ 1.240,00 |
| Breakpoint único 600px | Rail lateral ↔ bottom nav; sem outros breakpoints |
| Riscado = anulado | Estornos e gastos excluídos aparecem com line-through |

---

## 5. Dores e oportunidades conhecidas (input para o redesign)

1. **Dashboard vazio** — primeira impressão do app é uma tela em branco. Não há visão gerencial nenhuma.
2. **Sem identidade visual** — Material 3 default, ícone de grama como logo, sem paleta própria, sem tipografia própria.
3. **Lote não tem lista própria** — só se chega a um lote navegando Piquete → Lote. Já foi apontado em teste de usuário.
4. **Fluxo sanitário de 3 passos** — funcional, mas pesado (dialog → tela → dialog). Repensar.
5. **Densidade de informação** — vet no campo precisa de alvos de toque grandes, contraste alto (sol), leitura rápida; hoje as listas são genéricas.
6. **Ficha do animal** é o core mas visualmente é uma pilha de cards igual a qualquer outra tela — merece destaque e hierarquia próprios.
7. **Seletor de fazenda** no AppBar é discreto; usuários multi-fazenda podem não perceber em qual fazenda estão (risco real de registrar dado na fazenda errada).
8. **Sem modo offline** (fora de escopo v1) — mas o contexto de campo tem sinal ruim; o redesign pode ao menos comunicar melhor estados de erro/carregamento.

### O que NÃO pode mudar (restrições de negócio)
- Hierarquia Propriedade → Piquete → Lote → Animal
- Regras: snapshot sanitário imutável (só estorno), ATF só vacas/novilhas, 1 ATF ativo por animal, numeração única, baixa preserva histórico
- Os 3 papéis e a convenção de esconder (não desabilitar) controles
- pt-BR e formatos locais
- Flutter + Material como base técnica (o design system pode ser customizado em cima)

### Escopo v2 já previsto (bom considerar no design desde já)
Parto e vínculo mãe↔cria · histórico de peso · calendário sanitário · exportação CSV · breakdown de gastos por categoria · indicadores (UA/ha, custo/animal) · notificações in-app (DG pendente).
