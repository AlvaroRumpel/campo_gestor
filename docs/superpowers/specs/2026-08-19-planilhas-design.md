# Planilhas — exportar, importar e editar em grade

**Data:** 2026-08-19
**Status:** aprovado em brainstorming, aguardando plano de implementação
**Mockups:** https://claude.ai/code/artifact/33d21f14-c52c-4264-a49d-cea0443151d0

## Problema

Usuários do nicho (veterinários, proprietários) preferem editar dados em massa no Excel. Softwares concorrentes exportam tabelas; muitos clientes chegam com planilhas desses softwares. Hoje o Campo Gestor só edita animal por animal via diálogo.

## Objetivo

1. **Exportar** as 4 tabelas principais para `.xlsx` com os filtros atuais da tela.
2. **Importar** `.xlsx`/`.csv` de qualquer origem (planilha genérica ou de outro software) com mapeamento manual de colunas, preview e gravação atômica.
3. **Editar em grade** (tipo planilha) dentro do app, com salvamento em lote, para animais, doses e aplicações sanitárias multi-dose.

Fora de escopo v1: presets de software específico (vêm depois com arquivo-exemplo), offline, mobile-first da grade (funciona, mas desktop é o alvo), campos novos no animal (peso, nascimento, brinco — colunas desconhecidas são ignoradas no import).

## Entidades cobertas

| Entidade | Export | Import | Grade |
|---|---|---|---|
| Animais | sim | upsert por número | sim — toggle lista/grade em `/animais` |
| Doses (catálogo) | sim | upsert por nome | sim — na tela de catálogo |
| Aplicações sanitárias | sim (histórico) | cria aplicações (agrupa lote+dose+data) | sim — nova tela "aplicação em grade" animais × doses |
| DG por ATF | sim | lança DG (`save_dg_records`) | já existe (`atf_dg_table_view`) — mantém |

Permissões: segue RLS atual. Export: qualquer membro. Import/grade: quem já pode escrever na tabela (animais, doses, sanitário = veterinário).

## Arquitetura

```
lib/features/planilhas/
  data/
    sheet_codec.dart        # xlsx/csv → List<List<String>>; rows → bytes xlsx
    column_mapping.dart     # mapeamento salvo em shared_preferences: key = entidade + hash(headers)
    bulk_repository.dart    # rpc bulk_upsert_animals | bulk_register_sanitary | bulk_upsert_doses; reusa atfRepository.saveDgRecords
  domain/
    sheet_schema.dart       # SheetSchema + SheetColumn por entidade — FONTE ÚNICA de colunas
    import_preview.dart     # ImportRow{index, values, status create|update|error, errors[]} + validador client-side
    header_matcher.dart     # normaliza cabeçalho (sem acento/caixa/pontuação) e casa com aliases do schema
  presentation/
    export_button.dart      # gera xlsx com linhas visíveis; download via universal_html/anchor
    import_flow_screen.dart # 3 passos: arquivo → mapear → revisar
    editable_grid.dart      # grade genérica dirty-tracking
    sanitario_grade_screen.dart  # animais × doses (usa editable_grid em modo checkbox)
```

**SheetSchema** — por entidade, lista de `SheetColumn{key, label, type (text|int|decimal|date|enum), required, enumValues (chave→label pt-BR), aliases, editable, readOnlyWhenExisting}`. Gera: cabeçalho do export, alvos do passo "mapear", colunas da grade, planilha-modelo.

**Dependências novas:** `excel` (leitura/escrita xlsx, puro Dart), `file_picker` (seleção de arquivo web). CSV via `dart:convert` + split manual com detecção de separador (`;` ou `,`) e BOM UTF-8 — sem package.

## Banco — migration `20260820_15_bulk_sheets.sql`

Todas `SECURITY INVOKER`, `SET search_path = public`, `REVOKE ALL FROM public`, `GRANT EXECUTE TO authenticated`. Uma transação por chamada; qualquer erro → rollback + `RAISE EXCEPTION 'linha %: %'`.

### `bulk_upsert_animals(p_property_id uuid, p_rows jsonb) returns jsonb`
Entrada: `[{number int|null, category text, breed text|null, body_condition int|null, observation text|null, lot_name text}]`.
- Resolve `lot_name` → `lots.id` ativo da propriedade (erro se não existe).
- `number` presente e existe ativo na propriedade → `UPDATE` campos enviados (null não sobrescreve; string vazia limpa).
- `number` ausente/inexistente → `INSERT`; number null → `generate_animal_number`.
- Retorna `{"created": n, "updated": n}`.
- Mudança de lote via import reusa a lógica de `move_animal_to_lot` (mesma validação).

### `bulk_register_sanitary(p_property_id uuid, p_rows jsonb) returns jsonb`
Entrada: `[{animal_number int, dose_name text, applied_at date, notes text|null}]`.
- Resolve animal por número (ativo), dose por `lower(name)` ativa; erro se não existe.
- Agrupa por `(animal.lot_id, dose_id, applied_at, notes)`; para cada grupo chama `register_sanitary_application(lot_id, dose_id, applied_at, animal_ids, notes)`.
- Retorna `{"applications": n, "animals": n}`.

### `bulk_upsert_doses(p_property_id uuid, p_rows jsonb) returns jsonb`
Entrada: `[{name, active_ingredient, dosage_per_kg, cost_per_kg}]`. Match por `lower(trim(name))` ativa. Retorna `{"created","updated"}`.

### DG
Sem RPC nova. Cliente traduz `numero_animal → animal_id` (animais membros do ATF) e `resultado` (Prenhe/Vazia/Duvidosa → pregnant/not_pregnant/doubtful) e chama `save_dg_records`.

## Fluxo de import (3 passos)

1. **Arquivo** — seletor de entidade, drop zone/botão `.xlsx|.csv`, "Baixar modelo" (xlsx com cabeçalhos + 2 linhas exemplo). Limite 5.000 linhas. Lê a primeira aba; linha 1 = cabeçalho.
2. **Mapear colunas** — grid `coluna do arquivo | amostra (3 valores) | campo ▾`. Auto-match por `header_matcher`. Obrigatórios faltando bloqueiam "Revisar". Checkbox "Lembrar este mapeamento" (default ligado) salva por entidade+hash de cabeçalhos; reimport do mesmo layout pula o passo com aviso "mapeamento reaproveitado".
3. **Revisar** — grade somente-leitura, linha com borda esquerda: verde = nova, verde-médio = atualiza, vermelho = erro (mensagem inline). Resumo em chips. Filtro "Mostrar só erros". Botão "Importar N válidas" → 1 RPC. Sucesso → toast + invalida providers da propriedade + volta à tela de origem. Erro do servidor → mostra `linha N: motivo`.

Validação client-side (antes do RPC): tipos, enums (label pt-BR ou chave), ECC 1–5, data `dd/MM/yyyy` ou serial Excel, lote/dose/animal existentes (lista carregada dos providers). Servidor revalida via constraints/triggers.

## Grade editável

`EditableGrid(schema, rows, onSave(changedRows), mode: cells|checkbox)`:
- Células: texto / número / dropdown (enum e lookups como lote) / data. Clique, Enter ou digitar começa edição; **Tab/Enter** avança (Shift volta); **Esc** cancela a célula.
- **Ctrl+V**: cola TSV da área de transferência a partir da célula focada, n linhas × m colunas; enums aceitam label ou chave; valores inválidos viram célula com erro.
- Dirty: célula alterada `accentContainer` + borda `accentBorder`; erro: borda `danger` 2px; "Salvar" desabilitado se há erro.
- Barra inferior fixa escura (`ink`): "N células alteradas em M linhas · [Descartar] [Salvar alterações]". Sair com dirty → diálogo de confirmação.
- Salvar → RPC bulk com só as linhas alteradas → `invalidate_property_data` → toast.

Onde:
- **Animais**: toggle lista/grade no header de `/animais`. Colunas: Nº (read-only), Categoria, Raça, ECC, Lote (dropdown), Observação. Animais com baixa não aparecem.
- **Doses**: grade no catálogo; "+ linha" cria dose nova.
- **Sanitário multi-dose** (`/sanitario/grade`): header com Lote ▾, Data, "+ Adicionar dose" (coluna). Linhas = animais ativos do lote, colunas = doses escolhidas, célula = checkbox; linha "marcar todos"; rodapé com totais por dose (animais, volume, custo — reusa `sanitary_calculations`). Salvar → `bulk_register_sanitary` (1 aplicação por coluna marcada). Checagem de duplicata recente reaproveita `findRecentIdenticalApplication` por coluna antes de enviar.

## Export

Botão "Exportar" nas 4 telas. Gera `.xlsx` (1 aba) com as linhas visíveis após filtros/ordenação da tela, cabeçalhos do schema em pt-BR, datas como data Excel, números como número. Nome: `campo-gestor_<entidade>_<propriedade>_<yyyyMMdd>.xlsx`. Download via anchor blob (web). Export de animais inclui colunas derivadas somente-leitura (Piquete, UA, Status reprodutivo) marcadas no schema como `exportOnly`.

## Erros

- Arquivo ilegível/vazio/sem cabeçalho → mensagem no passo 1.
- > 5.000 linhas → bloqueia com contagem.
- RPC falha → rollback total; UI mostra linha e motivo. Preview é somente-leitura em v1: usuário corrige no arquivo e reimporta, ou a linha já foi excluída por ser inválida.
- Conflito de número gerado em paralelo → `generate_animal_number` usa advisory lock, seguro.

## Testes

- Unit (Dart): `header_matcher` (aliases, acentos), `sheet_codec` (csv `;`/`,`/BOM, xlsx round-trip), validador de `import_preview` (cada regra), `EditableGrid` paste parsing.
- Widget: `EditableGrid` (Tab/Enter/Esc, dirty, Ctrl+V), `import_flow_screen` bloqueio de obrigatórios.
- pgTAP: 3 RPCs — upsert cria/atualiza, rollback em erro, RLS nega membro não-vet, `bulk_register_sanitary` agrupa corretamente.

## Fora de escopo / depois

- Presets de mapeamento por software (precisa arquivo exemplo).
- Preview editável antes de importar.
- Import de ATF/lotes/piquetes.
- Campos novos no animal (peso, nascimento, identificação externa).
