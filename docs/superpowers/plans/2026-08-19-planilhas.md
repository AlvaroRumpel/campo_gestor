# Planilhas (export / import / grade) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Exportar `.xlsx`, importar `.xlsx/.csv` com mapeamento de colunas + preview, e editar em grade (animais, doses, sanitário multi-dose) com salvamento em lote via RPCs atômicas.

**Architecture:** Módulo `lib/features/planilhas/` com `SheetSchema` como fonte única de colunas por entidade (export header, alvos de mapeamento, colunas da grade). Cliente parseia/valida; 3 RPCs Postgres (`bulk_upsert_animals`, `bulk_register_sanitary`, `bulk_upsert_doses`) gravam em transação; DG reusa `save_dg_records`. `EditableGrid` genérico com dirty-tracking serve animais, doses e grade multi-dose.

**Tech Stack:** Flutter 3.41 web, Riverpod 3 (providers manuais, sem codegen nos repos), go_router 17, supabase_flutter 2, `excel` (xlsx), `file_picker` (upload web), `package:web` (download), pgTAP.

**Spec:** `docs/superpowers/specs/2026-08-19-planilhas-design.md`

## Global Constraints

- Widgets nunca importam `supabase_flutter` — só via `SupabaseService` nos repositórios.
- Datas date-only: `DateFormat('yyyy-MM-dd')`, nunca `.toUtc()`.
- Após qualquer mutação: `ref.invalidatePropertyData()` (extension em `lib/core/providers/invalidate_property_data.dart`).
- RPCs seguem o padrão das existentes: `SECURITY DEFINER`, `SET search_path = public`, guardas explícitas `is_member_of` + `get_role = 'veterinarian'`, `REVOKE ALL FROM public; GRANT EXECUTE TO authenticated`. (Ajuste sobre a spec, que dizia INVOKER — seguir o padrão do repo.)
- Migration: `supabase/migrations/20260820_15_bulk_sheets.sql`; teste pgTAP `supabase/tests/15_bulk_sheets_test.sql`. Aplicar em PROD só via `supabase db push` (CLI já linkada) após aprovação do usuário.
- Cores: só `AppColors.*` (`lib/core/theme/app_colors.dart`). Fontes: Archivo (UI), `monoStyle()` p/ números.
- Labels pt-BR. Categoria via `kCategoryLabels` (`lib/features/animais/data/animal_constants.dart`).
- Limite import: 5.000 linhas.
- Edição de animais/doses/sanitário = só `veterinarian` (mesma regra `_canEdit` das telas).
- GSD: execute via `/gsd-quick` ou `/gsd-execute-phase` para commits atômicos; mensagens de commit em português, prefixo `feat(planilhas):`.
- Rodar `flutter analyze` antes de cada commit; zero warnings novos.

---

## File map

| Arquivo | Responsabilidade |
|---|---|
| `supabase/migrations/20260820_15_bulk_sheets.sql` | 3 RPCs bulk |
| `supabase/tests/15_bulk_sheets_test.sql` | pgTAP das RPCs |
| `lib/features/planilhas/domain/sheet_schema.dart` | `SheetColumn`, `SheetSchema`, `SheetColumnType`, schemas `animaisSchema`, `dosesSchema`, `sanitarioSchema`, `dgSchema` |
| `lib/features/planilhas/domain/header_matcher.dart` | `normalizeHeader`, `autoMatch` |
| `lib/features/planilhas/domain/import_preview.dart` | `ImportRowStatus`, `ImportRow`, `ImportContext`, `validateRows` |
| `lib/features/planilhas/data/sheet_codec.dart` | `SheetTable`, `parseCsv`, `parseXlsx`, `encodeXlsx`, `decodeSheet` |
| `lib/features/planilhas/data/column_mapping.dart` | `ColumnMappingStore` (shared_preferences) |
| `lib/features/planilhas/data/bulk_repository.dart` | `BulkRepository` + `bulkRepositoryProvider` |
| `lib/features/planilhas/data/download_web.dart` | `downloadBytes(name, bytes)` via `package:web` |
| `lib/features/planilhas/presentation/export_button.dart` | `ExportButton(schema, rows, fileStem)` |
| `lib/features/planilhas/presentation/import_flow_screen.dart` | 3 passos |
| `lib/features/planilhas/presentation/editable_grid.dart` | `EditableGrid`, `GridChange` |
| `lib/features/planilhas/presentation/animais_grid_view.dart` | grade de animais |
| `lib/features/planilhas/presentation/doses_grid_view.dart` | grade de doses |
| `lib/features/planilhas/presentation/sanitario_grade_screen.dart` | animais × doses |
| `lib/core/router/routes.dart` + `router.dart` | rotas `/planilhas/importar/:entity`, `/sanitario/grade` |
| `lib/features/animais/presentation/animais_table_view.dart` | botões Exportar/Importar + toggle lista/grade |
| `lib/features/sanitario/presentation/sanitario_screen.dart` | botões Exportar/Importar/Grade |
| `lib/features/reproducao/presentation/atf_detail_screen.dart` | botões Exportar/Importar DG |

---

### Task 1: Migration — RPCs bulk + pgTAP

**Files:**
- Create: `supabase/migrations/20260820_15_bulk_sheets.sql`
- Create: `supabase/tests/15_bulk_sheets_test.sql`

**Interfaces:**
- Produces: `bulk_upsert_animals(p_property_id uuid, p_rows jsonb) returns jsonb {"created":int,"updated":int}`; `bulk_upsert_doses(p_property_id uuid, p_rows jsonb) returns jsonb {"created","updated"}`; `bulk_register_sanitary(p_property_id uuid, p_rows jsonb) returns jsonb {"applications","animals"}`.
- Row shapes: animals `{number:int|null, category:text, breed:text|null, body_condition:int|null, observation:text|null, lot_name:text}`; doses `{name, active_ingredient, dosage_per_kg, cost_per_kg}`; sanitary `{animal_number:int, dose_name:text, applied_at:date, notes:text|null}`.

- [ ] **Step 1: Write pgTAP test (red)**

`supabase/tests/15_bulk_sheets_test.sql` — mirror fixture style of `06_sanitary_test.sql` (properties, auth.users, property_members, paddock, lots, doses; `set_config('request.jwt.claim.sub', ...)` + `set_config('request.jwt.claim.role','authenticated')` for impersonation; `BEGIN; SELECT plan(N); ... SELECT * FROM finish(); ROLLBACK;`). Assertions (plan(14)):

```sql
-- vet A impersonated
SELECT lives_ok($$SELECT bulk_upsert_doses('a0000000-0015-0015-0015-000000000001',
  '[{"name":"Ivermectina","active_ingredient":"ivermectina","dosage_per_kg":0.02,"cost_per_kg":0.5}]'::jsonb)$$, 'doses: insert ok');
SELECT is((SELECT count(*) FROM doses WHERE property_id='a0000000-0015-0015-0015-000000000001' AND lower(name)='ivermectina'), 1::bigint, 'doses: 1 row');
SELECT is((bulk_upsert_doses('a0000000-0015-0015-0015-000000000001',
  '[{"name":"ivermectina","dosage_per_kg":0.03}]'::jsonb))->>'updated', '1', 'doses: same name updates');
SELECT is((SELECT dosage_per_kg FROM doses WHERE lower(name)='ivermectina' AND property_id='a0000000-0015-0015-0015-000000000001'), 0.03::numeric, 'doses: dosage updated');

SELECT is((bulk_upsert_animals('a0000000-0015-0015-0015-000000000001',
  '[{"number":500,"category":"vaca","breed":"Nelore","lot_name":"Lote A1"},
    {"number":null,"category":"novilha","lot_name":"Lote A1"}]'::jsonb))->>'created', '2', 'animals: 2 created');
SELECT is((SELECT count(*) FROM animals WHERE property_id='a0000000-0015-0015-0015-000000000001' AND deleted_at IS NULL), 2::bigint, 'animals: rows exist');
SELECT is((bulk_upsert_animals('a0000000-0015-0015-0015-000000000001',
  '[{"number":500,"category":"vaca","body_condition":4,"lot_name":"Lote A1"}]'::jsonb))->>'updated', '1', 'animals: existing number updates');
SELECT is((SELECT body_condition FROM animals WHERE number=500 AND property_id='a0000000-0015-0015-0015-000000000001'), 4, 'animals: ecc updated');
SELECT throws_ok($$SELECT bulk_upsert_animals('a0000000-0015-0015-0015-000000000001',
  '[{"number":501,"category":"vaca","lot_name":"Lote A1"},{"number":502,"category":"vaca","lot_name":"Nao Existe"}]'::jsonb)$$,
  'P0001', 'linha 2: lote "Nao Existe" não encontrado', 'animals: unknown lot raises with line');
SELECT is((SELECT count(*) FROM animals WHERE number=501 AND property_id='a0000000-0015-0015-0015-000000000001'), 0::bigint, 'animals: rollback on error');
SELECT throws_ok($$SELECT bulk_upsert_animals('a0000000-0015-0015-0015-000000000001',
  '[{"number":503,"category":"bezerro","lot_name":"Lote A1"}]'::jsonb)$$, 'P0001', 'linha 1: categoria "bezerro" inválida', 'animals: bad category');

SELECT is((bulk_register_sanitary('a0000000-0015-0015-0015-000000000001',
  '[{"animal_number":500,"dose_name":"Ivermectina","applied_at":"2026-08-01"},
    {"animal_number":500,"dose_name":"Ivermectina","applied_at":"2026-08-02"}]'::jsonb))->>'applications', '2', 'sanitary: groups by date');

-- reader A impersonated
SELECT throws_ok($$SELECT bulk_upsert_doses('a0000000-0015-0015-0015-000000000001','[{"name":"X","dosage_per_kg":1}]'::jsonb)$$, '42501', NULL, 'doses: reader forbidden');
SELECT throws_ok($$SELECT bulk_upsert_animals('a0000000-0015-0015-0015-000000000001','[{"number":600,"category":"vaca","lot_name":"Lote A1"}]'::jsonb)$$, '42501', NULL, 'animals: reader forbidden');
```

- [ ] **Step 2: Run test to verify it fails**

Run: `supabase test db --file supabase/tests/15_bulk_sheets_test.sql` (fallback: MCP `execute_sql` BEGIN/ROLLBACK replay, padrão do projeto).
Expected: FAIL — function bulk_upsert_doses does not exist.

- [ ] **Step 3: Write migration**

```sql
-- 20260820_15_bulk_sheets.sql — RPCs de importação/grade em lote (spec planilhas)
-- Padrão: SECURITY DEFINER + guardas explícitas (mesmo de register_sanitary_application).
-- Erro em qualquer linha → RAISE com "linha N: motivo" → transação inteira desfeita.

CREATE OR REPLACE FUNCTION assert_vet_of(p_property_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF p_property_id IS NULL THEN
    RAISE EXCEPTION 'property_id is required' USING ERRCODE = '22023';
  END IF;
  IF NOT is_member_of(p_property_id) THEN
    RAISE EXCEPTION 'forbidden: not a member of property %', p_property_id USING ERRCODE = '42501';
  END IF;
  IF get_role(p_property_id) <> 'veterinarian'::role_enum THEN
    RAISE EXCEPTION 'forbidden: only veterinarians can bulk-write' USING ERRCODE = '42501';
  END IF;
END; $$;
REVOKE ALL ON FUNCTION assert_vet_of(uuid) FROM public;

-- ---------------------------------------------------------------- doses
CREATE OR REPLACE FUNCTION bulk_upsert_doses(p_property_id uuid, p_rows jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  r jsonb; i int := 0; v_created int := 0; v_updated int := 0;
  v_name text; v_id uuid; v_dosage numeric; v_cost numeric;
BEGIN
  PERFORM assert_vet_of(p_property_id);
  IF p_rows IS NULL OR jsonb_typeof(p_rows) <> 'array' THEN
    RAISE EXCEPTION 'rows must be a json array' USING ERRCODE = '22023';
  END IF;
  FOR r IN SELECT * FROM jsonb_array_elements(p_rows) LOOP
    i := i + 1;
    v_name := nullif(trim(r->>'name'), '');
    IF v_name IS NULL THEN
      RAISE EXCEPTION 'linha %: nome da dose obrigatório', i;
    END IF;
    v_dosage := (r->>'dosage_per_kg')::numeric;
    v_cost   := (r->>'cost_per_kg')::numeric;
    SELECT id INTO v_id FROM doses
     WHERE property_id = p_property_id AND deleted_at IS NULL AND lower(trim(name)) = lower(v_name);
    IF v_id IS NULL THEN
      IF v_dosage IS NULL OR v_dosage <= 0 THEN
        RAISE EXCEPTION 'linha %: dosagem por kg obrigatória e > 0', i;
      END IF;
      INSERT INTO doses (property_id, name, active_ingredient, dosage_per_kg, cost_per_kg)
      VALUES (p_property_id, v_name, nullif(trim(r->>'active_ingredient'), ''), v_dosage, v_cost);
      v_created := v_created + 1;
    ELSE
      UPDATE doses SET
        active_ingredient = CASE WHEN r ? 'active_ingredient' THEN nullif(trim(r->>'active_ingredient'), '') ELSE active_ingredient END,
        dosage_per_kg     = COALESCE(v_dosage, dosage_per_kg),
        cost_per_kg       = CASE WHEN r ? 'cost_per_kg' THEN v_cost ELSE cost_per_kg END
      WHERE id = v_id;
      v_updated := v_updated + 1;
    END IF;
  END LOOP;
  RETURN jsonb_build_object('created', v_created, 'updated', v_updated);
EXCEPTION WHEN check_violation THEN
  RAISE EXCEPTION 'linha %: valor inválido (%)', i, SQLERRM;
END; $$;
REVOKE ALL ON FUNCTION bulk_upsert_doses(uuid, jsonb) FROM public;
GRANT EXECUTE ON FUNCTION bulk_upsert_doses(uuid, jsonb) TO authenticated;

-- ---------------------------------------------------------------- animals
CREATE OR REPLACE FUNCTION bulk_upsert_animals(p_property_id uuid, p_rows jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  r jsonb; i int := 0; v_created int := 0; v_updated int := 0;
  v_number int; v_category text; v_lot_id uuid; v_lot_name text; v_id uuid; v_ecc int;
  k_categories text[] := ARRAY['vaca','novilha','terneiro','terneira','touro','boi','novilho'];
BEGIN
  PERFORM assert_vet_of(p_property_id);
  IF p_rows IS NULL OR jsonb_typeof(p_rows) <> 'array' THEN
    RAISE EXCEPTION 'rows must be a json array' USING ERRCODE = '22023';
  END IF;
  FOR r IN SELECT * FROM jsonb_array_elements(p_rows) LOOP
    i := i + 1;
    v_number   := (r->>'number')::int;
    v_category := lower(trim(r->>'category'));
    v_lot_name := nullif(trim(r->>'lot_name'), '');
    v_ecc      := (r->>'body_condition')::int;

    IF v_category IS NULL OR NOT (v_category = ANY (k_categories)) THEN
      RAISE EXCEPTION 'linha %: categoria "%" inválida', i, COALESCE(r->>'category', '');
    END IF;
    IF v_ecc IS NOT NULL AND (v_ecc < 1 OR v_ecc > 5) THEN
      RAISE EXCEPTION 'linha %: ECC deve ser de 1 a 5', i;
    END IF;
    IF v_lot_name IS NOT NULL THEN
      SELECT id INTO v_lot_id FROM lots
       WHERE property_id = p_property_id AND deleted_at IS NULL AND lower(name) = lower(v_lot_name);
      IF v_lot_id IS NULL THEN
        RAISE EXCEPTION 'linha %: lote "%" não encontrado', i, v_lot_name;
      END IF;
    ELSE
      v_lot_id := NULL;
    END IF;

    v_id := NULL;
    IF v_number IS NOT NULL THEN
      SELECT id INTO v_id FROM animals
       WHERE property_id = p_property_id AND deleted_at IS NULL AND number = v_number;
    END IF;

    IF v_id IS NULL THEN
      IF v_lot_id IS NULL THEN
        RAISE EXCEPTION 'linha %: lote obrigatório para animal novo', i;
      END IF;
      IF v_number IS NULL THEN
        v_number := generate_animal_number(p_property_id);
      END IF;
      INSERT INTO animals (property_id, lot_id, category, number, breed, body_condition, observation)
      VALUES (p_property_id, v_lot_id, v_category, v_number,
              nullif(trim(r->>'breed'), ''), v_ecc, nullif(trim(r->>'observation'), ''));
      v_created := v_created + 1;
    ELSE
      UPDATE animals SET
        category       = v_category,
        lot_id         = COALESCE(v_lot_id, lot_id),
        breed          = CASE WHEN r ? 'breed' THEN nullif(trim(r->>'breed'), '') ELSE breed END,
        body_condition = CASE WHEN r ? 'body_condition' THEN v_ecc ELSE body_condition END,
        observation    = CASE WHEN r ? 'observation' THEN nullif(trim(r->>'observation'), '') ELSE observation END
      WHERE id = v_id;
      v_updated := v_updated + 1;
    END IF;
  END LOOP;
  RETURN jsonb_build_object('created', v_created, 'updated', v_updated);
EXCEPTION
  WHEN unique_violation THEN RAISE EXCEPTION 'linha %: número já existe na propriedade', i;
  WHEN check_violation  THEN RAISE EXCEPTION 'linha %: valor inválido (%)', i, SQLERRM;
END; $$;
REVOKE ALL ON FUNCTION bulk_upsert_animals(uuid, jsonb) FROM public;
GRANT EXECUTE ON FUNCTION bulk_upsert_animals(uuid, jsonb) TO authenticated;

-- ---------------------------------------------------------------- sanitary
CREATE OR REPLACE FUNCTION bulk_register_sanitary(p_property_id uuid, p_rows jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  g record; v_apps int := 0; v_animals int := 0; i int := 0; r jsonb;
BEGIN
  PERFORM assert_vet_of(p_property_id);
  IF p_rows IS NULL OR jsonb_typeof(p_rows) <> 'array' THEN
    RAISE EXCEPTION 'rows must be a json array' USING ERRCODE = '22023';
  END IF;

  CREATE TEMP TABLE _bulk_san (idx int, animal_id uuid, lot_id uuid, dose_id uuid, applied_at date, notes text) ON COMMIT DROP;

  FOR r IN SELECT * FROM jsonb_array_elements(p_rows) LOOP
    i := i + 1;
    INSERT INTO _bulk_san
    SELECT i, a.id, a.lot_id, d.id, (r->>'applied_at')::date, nullif(trim(r->>'notes'), '')
      FROM animals a
      LEFT JOIN doses d ON d.property_id = p_property_id AND d.deleted_at IS NULL
                       AND lower(trim(d.name)) = lower(trim(r->>'dose_name'))
     WHERE a.property_id = p_property_id AND a.deleted_at IS NULL AND a.number = (r->>'animal_number')::int;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'linha %: animal nº % não encontrado', i, r->>'animal_number';
    END IF;
    IF (SELECT dose_id FROM _bulk_san WHERE idx = i) IS NULL THEN
      RAISE EXCEPTION 'linha %: dose "%" não encontrada', i, r->>'dose_name';
    END IF;
    IF (SELECT applied_at FROM _bulk_san WHERE idx = i) IS NULL THEN
      RAISE EXCEPTION 'linha %: data obrigatória', i;
    END IF;
  END LOOP;

  FOR g IN
    SELECT lot_id, dose_id, applied_at, notes, jsonb_agg(DISTINCT animal_id) AS ids, count(DISTINCT animal_id) AS n
      FROM _bulk_san GROUP BY lot_id, dose_id, applied_at, notes
  LOOP
    PERFORM register_sanitary_application(g.lot_id, g.dose_id, g.applied_at, g.ids, g.notes);
    v_apps := v_apps + 1; v_animals := v_animals + g.n;
  END LOOP;
  RETURN jsonb_build_object('applications', v_apps, 'animals', v_animals);
END; $$;
REVOKE ALL ON FUNCTION bulk_register_sanitary(uuid, jsonb) FROM public;
GRANT EXECUTE ON FUNCTION bulk_register_sanitary(uuid, jsonb) TO authenticated;
```

- [ ] **Step 4: Apply locally + run test**

Run: `supabase db reset` (ou aplicar via MCP em branch/dev) e `supabase test db`.
Expected: 14/14 pass.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20260820_15_bulk_sheets.sql supabase/tests/15_bulk_sheets_test.sql
git commit -m "feat(planilhas): RPCs bulk_upsert_animals/doses e bulk_register_sanitary + pgTAP"
```

---

### Task 2: Deps + SheetCodec (csv/xlsx ↔ tabela)

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/features/planilhas/data/sheet_codec.dart`
- Test: `test/features/planilhas/sheet_codec_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class SheetTable { final List<String> headers; final List<List<String>> rows; }
  SheetTable parseCsv(String text);            // detecta ; ou , ; remove BOM
  SheetTable parseXlsx(Uint8List bytes);       // primeira aba; células → String (datas → dd/MM/yyyy)
  SheetTable decodeSheet(String fileName, Uint8List bytes); // despacha por extensão
  Uint8List encodeXlsx({required String sheetName, required List<String> headers, required List<List<Object?>> rows});
  ```

- [ ] **Step 1: Add deps**

Run: `flutter pub add excel file_picker web`
Expected: pubspec atualizado, `flutter pub get` ok.

- [ ] **Step 2: Write failing tests**

```dart
// test/features/planilhas/sheet_codec_test.dart
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:campo_gestor/features/planilhas/data/sheet_codec.dart';

void main() {
  group('parseCsv', () {
    test('detecta ; e remove BOM', () {
      final t = parseCsv('﻿Nº;Categoria\n1;Vaca\n2;Touro\n');
      expect(t.headers, ['Nº', 'Categoria']);
      expect(t.rows, [['1', 'Vaca'], ['2', 'Touro']]);
    });
    test('detecta , e respeita aspas', () {
      final t = parseCsv('a,b\n"x, y",2\n');
      expect(t.rows.single, ['x, y', '2']);
    });
    test('ignora linhas vazias', () {
      final t = parseCsv('a;b\n\n1;2\n\n');
      expect(t.rows.length, 1);
    });
  });

  test('xlsx round-trip', () {
    final bytes = encodeXlsx(
      sheetName: 'Animais',
      headers: ['Nº', 'Raça', 'Data'],
      rows: [[1, 'Nelore', DateTime(2026, 8, 19)], [2, null, null]],
    );
    final t = parseXlsx(Uint8List.fromList(bytes));
    expect(t.headers, ['Nº', 'Raça', 'Data']);
    expect(t.rows[0], ['1', 'Nelore', '19/08/2026']);
    expect(t.rows[1], ['2', '', '']);
  });

  test('decodeSheet despacha por extensão', () {
    expect(decodeSheet('x.CSV', Uint8List.fromList('a;b\n1;2'.codeUnits)).rows, [['1', '2']]);
    expect(() => decodeSheet('x.txt', Uint8List(0)), throwsA(isA<FormatException>()));
  });
}
```

- [ ] **Step 3: Run, verify fail**

Run: `rtk flutter test test/features/planilhas/sheet_codec_test.dart`
Expected: FAIL (arquivo não existe).

- [ ] **Step 4: Implement**

```dart
// lib/features/planilhas/data/sheet_codec.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

class SheetTable {
  const SheetTable({required this.headers, required this.rows});
  final List<String> headers;
  final List<List<String>> rows;
}

final _brDate = DateFormat('dd/MM/yyyy');

SheetTable decodeSheet(String fileName, Uint8List bytes) {
  final ext = fileName.toLowerCase().split('.').last;
  switch (ext) {
    case 'csv':
      return parseCsv(utf8.decode(bytes, allowMalformed: true));
    case 'xlsx':
      return parseXlsx(bytes);
    default:
      throw FormatException('Formato não suportado: .$ext (use .xlsx ou .csv)');
  }
}

SheetTable parseCsv(String text) {
  var src = text;
  if (src.startsWith('﻿')) src = src.substring(1);
  final lines = const LineSplitter().convert(src).where((l) => l.trim().isNotEmpty).toList();
  if (lines.isEmpty) return const SheetTable(headers: [], rows: []);
  final sep = lines.first.split(';').length >= lines.first.split(',').length ? ';' : ',';
  List<String> split(String line) {
    final out = <String>[];
    final buf = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') { buf.write('"'); i++; }
        else { inQuotes = !inQuotes; }
      } else if (c == sep && !inQuotes) {
        out.add(buf.toString().trim()); buf.clear();
      } else {
        buf.write(c);
      }
    }
    out.add(buf.toString().trim());
    return out;
  }
  final headers = split(lines.first);
  final rows = lines.skip(1).map(split).map((r) {
    // normaliza largura
    if (r.length < headers.length) return [...r, ...List.filled(headers.length - r.length, '')];
    return r.take(headers.length).toList();
  }).toList();
  return SheetTable(headers: headers, rows: rows);
}

String _cellToString(Data? cell) {
  final v = cell?.value;
  if (v == null) return '';
  if (v is DateCellValue) return _brDate.format(DateTime(v.year, v.month, v.day));
  if (v is DateTimeCellValue) return _brDate.format(DateTime(v.year, v.month, v.day));
  if (v is IntCellValue) return v.value.toString();
  if (v is DoubleCellValue) {
    final d = v.value;
    return d == d.roundToDouble() ? d.toInt().toString() : d.toString().replaceAll('.', ',');
  }
  if (v is TextCellValue) return v.value.text ?? '';
  if (v is BoolCellValue) return v.value ? 'sim' : 'não';
  return v.toString();
}

SheetTable parseXlsx(Uint8List bytes) {
  final book = Excel.decodeBytes(bytes);
  if (book.tables.isEmpty) return const SheetTable(headers: [], rows: []);
  final sheet = book.tables.values.first;
  final all = sheet.rows.map((r) => r.map(_cellToString).toList()).toList();
  final nonEmpty = all.where((r) => r.any((c) => c.isNotEmpty)).toList();
  if (nonEmpty.isEmpty) return const SheetTable(headers: [], rows: []);
  final headers = nonEmpty.first.map((h) => h.trim()).toList();
  while (headers.isNotEmpty && headers.last.isEmpty) headers.removeLast();
  final rows = nonEmpty.skip(1).map((r) {
    final fixed = r.length < headers.length ? [...r, ...List.filled(headers.length - r.length, '')] : r.take(headers.length).toList();
    return fixed;
  }).toList();
  return SheetTable(headers: headers, rows: rows);
}

Uint8List encodeXlsx({
  required String sheetName,
  required List<String> headers,
  required List<List<Object?>> rows,
}) {
  final book = Excel.createExcel();
  final defaultName = book.getDefaultSheet()!;
  book.rename(defaultName, sheetName);
  final sheet = book[sheetName];
  sheet.appendRow([for (final h in headers) TextCellValue(h)]);
  for (final r in rows) {
    sheet.appendRow([
      for (final v in r)
        switch (v) {
          null => TextCellValue(''),
          int i => IntCellValue(i),
          double d => DoubleCellValue(d),
          DateTime dt => DateCellValue(year: dt.year, month: dt.month, day: dt.day),
          _ => TextCellValue(v.toString()),
        }
    ]);
  }
  return Uint8List.fromList(book.encode()!);
}
```

(Se a API do `excel` 4.x divergir nos nomes `DateCellValue`/`TextCellValue.value.text`, ajustar ao que `flutter pub` instalou — checar `pub cache` do pacote.)

- [ ] **Step 5: Run tests → pass; analyze; commit**

Run: `rtk flutter test test/features/planilhas/sheet_codec_test.dart && rtk flutter analyze`
```bash
git add pubspec.yaml pubspec.lock lib/features/planilhas/data/sheet_codec.dart test/features/planilhas/sheet_codec_test.dart
git commit -m "feat(planilhas): SheetCodec csv/xlsx + deps excel, file_picker, web"
```

---

### Task 3: SheetSchema + HeaderMatcher

**Files:**
- Create: `lib/features/planilhas/domain/sheet_schema.dart`
- Create: `lib/features/planilhas/domain/header_matcher.dart`
- Test: `test/features/planilhas/sheet_schema_test.dart`

**Interfaces:**
- Produces:
  ```dart
  enum SheetEntity { animais, doses, sanitario, dg }
  enum SheetColumnType { text, integer, decimal, date, enumeration }
  class SheetColumn {
    final String key, label; final SheetColumnType type; final bool required;
    final Map<String, String> enumValues; // chave → label pt-BR
    final List<String> aliases; final bool editable; final bool readOnlyWhenExisting; final bool exportOnly;
  }
  class SheetSchema { final SheetEntity entity; final String title; final String sheetName; final List<SheetColumn> columns;
    List<SheetColumn> get importColumns; List<SheetColumn> get requiredColumns; SheetColumn? byKey(String); List<List<Object?>> templateRows(); }
  final animaisSchema, dosesSchema, sanitarioSchema, dgSchema; SheetSchema schemaFor(SheetEntity e);
  String normalizeHeader(String h);
  Map<int, String> autoMatch(List<String> headers, SheetSchema schema); // índice da coluna do arquivo → column.key
  ```

- [ ] **Step 1: Failing tests**

```dart
// test/features/planilhas/sheet_schema_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:campo_gestor/features/planilhas/domain/header_matcher.dart';
import 'package:campo_gestor/features/planilhas/domain/sheet_schema.dart';

void main() {
  test('normalizeHeader remove acento, caixa e pontuação', () {
    expect(normalizeHeader(' Nº do Animal '), 'n do animal');
    expect(normalizeHeader('Raça'), 'raca');
    expect(normalizeHeader('ECC (1-5)'), 'ecc 15');
  });

  test('autoMatch casa aliases de animais', () {
    final m = autoMatch(['Brinco', 'Categ.', 'Raça', 'ECC', 'Lote', 'Peso'], animaisSchema);
    expect(m[0], 'number');
    expect(m[1], 'category');
    expect(m[2], 'breed');
    expect(m[3], 'body_condition');
    expect(m[4], 'lot_name');
    expect(m.containsKey(5), false);
  });

  test('autoMatch não repete alvo', () {
    final m = autoMatch(['Número', 'Nº'], animaisSchema);
    expect(m.values.where((v) => v == 'number').length, 1);
  });

  test('schemas têm obrigatórios e enum de categoria', () {
    expect(animaisSchema.requiredColumns.map((c) => c.key), containsAll(['category', 'lot_name']));
    expect(animaisSchema.byKey('category')!.enumValues['vaca'], 'Vaca');
    expect(dgSchema.byKey('result')!.enumValues['pregnant'], 'Prenhe');
    expect(schemaFor(SheetEntity.doses).importColumns.map((c) => c.key), contains('dosage_per_kg'));
    expect(animaisSchema.templateRows().length, 2);
  });
}
```

- [ ] **Step 2: Run → fail**

Run: `rtk flutter test test/features/planilhas/sheet_schema_test.dart` → FAIL.

- [ ] **Step 3: Implement**

```dart
// lib/features/planilhas/domain/sheet_schema.dart
import '../../animais/data/animal_constants.dart';

enum SheetEntity { animais, doses, sanitario, dg }
enum SheetColumnType { text, integer, decimal, date, enumeration }

class SheetColumn {
  const SheetColumn({
    required this.key,
    required this.label,
    this.type = SheetColumnType.text,
    this.required = false,
    this.enumValues = const {},
    this.aliases = const [],
    this.editable = true,
    this.readOnlyWhenExisting = false,
    this.exportOnly = false,
  });
  final String key;
  final String label;
  final SheetColumnType type;
  final bool required;
  final Map<String, String> enumValues;
  final List<String> aliases;
  final bool editable;
  final bool readOnlyWhenExisting;
  final bool exportOnly;
}

class SheetSchema {
  const SheetSchema({
    required this.entity,
    required this.title,
    required this.sheetName,
    required this.columns,
    this.templateExamples = const [],
  });
  final SheetEntity entity;
  final String title;
  final String sheetName;
  final List<SheetColumn> columns;
  final List<List<Object?>> templateExamples;

  List<SheetColumn> get importColumns => columns.where((c) => !c.exportOnly).toList();
  List<SheetColumn> get requiredColumns => importColumns.where((c) => c.required).toList();
  SheetColumn? byKey(String key) => columns.where((c) => c.key == key).firstOrNull;
  List<String> get importHeaders => importColumns.map((c) => c.label).toList();
  List<List<Object?>> templateRows() => templateExamples;
}

final animaisSchema = SheetSchema(
  entity: SheetEntity.animais,
  title: 'Animais',
  sheetName: 'Animais',
  columns: [
    const SheetColumn(key: 'number', label: 'Nº', type: SheetColumnType.integer,
        aliases: ['numero', 'n', 'n do animal', 'numero do animal', 'brinco', 'identificacao', 'id animal'],
        readOnlyWhenExisting: true),
    SheetColumn(key: 'category', label: 'Categoria', type: SheetColumnType.enumeration, required: true,
        enumValues: kCategoryLabels, aliases: const ['categ', 'cat', 'classe']),
    const SheetColumn(key: 'breed', label: 'Raça', aliases: ['raca']),
    const SheetColumn(key: 'body_condition', label: 'ECC', type: SheetColumnType.integer,
        aliases: ['ecc', 'ecc 15', 'escore', 'escore corporal', 'condicao corporal', 'cc']),
    const SheetColumn(key: 'lot_name', label: 'Lote', required: true, aliases: ['lote', 'nome do lote', 'grupo']),
    const SheetColumn(key: 'observation', label: 'Observação', aliases: ['obs', 'observacao', 'observacoes', 'notas']),
    const SheetColumn(key: 'paddock_name', label: 'Piquete', exportOnly: true),
    const SheetColumn(key: 'ua', label: 'UA', type: SheetColumnType.decimal, exportOnly: true),
  ],
  templateExamples: const [
    [1001, 'Vaca', 'Nelore', 3, 'Lote 01', ''],
    [null, 'Novilha', 'Angus', 4, 'Lote 01', 'número gerado ao importar'],
  ],
);

final dosesSchema = SheetSchema(
  entity: SheetEntity.doses,
  title: 'Doses',
  sheetName: 'Doses',
  columns: const [
    SheetColumn(key: 'name', label: 'Nome', required: true, aliases: ['dose', 'produto', 'vacina', 'medicamento', 'nome da dose']),
    SheetColumn(key: 'active_ingredient', label: 'Princípio ativo', aliases: ['principio ativo', 'principio', 'ativo']),
    SheetColumn(key: 'dosage_per_kg', label: 'Dosagem (ml/kg)', type: SheetColumnType.decimal, required: true,
        aliases: ['dosagem', 'dosagem por kg', 'ml kg', 'mlkg', 'dose por kg']),
    SheetColumn(key: 'cost_per_kg', label: 'Custo (R\$/kg)', type: SheetColumnType.decimal,
        aliases: ['custo', 'custo por kg', 'preco', 'r kg', 'rkg', 'valor']),
  ],
  templateExamples: const [
    ['Ivermectina 1%', 'ivermectina', 0.02, 0.5],
    ['Febre aftosa', '', 0.005, 0.3],
  ],
);

final sanitarioSchema = SheetSchema(
  entity: SheetEntity.sanitario,
  title: 'Aplicações sanitárias',
  sheetName: 'Aplicacoes',
  columns: const [
    SheetColumn(key: 'animal_number', label: 'Nº do animal', type: SheetColumnType.integer, required: true,
        aliases: ['numero', 'n', 'n do animal', 'numero do animal', 'brinco', 'animal']),
    SheetColumn(key: 'dose_name', label: 'Dose', required: true, aliases: ['dose', 'produto', 'vacina', 'medicamento']),
    SheetColumn(key: 'applied_at', label: 'Data', type: SheetColumnType.date, required: true,
        aliases: ['data', 'data da aplicacao', 'aplicado em', 'dt']),
    SheetColumn(key: 'notes', label: 'Observação', aliases: ['obs', 'observacao', 'notas']),
    SheetColumn(key: 'lot_name', label: 'Lote', exportOnly: true),
    SheetColumn(key: 'category', label: 'Categoria', exportOnly: true),
  ],
  templateExamples: const [
    [1001, 'Ivermectina 1%', '19/08/2026', ''],
    [1002, 'Ivermectina 1%', '19/08/2026', ''],
  ],
);

final dgSchema = SheetSchema(
  entity: SheetEntity.dg,
  title: 'Diagnóstico de gestação',
  sheetName: 'DG',
  columns: const [
    SheetColumn(key: 'animal_number', label: 'Nº do animal', type: SheetColumnType.integer, required: true,
        aliases: ['numero', 'n', 'n do animal', 'numero do animal', 'brinco', 'animal']),
    SheetColumn(key: 'result', label: 'Resultado', type: SheetColumnType.enumeration, required: true,
        enumValues: {'pregnant': 'Prenhe', 'not_pregnant': 'Vazia', 'doubtful': 'Duvidosa'},
        aliases: ['dg', 'diagnostico', 'resultado dg', 'status']),
    SheetColumn(key: 'exam_date', label: 'Data do exame', type: SheetColumnType.date, required: true,
        aliases: ['data', 'data do exame', 'data dg', 'exame']),
    SheetColumn(key: 'observation', label: 'Observação', aliases: ['obs', 'observacao', 'notas']),
    SheetColumn(key: 'category', label: 'Categoria', exportOnly: true),
  ],
  templateExamples: const [
    [1001, 'Prenhe', '19/08/2026', ''],
    [1002, 'Vazia', '19/08/2026', ''],
  ],
);

SheetSchema schemaFor(SheetEntity e) => switch (e) {
      SheetEntity.animais => animaisSchema,
      SheetEntity.doses => dosesSchema,
      SheetEntity.sanitario => sanitarioSchema,
      SheetEntity.dg => dgSchema,
    };
```

```dart
// lib/features/planilhas/domain/header_matcher.dart
import 'sheet_schema.dart';

const _accents = 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
const _plain   = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';

String normalizeHeader(String h) {
  final sb = StringBuffer();
  for (final ch in h.characters) {
    final i = _accents.indexOf(ch);
    sb.write(i >= 0 ? _plain[i] : ch);
  }
  return sb
      .toString()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Índice da coluna do arquivo → key do schema. Cada key é usada no máximo uma vez.
Map<int, String> autoMatch(List<String> headers, SheetSchema schema) {
  final result = <int, String>{};
  final used = <String>{};
  for (var i = 0; i < headers.length; i++) {
    final h = normalizeHeader(headers[i]);
    if (h.isEmpty) continue;
    for (final c in schema.importColumns) {
      if (used.contains(c.key)) continue;
      final candidates = {normalizeHeader(c.label), normalizeHeader(c.key), ...c.aliases.map(normalizeHeader)};
      if (candidates.contains(h)) {
        result[i] = c.key;
        used.add(c.key);
        break;
      }
    }
  }
  return result;
}
```
(`characters` vem de `package:characters` — já transitivo no Flutter; importar `package:characters/characters.dart` se o analyzer pedir.)

- [ ] **Step 4: Run → pass; commit**

```bash
git add lib/features/planilhas/domain test/features/planilhas/sheet_schema_test.dart
git commit -m "feat(planilhas): SheetSchema por entidade + auto-match de cabeçalhos"
```

---

### Task 4: ImportPreview — validação client-side

**Files:**
- Create: `lib/features/planilhas/domain/import_preview.dart`
- Test: `test/features/planilhas/import_preview_test.dart`

**Interfaces:**
- Produces:
  ```dart
  enum ImportRowStatus { create, update, error }
  class ImportRow { final int index /*1-based, linha do arquivo*/; final Map<String, dynamic> values; final ImportRowStatus status; final List<String> errors; }
  class ImportContext { final Set<int> existingAnimalNumbers; final Set<String> lotNamesLower; final Set<String> doseNamesLower; final Set<int> atfAnimalNumbers; }
  List<ImportRow> validateRows({required SheetSchema schema, required SheetTable table, required Map<int,String> mapping, required ImportContext ctx});
  Object? parseCell(SheetColumn col, String raw); // throws FormatException com mensagem pt-BR
  ```
  `values` usa a key do schema; datas viram `DateTime`; enum vira chave; vazio vira `null` (ausente do map quando coluna não mapeada).

- [ ] **Step 1: Failing tests**

```dart
// test/features/planilhas/import_preview_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:campo_gestor/features/planilhas/data/sheet_codec.dart';
import 'package:campo_gestor/features/planilhas/domain/import_preview.dart';
import 'package:campo_gestor/features/planilhas/domain/sheet_schema.dart';

void main() {
  final ctx = ImportContext(
    existingAnimalNumbers: {1021},
    lotNamesLower: {'lote 03'},
    doseNamesLower: {'ivermectina'},
    atfAnimalNumbers: {1021},
  );
  const mapping = {0: 'number', 1: 'category', 2: 'body_condition', 3: 'lot_name'};

  test('classifica create/update/error', () {
    final t = SheetTable(headers: ['N', 'Cat', 'ECC', 'Lote'], rows: [
      ['1021', 'Vaca', '3', 'Lote 03'],
      ['1022', 'novilha', '4', 'lote 03'],
      ['1023', 'Bezerro', '3', 'Lote 03'],
      ['1024', 'Vaca', '6', 'Lote 03'],
      ['1025', 'Vaca', '', 'Lote 12'],
      ['', 'Vaca', '', 'Lote 03'],
    ]);
    final rows = validateRows(schema: animaisSchema, table: t, mapping: mapping, ctx: ctx);
    expect(rows[0].status, ImportRowStatus.update);
    expect(rows[1].status, ImportRowStatus.create);
    expect(rows[1].values['category'], 'novilha');
    expect(rows[2].errors.single, contains('Categoria "Bezerro" inválida'));
    expect(rows[3].errors.single, 'ECC deve ser de 1 a 5');
    expect(rows[4].errors.single, 'Lote "Lote 12" não existe');
    expect(rows[5].status, ImportRowStatus.create);
    expect(rows[5].values.containsKey('number'), false);
    expect(rows[0].index, 2); // linha 1 = cabeçalho
  });

  test('parseCell: data dd/MM/yyyy e serial Excel', () {
    final col = sanitarioSchema.byKey('applied_at')!;
    expect(parseCell(col, '19/08/2026'), DateTime(2026, 8, 19));
    expect(parseCell(col, '46253'), DateTime(2026, 8, 19)); // serial Excel
    expect(() => parseCell(col, '2026-13-40'), throwsFormatException);
  });

  test('parseCell: decimal com vírgula', () {
    expect(parseCell(dosesSchema.byKey('dosage_per_kg')!, '0,02'), 0.02);
  });

  test('sanitário exige animal e dose existentes', () {
    final t = SheetTable(headers: ['N', 'Dose', 'Data'], rows: [
      ['1021', 'ivermectina', '01/08/2026'],
      ['9999', 'Ivermectina', '01/08/2026'],
      ['1021', 'Aftosa', '01/08/2026'],
    ]);
    final rows = validateRows(schema: sanitarioSchema, table: t,
        mapping: const {0: 'animal_number', 1: 'dose_name', 2: 'applied_at'}, ctx: ctx);
    expect(rows[0].status, ImportRowStatus.create);
    expect(rows[1].errors.single, 'Animal nº 9999 não encontrado');
    expect(rows[2].errors.single, 'Dose "Aftosa" não existe');
  });

  test('dg exige animal no ATF e resultado válido', () {
    final t = SheetTable(headers: ['N', 'R', 'D'], rows: [
      ['1021', 'Prenhe', '01/08/2026'],
      ['1022', 'Prenhe', '01/08/2026'],
      ['1021', 'Talvez', '01/08/2026'],
    ]);
    final rows = validateRows(schema: dgSchema, table: t,
        mapping: const {0: 'animal_number', 1: 'result', 2: 'exam_date'}, ctx: ctx);
    expect(rows[0].values['result'], 'pregnant');
    expect(rows[1].errors.single, 'Animal nº 1022 não está neste ATF');
    expect(rows[2].errors.single, contains('Resultado "Talvez" inválido'));
  });

  test('obrigatório vazio é erro', () {
    final t = SheetTable(headers: ['N', 'Cat', 'ECC', 'Lote'], rows: [['1030', '', '', 'Lote 03']]);
    final rows = validateRows(schema: animaisSchema, table: t, mapping: mapping, ctx: ctx);
    expect(rows.single.errors.single, 'Categoria é obrigatório');
  });
}
```

- [ ] **Step 2: Run → fail**

- [ ] **Step 3: Implement**

```dart
// lib/features/planilhas/domain/import_preview.dart
import '../data/sheet_codec.dart';
import 'header_matcher.dart';
import 'sheet_schema.dart';

enum ImportRowStatus { create, update, error }

class ImportRow {
  const ImportRow({required this.index, required this.values, required this.status, required this.errors});
  final int index;
  final Map<String, dynamic> values;
  final ImportRowStatus status;
  final List<String> errors;
}

class ImportContext {
  const ImportContext({
    this.existingAnimalNumbers = const {},
    this.lotNamesLower = const {},
    this.doseNamesLower = const {},
    this.atfAnimalNumbers = const {},
  });
  final Set<int> existingAnimalNumbers;
  final Set<String> lotNamesLower;
  final Set<String> doseNamesLower;
  final Set<int> atfAnimalNumbers;
}

final _excelEpoch = DateTime(1899, 12, 30);

Object? parseCell(SheetColumn col, String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  switch (col.type) {
    case SheetColumnType.text:
      return s;
    case SheetColumnType.integer:
      final v = int.tryParse(s.replaceAll('.', '').replaceAll(',', '.').split('.').first);
      if (v == null) throw FormatException('${col.label} deve ser número inteiro');
      return v;
    case SheetColumnType.decimal:
      final v = double.tryParse(s.replaceAll('.', '').replaceAll(',', '.')) ?? double.tryParse(s);
      if (v == null) throw FormatException('${col.label} deve ser número');
      return v;
    case SheetColumnType.date:
      final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(s);
      if (m != null) {
        final d = DateTime(int.parse(m.group(3)!), int.parse(m.group(2)!), int.parse(m.group(1)!));
        if (d.month != int.parse(m.group(2)!)) throw FormatException('${col.label}: data inválida');
        return d;
      }
      final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
      if (iso != null) {
        final d = DateTime(int.parse(iso.group(1)!), int.parse(iso.group(2)!), int.parse(iso.group(3)!));
        if (d.month != int.parse(iso.group(2)!)) throw FormatException('${col.label}: data inválida');
        return d;
      }
      final serial = int.tryParse(s);
      if (serial != null && serial > 20000 && serial < 80000) {
        return _excelEpoch.add(Duration(days: serial));
      }
      throw FormatException('${col.label}: use dd/MM/yyyy');
    case SheetColumnType.enumeration:
      final n = normalizeHeader(s);
      for (final e in col.enumValues.entries) {
        if (normalizeHeader(e.key) == n || normalizeHeader(e.value) == n) return e.key;
      }
      throw FormatException('${col.label} "$s" inválido · use ${col.enumValues.values.join(', ')}');
  }
}

List<ImportRow> validateRows({
  required SheetSchema schema,
  required SheetTable table,
  required Map<int, String> mapping,
  required ImportContext ctx,
}) {
  final out = <ImportRow>[];
  for (var r = 0; r < table.rows.length; r++) {
    final raw = table.rows[r];
    final values = <String, dynamic>{};
    final errors = <String>[];
    for (final e in mapping.entries) {
      final col = schema.byKey(e.value);
      if (col == null || e.key >= raw.length) continue;
      try {
        final v = parseCell(col, raw[e.key]);
        if (v != null) values[col.key] = v;
      } on FormatException catch (ex) {
        errors.add(ex.message);
      }
    }
    for (final c in schema.requiredColumns) {
      if (!values.containsKey(c.key) && !(schema.entity == SheetEntity.animais && c.key == 'lot_name' && _isExistingAnimal(values, ctx))) {
        if (!errors.any((m) => m.startsWith(c.label))) errors.add('${c.label} é obrigatório');
      }
    }
    var status = ImportRowStatus.create;
    switch (schema.entity) {
      case SheetEntity.animais:
        final ecc = values['body_condition'] as int?;
        if (ecc != null && (ecc < 1 || ecc > 5)) errors.add('ECC deve ser de 1 a 5');
        final lot = values['lot_name'] as String?;
        if (lot != null && !ctx.lotNamesLower.contains(lot.toLowerCase())) errors.add('Lote "$lot" não existe');
        if (_isExistingAnimal(values, ctx)) status = ImportRowStatus.update;
      case SheetEntity.doses:
        final d = values['dosage_per_kg'] as double?;
        if (d != null && d <= 0) errors.add('Dosagem deve ser maior que zero');
        final name = values['name'] as String?;
        if (name != null && ctx.doseNamesLower.contains(name.toLowerCase())) status = ImportRowStatus.update;
      case SheetEntity.sanitario:
        final n = values['animal_number'] as int?;
        if (n != null && !ctx.existingAnimalNumbers.contains(n)) errors.add('Animal nº $n não encontrado');
        final dose = values['dose_name'] as String?;
        if (dose != null && !ctx.doseNamesLower.contains(dose.toLowerCase())) errors.add('Dose "$dose" não existe');
      case SheetEntity.dg:
        final n = values['animal_number'] as int?;
        if (n != null && !ctx.atfAnimalNumbers.contains(n)) errors.add('Animal nº $n não está neste ATF');
    }
    if (errors.isNotEmpty) status = ImportRowStatus.error;
    out.add(ImportRow(index: r + 2, values: values, status: status, errors: errors));
  }
  return out;
}

bool _isExistingAnimal(Map<String, dynamic> values, ImportContext ctx) {
  final n = values['number'] as int?;
  return n != null && ctx.existingAnimalNumbers.contains(n);
}
```

Nota: o teste de categoria espera `Categoria "Bezerro" inválida` — o `parseCell` monta `'${col.label} "$s" inválido · use …'`; ajustar para `inválida` quando label termina em "a"? Não — simplificar: mensagem fixa `'${col.label} "$s" inválido'` e ajustar o teste para `contains('"Bezerro" inválid')`. Ajuste o teste ao implementar.

- [ ] **Step 4: Run → pass; commit**

```bash
git add lib/features/planilhas/domain/import_preview.dart test/features/planilhas/import_preview_test.dart
git commit -m "feat(planilhas): validação client-side do import (preview)"
```

---

### Task 5: ColumnMappingStore + BulkRepository + download

**Files:**
- Create: `lib/features/planilhas/data/column_mapping.dart`
- Create: `lib/features/planilhas/data/bulk_repository.dart`
- Create: `lib/features/planilhas/data/download_web.dart`
- Test: `test/features/planilhas/column_mapping_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class ColumnMappingStore { static String keyFor(SheetEntity e, List<String> headers); Future<Map<int,String>?> load(SheetEntity, List<String> headers); Future<void> save(SheetEntity, List<String> headers, Map<int,String> mapping); }
  class BulkRepository {
    Future<({int created, int updated})> upsertAnimals(String propertyId, List<Map<String,dynamic>> rows);
    Future<({int created, int updated})> upsertDoses(String propertyId, List<Map<String,dynamic>> rows);
    Future<({int applications, int animals})> registerSanitary(String propertyId, List<Map<String,dynamic>> rows);
  }
  final bulkRepositoryProvider = Provider<BulkRepository>(...);
  void downloadBytes(String fileName, Uint8List bytes); // web only
  ```
  Datas nas rows já serializadas pelo chamador com `yyyy-MM-dd`.

- [ ] **Step 1: Failing test (mapping store)**

```dart
// test/features/planilhas/column_mapping_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:campo_gestor/features/planilhas/data/column_mapping.dart';
import 'package:campo_gestor/features/planilhas/domain/sheet_schema.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('save/load por entidade + cabeçalhos', () async {
    final store = ColumnMappingStore();
    await store.save(SheetEntity.animais, ['Brinco', 'Categ.'], {0: 'number', 1: 'category'});
    expect(await store.load(SheetEntity.animais, ['Brinco', 'Categ.']), {0: 'number', 1: 'category'});
    expect(await store.load(SheetEntity.animais, ['Brinco', 'Cat']), isNull);
    expect(await store.load(SheetEntity.doses, ['Brinco', 'Categ.']), isNull);
  });
}
```

- [ ] **Step 2: Run → fail**

- [ ] **Step 3: Implement**

```dart
// lib/features/planilhas/data/column_mapping.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/header_matcher.dart';
import '../domain/sheet_schema.dart';

/// Persiste o mapeamento coluna-do-arquivo → campo por (entidade, cabeçalhos).
/// ponytail: shared_preferences local (por navegador); sincronizar no banco se virar pedido.
class ColumnMappingStore {
  static String keyFor(SheetEntity e, List<String> headers) {
    final sig = headers.map(normalizeHeader).join('|');
    return 'sheet_mapping.${e.name}.${sig.hashCode}';
  }

  Future<Map<int, String>?> load(SheetEntity e, List<String> headers) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keyFor(e, headers));
    if (raw == null) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return {for (final en in map.entries) int.parse(en.key): en.value as String};
  }

  Future<void> save(SheetEntity e, List<String> headers, Map<int, String> mapping) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyFor(e, headers), jsonEncode({for (final en in mapping.entries) '${en.key}': en.value}));
  }
}
```

```dart
// lib/features/planilhas/data/bulk_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/services/supabase_service.dart';

class BulkRepository {
  BulkRepository(this._service);
  final SupabaseService _service;

  Future<({int created, int updated})> upsertAnimals(String propertyId, List<Map<String, dynamic>> rows) async {
    final r = await _service.client.rpc('bulk_upsert_animals', params: {'p_property_id': propertyId, 'p_rows': rows}) as Map<String, dynamic>;
    return (created: r['created'] as int, updated: r['updated'] as int);
  }

  Future<({int created, int updated})> upsertDoses(String propertyId, List<Map<String, dynamic>> rows) async {
    final r = await _service.client.rpc('bulk_upsert_doses', params: {'p_property_id': propertyId, 'p_rows': rows}) as Map<String, dynamic>;
    return (created: r['created'] as int, updated: r['updated'] as int);
  }

  Future<({int applications, int animals})> registerSanitary(String propertyId, List<Map<String, dynamic>> rows) async {
    final r = await _service.client.rpc('bulk_register_sanitary', params: {'p_property_id': propertyId, 'p_rows': rows}) as Map<String, dynamic>;
    return (applications: r['applications'] as int, animals: r['animals'] as int);
  }
}

final bulkRepositoryProvider = Provider<BulkRepository>((ref) => BulkRepository(ref.watch(supabaseServiceProvider)));
```

```dart
// lib/features/planilhas/data/download_web.dart
import 'dart:typed_data';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Dispara download no navegador. Web-only (app é web-first); em outras
/// plataformas não faz nada — ponytail: adicionar path_provider+share se mobile pedir.
void downloadBytes(String fileName, Uint8List bytes) {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: 'application/octet-stream'));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()..href = url..download = fileName;
  web.document.body!.append(a);
  a.click();
  a.remove();
  web.URL.revokeObjectURL(url);
}
```
Se `flutter analyze` reclamar em alvos não-web, criar `download_stub.dart` (`void downloadBytes(...) {}`) e `download.dart` com `export 'download_stub.dart' if (dart.library.js_interop) 'download_web.dart';` — importar `download.dart` nos widgets.

- [ ] **Step 4: Run → pass; analyze; commit**

```bash
git add lib/features/planilhas/data test/features/planilhas/column_mapping_test.dart
git commit -m "feat(planilhas): ColumnMappingStore, BulkRepository e download web"
```

---

### Task 6: ExportButton + wire nas 4 telas

**Files:**
- Create: `lib/features/planilhas/presentation/export_button.dart`
- Modify: `lib/features/animais/presentation/animais_table_view.dart` (header actions, ~linha 186)
- Modify: `lib/features/sanitario/presentation/sanitario_screen.dart` (header das tabs Aplicações e Doses)
- Modify: `lib/features/reproducao/presentation/atf_detail_screen.dart` (AppBar actions)
- Test: `test/features/planilhas/export_button_test.dart`

**Interfaces:**
- Consumes: `encodeXlsx`, `downloadBytes`, `SheetSchema`.
- Produces: `ExportButton({required SheetSchema schema, required List<Map<String,Object?>> rows, required String fileStem, bool compact=false})`; helper `String exportFileName(String entity, String propertyName)` → `campo-gestor_<entity>_<slug>_<yyyyMMdd>.xlsx`; `List<List<Object?>> rowsForExport(SheetSchema, List<Map<String,Object?>>)` (ordem das colunas do schema, enum → label, DateTime mantido).

- [ ] **Step 1: Failing test**

```dart
// test/features/planilhas/export_button_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:campo_gestor/features/planilhas/presentation/export_button.dart';
import 'package:campo_gestor/features/planilhas/domain/sheet_schema.dart';

void main() {
  test('exportFileName', () {
    expect(exportFileName('animais', 'Fazenda Santa Rita', DateTime(2026, 8, 19)),
        'campo-gestor_animais_fazenda-santa-rita_20260819.xlsx');
  });
  test('rowsForExport ordena por schema e traduz enum', () {
    final rows = rowsForExport(animaisSchema, [
      {'number': 1, 'category': 'vaca', 'lot_name': 'L1', 'ua': 1.0, 'paddock_name': 'P'},
    ]);
    expect(rows.single, [1, 'Vaca', null, null, 'L1', null, 'P', 1.0]);
  });
}
```

- [ ] **Step 2: Run → fail**

- [ ] **Step 3: Implement**

```dart
// lib/features/planilhas/presentation/export_button.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/download.dart'; // ou download_web.dart se não houver stub
import '../data/sheet_codec.dart';
import '../domain/sheet_schema.dart';

String exportFileName(String entity, String propertyName, [DateTime? now]) {
  final slug = propertyName.toLowerCase()
      .replaceAll(RegExp(r'[áàâã]'), 'a').replaceAll(RegExp(r'[éê]'), 'e').replaceAll(RegExp(r'[íî]'), 'i')
      .replaceAll(RegExp(r'[óôõ]'), 'o').replaceAll(RegExp(r'[úû]'), 'u').replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
  return 'campo-gestor_${entity}_${slug}_${DateFormat('yyyyMMdd').format(now ?? DateTime.now())}.xlsx';
}

List<List<Object?>> rowsForExport(SheetSchema schema, List<Map<String, Object?>> rows) => [
      for (final r in rows)
        [
          for (final c in schema.columns)
            c.type == SheetColumnType.enumeration && r[c.key] != null
                ? (c.enumValues[r[c.key]] ?? r[c.key])
                : r[c.key],
        ],
    ];

class ExportButton extends StatelessWidget {
  const ExportButton({super.key, required this.schema, required this.rows, required this.fileName, this.compact = false});
  final SheetSchema schema;
  final List<Map<String, Object?>> rows;
  final String fileName;
  final bool compact;

  void _export(BuildContext context) {
    final bytes = encodeXlsx(
      sheetName: schema.sheetName,
      headers: schema.columns.map((c) => c.label).toList(),
      rows: rowsForExport(schema, rows),
    );
    downloadBytes(fileName, bytes);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${rows.length} linhas exportadas')));
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return IconButton(tooltip: 'Exportar .xlsx', icon: const Icon(Icons.download_outlined), onPressed: rows.isEmpty ? null : () => _export(context));
    }
    return OutlinedButton.icon(onPressed: rows.isEmpty ? null : () => _export(context), icon: const Icon(Icons.download_outlined, size: 20), label: const Text('Exportar'));
  }
}
```

- [ ] **Step 4: Wire — Animais**

Em `animais_table_view.dart`, no header Row antes do `if (canEdit)` do botão "Novo animal": adicionar
```dart
const SizedBox(width: 10),
ExportButton(
  schema: animaisSchema,
  fileName: exportFileName('animais', propertyName),
  rows: [
    for (final aw in filtered)
      {
        'number': aw.animal.number, 'category': aw.animal.category, 'breed': aw.animal.breed,
        'body_condition': aw.animal.bodyCondition, 'lot_name': aw.lotName,
        'observation': aw.animal.observation, 'paddock_name': aw.paddockName,
        'ua': kUaWeights[aw.animal.category],
      }
  ],
),
```
`AnimaisTableView` precisa de `propertyName` — passar de `AnimaisScreen` (`currentProperty?.name ?? ''`). Adicionar parâmetro `required String propertyName`.

- [ ] **Step 5: Wire — Sanitário (aplicações e doses) e DG**

`sanitario_screen.dart`: no header desktop de cada tab, ao lado do botão existente, `ExportButton(compact: !isDesktop, ...)`:
- Aplicações: `sanitarioSchema`, rows = para cada `SanitaryApplication` visível (após filtros) × cada entrada de `compositionSnapshot`: `{'animal_number': e.number, 'dose_name': app.doseName, 'applied_at': app.appliedAt, 'notes': app.notes, 'lot_name': app.lotName, 'category': e.category}`.
- Doses: `dosesSchema`, rows = `{'name','active_ingredient','dosage_per_kg','cost_per_kg'}`.

`atf_detail_screen.dart`: action no AppBar `ExportButton(compact: true, schema: dgSchema, ...)` com rows = último `DgRecord` por animal (memberships): `{'animal_number': m.animalNumber, 'result': rec?.result.dbValue, 'exam_date': rec?.examDate, 'observation': rec?.observation, 'category': m.animalCategory}`.

- [ ] **Step 6: Run tests + analyze; smoke manual (`flutter run -d chrome`, exportar animais abre .xlsx no Excel); commit**

```bash
git add lib/features/planilhas/presentation/export_button.dart test/features/planilhas/export_button_test.dart lib/features/animais lib/features/sanitario lib/features/reproducao
git commit -m "feat(planilhas): exportar .xlsx em animais, sanitário, doses e DG"
```

---

### Task 7: ImportFlowScreen (3 passos) + rota + botões Importar

**Files:**
- Create: `lib/features/planilhas/presentation/import_flow_screen.dart`
- Modify: `lib/core/router/routes.dart` (add `static const importar = '/planilhas/importar/:entity'; static String importarFor(SheetEntity e, {String? atfId}) => '/planilhas/importar/${e.name}${atfId == null ? '' : '?atf=$atfId'}';`)
- Modify: `lib/core/router/router.dart` (GoRoute top-level, fora do shell, ao lado de `aplicacaoById`)
- Modify: `animais_table_view.dart`, `sanitario_screen.dart`, `atf_detail_screen.dart` — botão "Importar" (só `canEdit`) → `context.push(AppRoutes.importarFor(...))`
- Test: `test/features/planilhas/import_flow_screen_test.dart` (widget: passo 2 bloqueia sem obrigatórios; passo 3 conta status)

**Interfaces:**
- Consumes: `decodeSheet`, `autoMatch`, `validateRows`, `ColumnMappingStore`, `BulkRepository`, `atfRepository.saveDgRecords`, providers `animalListByPropertyProvider`, `loteListByPropertyProvider`, `doseListByPropertyProvider`, `atfMembershipsProvider(atfId)`.
- Produces: `ImportFlowScreen({required SheetEntity entity, String? atfId})`.

- [ ] **Step 1: Widget test (red)**

```dart
// test/features/planilhas/import_flow_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campo_gestor/features/planilhas/data/sheet_codec.dart';
import 'package:campo_gestor/features/planilhas/domain/sheet_schema.dart';
import 'package:campo_gestor/features/planilhas/presentation/import_flow_screen.dart';

void main() {
  testWidgets('passo mapear bloqueia Revisar sem obrigatórios', (tester) async {
    await tester.pumpWidget(MaterialApp(home: MappingStep(
      schema: animaisSchema,
      table: const SheetTable(headers: ['Brinco', 'Peso'], rows: [['1', '400']]),
      initial: const {0: 'number'},
      onBack: () {}, onNext: (_, __) {},
    )));
    final btn = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Revisar'));
    expect(btn.onPressed, isNull);
    expect(find.textContaining('Categoria'), findsWidgets);
  });
}
```
(`MappingStep` é widget público dentro de `import_flow_screen.dart` para ser testável isolado.)

- [ ] **Step 2: Run → fail**

- [ ] **Step 3: Implement screen**

Estrutura (um arquivo, ~450 linhas; widgets públicos `FileStep`, `MappingStep`, `ReviewStep`, privado `_Stepper`):

```dart
class ImportFlowScreen extends ConsumerStatefulWidget {
  const ImportFlowScreen({super.key, required this.entity, this.atfId});
  final SheetEntity entity; final String? atfId;
  ...
}
class _ImportFlowScreenState extends ConsumerState<ImportFlowScreen> {
  int _step = 0;
  String? _fileName; SheetTable? _table; Map<int, String> _mapping = {}; List<ImportRow> _rows = [];
  bool _remember = true; bool _saving = false; String? _serverError;

  SheetSchema get schema => schemaFor(widget.entity);

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx', 'csv'], withData: true);
    final f = res?.files.single; if (f == null || f.bytes == null) return;
    try {
      final t = decodeSheet(f.name, f.bytes!);
      if (t.headers.isEmpty) throw const FormatException('Planilha vazia ou sem cabeçalho na linha 1');
      if (t.rows.length > 5000) throw FormatException('Planilha com ${t.rows.length} linhas — limite 5.000');
      final saved = await ColumnMappingStore().load(widget.entity, t.headers);
      setState(() { _fileName = f.name; _table = t; _mapping = saved ?? autoMatch(t.headers, schema); _step = 1; });
      if (saved != null && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mapeamento reaproveitado')));
    } on FormatException catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message))); }
  }

  void _downloadTemplate() {
    final bytes = encodeXlsx(sheetName: schema.sheetName, headers: schema.importHeaders, rows: schema.templateRows());
    downloadBytes('modelo_${schema.sheetName.toLowerCase()}.xlsx', bytes);
  }

  ImportContext _buildContext() {
    final animals = ref.read(animalListByPropertyProvider).asData?.value ?? const [];
    final lots = ref.read(loteListByPropertyProvider).asData?.value ?? const [];
    final doses = ref.read(doseListByPropertyProvider).asData?.value ?? const [];
    final members = widget.atfId == null ? const <AtfMembershipView>[] : (ref.read(atfMembershipsProvider(widget.atfId!)).asData?.value ?? const []);
    return ImportContext(
      existingAnimalNumbers: {for (final a in animals) if (a.animal.deletedAt == null) a.animal.number},
      lotNamesLower: {for (final l in lots) l.name.toLowerCase()},
      doseNamesLower: {for (final d in doses) d.name.toLowerCase()},
      atfAnimalNumbers: {for (final m in members) if (!m.animalDeleted) m.animalNumber},
    );
  }

  Future<void> _goReview(Map<int, String> mapping, bool remember) async {
    if (remember) await ColumnMappingStore().save(widget.entity, _table!.headers, mapping);
    setState(() { _mapping = mapping; _rows = validateRows(schema: schema, table: _table!, mapping: mapping, ctx: _buildContext()); _step = 2; });
  }

  Future<void> _commit() async {
    final property = ref.read(currentPropertyProvider).asData?.value; if (property == null) return;
    final valid = _rows.where((r) => r.status != ImportRowStatus.error).toList();
    setState(() { _saving = true; _serverError = null; });
    try {
      final fmt = DateFormat('yyyy-MM-dd');
      Map<String, dynamic> ser(ImportRow r) => {for (final e in r.values.entries) e.key: e.value is DateTime ? fmt.format(e.value as DateTime) : e.value};
      String msg;
      switch (widget.entity) {
        case SheetEntity.animais:
          final res = await ref.read(bulkRepositoryProvider).upsertAnimals(property.id, valid.map(ser).toList());
          msg = '${res.created} animais criados · ${res.updated} atualizados';
        case SheetEntity.doses:
          final res = await ref.read(bulkRepositoryProvider).upsertDoses(property.id, valid.map(ser).toList());
          msg = '${res.created} doses criadas · ${res.updated} atualizadas';
        case SheetEntity.sanitario:
          final res = await ref.read(bulkRepositoryProvider).registerSanitary(property.id, valid.map(ser).toList());
          msg = '${res.applications} aplicações registradas · ${res.animals} animais';
        case SheetEntity.dg:
          final members = ref.read(atfMembershipsProvider(widget.atfId!)).asData!.value;
          final byNumber = {for (final m in members) m.animalNumber: m.animalId};
          await ref.read(atfRepositoryProvider).saveDgRecords(atfBatchId: widget.atfId!, records: [
            for (final r in valid) {
              'animal_id': byNumber[r.values['animal_number']], 'result': r.values['result'],
              'exam_date': fmt.format(r.values['exam_date'] as DateTime),
              if (r.values['observation'] != null) 'observation': r.values['observation'],
            }
          ]);
          msg = '${valid.length} diagnósticos lançados';
      }
      ref.invalidatePropertyData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      context.pop();
    } on PostgrestException catch (e) {
      setState(() => _serverError = e.message);
    } catch (e) {
      setState(() => _serverError = 'Falha ao importar. Tente novamente.');
    } finally { if (mounted) setState(() => _saving = false); }
  }
  ...
}
```
**Atenção:** `PostgrestException` não pode ser importado no widget (constraint). Em vez disso, `BulkRepository` e `AtfRepository` devem mapear: envolver as chamadas rpc num `try/on PostgrestException catch (e) { throw BulkImportException(e.message); }` dentro de `bulk_repository.dart` (criar `class BulkImportException implements Exception { final String message; }`), e o widget captura `BulkImportException`. Para `saveDgRecords`, envolver a chamada no widget com `catch (e)` genérico mostrando `e.toString()` sanitizado — ou adicionar o mesmo wrapper no `AtfRepository.saveDgRecords` (preferível, 3 linhas).

UI por passo (seguir mockup; só `AppColors`):
- `_Stepper(current)`: 3 círculos 26px (feito = `primary` + check, atual = `accent` número, futuro = borda `outlineBorder`) ligados por linha 48×1 `chipBorder`.
- `FileStep`: `DropTarget` não — só botão `Escolher arquivo` (OutlinedButton.icon upload) dentro de container tracejado (`DottedBorder` não existe → `Container` com `border: Border.all(color: AppColors.primary.withValues(alpha:.35))` + `borderRadius 16` + `surfaceSubtle`); card lateral com título da entidade, link "Baixar modelo", texto "Como funciona" conforme entidade. Rodapé: Cancelar (pop) / Continuar desabilitado.
- `MappingStep(schema, table, initial, onBack, onNext(mapping, remember))`: `StatefulWidget`; linha por header: nome mono bold, amostra = 3 primeiros valores não-vazios `·`, `DropdownButtonFormField<String?>` com itens `null → 'Ignorar coluna'` + `importColumns` (label + ' *' se required), desabilitando keys já usadas em outra linha; chip "automático" verde quando `initial` veio do autoMatch (passar `autoKeys` set). Topo: chips vermelhos dos obrigatórios faltando. Checkbox "Lembrar este mapeamento". Botão `Revisar` `FilledButton` — `onPressed: missing.isEmpty ? ... : null`.
- `ReviewStep(schema, rows, onBack, onCommit, saving, serverError)`: chips contagem (create `positiveChipBg`, update `neutralChipBg`, error `dangerChipBg`), switch "Mostrar só erros", lista `ListView.builder` com `Container` borda esquerda 3px (create `primary`, update `greenMid`, error `danger`), fundo erro `dangerContainer`; colunas = `schema.importColumns` que estão no mapping (+ col. "#" e "Resultado" com chip + mensagem). Rodapé: texto explicativo, Voltar, `FilledButton('Importar N válidas')` desabilitado se N==0 ou saving; `_serverError` em `WarningBanner`.

- [ ] **Step 4: Rotas + botões**

`routes.dart`:
```dart
static const importar = '/planilhas/importar/:entity';
static String importarFor(String entity, {String? atfId}) => '/planilhas/importar/$entity${atfId == null ? '' : '?atf=$atfId'}';
static const sanitarioGrade = '/sanitario/grade';
```
`router.dart` (top-level, junto de `aplicacaoById`):
```dart
GoRoute(
  path: AppRoutes.importar,
  builder: (ctx, state) => ImportFlowScreen(
    entity: SheetEntity.values.byName(state.pathParameters['entity']!),
    atfId: state.uri.queryParameters['atf'],
  ),
),
```
Botões "Importar" (`OutlinedButton.icon(Icons.upload_outlined)`, só `canEdit`): animais header (`context.push(AppRoutes.importarFor('animais'))`), sanitário tab Aplicações (`'sanitario'`) e Doses (`'doses'`), ATF detail AppBar (`IconButton` upload → `'dg'`, `atfId: atf.id`).

- [ ] **Step 5: Tests + analyze + smoke manual (importar modelo baixado com 2 linhas editadas) ; commit**

```bash
git add lib/features/planilhas/presentation/import_flow_screen.dart lib/core/router lib/features/animais lib/features/sanitario lib/features/reproducao lib/features/planilhas/data test/features/planilhas/import_flow_screen_test.dart
git commit -m "feat(planilhas): fluxo de importação em 3 passos (arquivo, mapear, revisar)"
```

---

### Task 8: EditableGrid genérico

**Files:**
- Create: `lib/features/planilhas/presentation/editable_grid.dart`
- Test: `test/features/planilhas/editable_grid_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class GridColumn { final String key, label; final double width; final SheetColumnType type; final Map<String,String>? options /*dropdown key→label*/; final bool editable; final bool mono; final TextAlign align; }
  class GridRow { final String id; final Map<String, Object?> values; final bool isNew; }
  class GridChange { final String rowId; final Map<String, Object?> values; /* só keys alteradas */ }
  typedef GridValidator = String? Function(String key, Object? value, Map<String, Object?> row);
  class EditableGrid extends StatefulWidget {
    EditableGrid({required List<GridColumn> columns, required List<GridRow> rows, required Future<void> Function(List<GridChange>) onSave,
                  GridValidator? validator, bool readOnly=false, Widget? footer, VoidCallback? onAddRow, String saveLabel='Salvar alterações'});
  }
  List<List<String>> parseClipboardTsv(String text);
  ```
- Estado interno: `Map<rowId, Map<key, Object?>> _edits`, `(rowIdx, colIdx)? _focus`, `Map<(rowId,key), String> _errors`. Dirty = `_edits` não vazio. Barra inferior `Container(color: AppColors.ink)` com contagem, erro, Descartar, Salvar (`FilledButton` laranja `accent`/`onAccent`, desabilitado com erro ou saving).
- Teclado: `Focus` + `CallbackShortcuts` na célula em edição: Tab → próxima editável (Shift+Tab anterior), Enter → mesma col linha abaixo, Esc → cancela. `Ctrl+V` no grid (fora de edição): lê `Clipboard.getData('text/plain')`, `parseClipboardTsv`, aplica a partir de `_focus` (respeitando `options`: aceita label ou key; senão erro na célula).
- Tipos: text/int/decimal → `TextField` inline (`autofocus`) committed on blur/Enter; enumeration/options → `DropdownButton` inline; date → `TextField` dd/MM/yyyy.
- `PopScope(canPop: !dirty)` + diálogo "Descartar alterações?".

- [ ] **Step 1: Tests (red)**

```dart
// test/features/planilhas/editable_grid_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campo_gestor/features/planilhas/domain/sheet_schema.dart';
import 'package:campo_gestor/features/planilhas/presentation/editable_grid.dart';

void main() {
  test('parseClipboardTsv', () {
    expect(parseClipboardTsv('a\tb\r\nc\td\n'), [['a', 'b'], ['c', 'd']]);
  });

  testWidgets('editar célula marca dirty e Salvar envia só mudanças', (tester) async {
    List<GridChange>? saved;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: EditableGrid(
      columns: const [
        GridColumn(key: 'number', label: 'Nº', width: 80, editable: false),
        GridColumn(key: 'breed', label: 'Raça', width: 160),
      ],
      rows: const [
        GridRow(id: 'a', values: {'number': 1, 'breed': 'Nelore'}),
        GridRow(id: 'b', values: {'number': 2, 'breed': 'Angus'}),
      ],
      onSave: (c) async => saved = c,
    ))));
    expect(find.text('Salvar alterações'), findsNothing); // barra só aparece dirty
    await tester.tap(find.text('Angus'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Brangus');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.textContaining('1 célula'), findsOneWidget);
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();
    expect(saved!.single.rowId, 'b');
    expect(saved!.single.values, {'breed': 'Brangus'});
  });

  testWidgets('validator bloqueia Salvar', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: EditableGrid(
      columns: const [GridColumn(key: 'ecc', label: 'ECC', width: 80, type: SheetColumnType.integer)],
      rows: const [GridRow(id: 'a', values: {'ecc': 3})],
      validator: (k, v, _) => k == 'ecc' && v is int && (v < 1 || v > 5) ? 'ECC deve ser de 1 a 5' : null,
      onSave: (_) async {},
    ))));
    await tester.tap(find.text('3'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '9');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    final btn = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Salvar alterações'));
    expect(btn.onPressed, isNull);
    expect(find.text('ECC deve ser de 1 a 5'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run → fail**

- [ ] **Step 3: Implement** (~400 linhas). Esqueleto:

```dart
class EditableGrid extends StatefulWidget { ... }
class _EditableGridState extends State<EditableGrid> {
  final _edits = <String, Map<String, Object?>>{};
  final _errors = <String, String>{}; // '$rowId|$key'
  (int, int)? _editing; // row, col
  bool _saving = false;
  final _gridFocus = FocusNode();

  Object? _value(GridRow r, String k) => _edits[r.id]?.containsKey(k) == true ? _edits[r.id]![k] : r.values[k];
  int get _dirtyCells => _edits.values.fold(0, (n, m) => n + m.length);

  void _set(GridRow r, GridColumn c, Object? v) {
    setState(() {
      final original = r.values[c.key];
      final m = _edits.putIfAbsent(r.id, () => {});
      if (v == original || (v == null && original == null)) { m.remove(c.key); if (m.isEmpty) _edits.remove(r.id); }
      else { m[c.key] = v; }
      final err = widget.validator?.call(c.key, v, {...r.values, ...?_edits[r.id]});
      if (err == null) _errors.remove('${r.id}|${c.key}'); else _errors['${r.id}|${c.key}'] = err;
    });
  }

  Object? _coerce(GridColumn c, String text) { /* int/decimal/date/enum(label→key)/text; lança FormatException → _errors */ }
  void _moveFocus(int dRow, int dCol) { /* próxima célula editável; setState(_editing) */ }
  Future<void> _paste() async { /* Clipboard.getData → parseClipboardTsv → aplica de _editing */ }
  Future<void> _save() async { setState(()=>_saving=true); try { await widget.onSave([for (final e in _edits.entries) GridChange(rowId: e.key, values: Map.of(e.value))]); setState(_edits.clear); } finally { setState(()=>_saving=false); } }
  void _discard() => setState(() { _edits.clear(); _errors.clear(); _editing = null; });

  @override Widget build(BuildContext context) {
    final dirty = _edits.isNotEmpty;
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) async { if (didPop) return; final ok = await _confirmDiscard(context); if (ok && context.mounted) { _discard(); Navigator.of(context).pop(); } },
      child: CallbackShortcuts(
        bindings: { const SingleActivator(LogicalKeyboardKey.keyV, control: true): _paste },
        child: Focus(focusNode: _gridFocus, child: Column(children: [
          _Header(columns: widget.columns),
          Expanded(child: ListView.builder(itemCount: widget.rows.length, itemBuilder: (_, i) => _row(i))),
          ?widget.footer,
          if (dirty) _SaveBar(dirtyCells: _dirtyCells, rows: _edits.length, error: _errors.values.firstOrNull,
              canSave: _errors.isEmpty && !_saving, saving: _saving, onDiscard: _discard, onSave: _save, saveLabel: widget.saveLabel),
        ])),
      ),
    );
  }
}
```
Célula: `Container(height: 44, padding: 0 10, decoration: BoxDecoration(color: dirty ? AppColors.accentContainer : null, border: Border(bottom: divider, right: divider) + (erro ? Border.all(danger, 2) : focado ? Border.all(primary, 2) : none)))`. Em edição: `TextField(autofocus, decoration: InputDecoration.collapsed, textInputAction: TextInputAction.done, onSubmitted: commit+moveFocus(1,0))` envolto em `CallbackShortcuts` para Tab/Shift+Tab/Esc; `Focus(onFocusChange: lost → commit)`.
`_SaveBar`: `Container(height: 64, color: AppColors.ink)` — textos `onGreen`; Descartar `OutlinedButton` com borda `glassStrong`; Salvar `FilledButton(style: backgroundColor accent, foregroundColor onAccent)`.
Deixar `// ponytail:` onde simplificou (ex.: sem virtualização horizontal).

- [ ] **Step 4: Tests pass + analyze; commit**

```bash
git add lib/features/planilhas/presentation/editable_grid.dart test/features/planilhas/editable_grid_test.dart
git commit -m "feat(planilhas): EditableGrid genérico com dirty-tracking, teclado e colar do Excel"
```

---

### Task 9: Grade de Animais (toggle lista/grade)

**Files:**
- Create: `lib/features/planilhas/presentation/animais_grid_view.dart`
- Modify: `lib/features/animais/presentation/animais_screen.dart` (estado `_gridMode`, passa para table view; renderiza `AnimaisGridView` no lugar de `AnimaisTableView` + painel quando ativo)
- Modify: `lib/features/animais/presentation/animais_table_view.dart` (toggle `SegmentedButton<bool>` lista/grade no header; só `isDesktop && canEdit`)
- Test: `test/features/planilhas/animais_grid_view_test.dart`

**Interfaces:**
- Consumes: `EditableGrid`, `GridColumn`, `GridRow`, `GridChange`, `bulkRepositoryProvider.upsertAnimals`, `loteListByPropertyProvider`, `kCategoryLabels`.
- Produces: `AnimaisGridView({required List<AnimalWithContext> animals, required List<Lot> lots, required String propertyId, required VoidCallback onExit})`; função pura `List<Map<String,dynamic>> animalChangesToRows(List<GridChange> changes, List<AnimalWithContext> animals, List<Lot> lots)` → linhas no shape do RPC (sempre inclui `number` e `category`; `lot_name` resolvido de `lot_id` escolhido).

- [ ] **Step 1: Test (red)** — `animalChangesToRows` converte `{'breed':'X'}` da linha id=A em `{'number': 1021, 'category': 'vaca', 'breed': 'X'}` e `{'lot_id': L2}` em `{'number':..,'category':..,'lot_name':'Lote 02'}`.

- [ ] **Step 2: Run → fail**

- [ ] **Step 3: Implement**

Colunas: `number` (width 96, editable false, mono), `category` (150, options kCategoryLabels), `breed` (170), `body_condition` (90, integer, mono), `lot_id` (160, options `{lot.id: lot.name}`), `observation` (flex → width 320). Validator: ECC 1–5. Header da grade (acima): reusar barra-dica "Ctrl+V cola células copiadas do Excel · Tab/Enter avançam · Esc cancela" (`surfaceVariant` pill, `textSecondary`). `onSave` → `upsertAnimals(propertyId, animalChangesToRows(...))` → `ref.invalidatePropertyData()` → SnackBar `"N animais atualizados"`; em erro `BulkImportException` → SnackBar com `message` (contém "linha N: …" — mapear N para nº do animal: `changes[N-1]` → `'#${number}: motivo'`).

Em `animais_screen.dart`: `bool _gridMode = false;` passado a `AnimaisTableView(gridMode:, onGridModeChanged:)`; no branch desktop, `if (_gridMode) Expanded(child: AnimaisGridView(animals: filtered, lots: allLots, propertyId: currentProperty!.id, onExit: () => setState(() => _gridMode = false))) else ...` (mantém header com filtros em ambos modos → mover o header da `AnimaisTableView` p/ widget compartilhado `AnimaisHeaderBar` se necessário; alternativa mais simples: `AnimaisTableView` ganha parâmetro `Widget? body` que substitui a tabela quando grade ativa — escolher esta, menor diff).

- [ ] **Step 4: Tests + analyze + smoke (editar 3 células, salvar, conferir no banco); commit**

```bash
git add lib/features/planilhas/presentation/animais_grid_view.dart lib/features/animais test/features/planilhas/animais_grid_view_test.dart
git commit -m "feat(planilhas): edição em grade de animais com salvamento em lote"
```

---

### Task 10: Grade de Doses

**Files:**
- Create: `lib/features/planilhas/presentation/doses_grid_view.dart`
- Modify: `lib/features/sanitario/presentation/sanitario_screen.dart` (tab Doses: toggle lista/grade desktop+canEdit; `_buildDosesTab` renderiza `DosesGridView` quando ativo)

**Interfaces:**
- Consumes: `EditableGrid`, `bulkRepositoryProvider.upsertDoses`, `doseListByPropertyProvider`.
- Produces: `DosesGridView({required List<Dose> doses, required String propertyId})`; `List<Map<String,dynamic>> doseChangesToRows(List<GridChange>, List<Dose>, List<GridRow> newRows)`.

- [ ] **Step 1: Test** `doseChangesToRows` — mudança em dose existente gera `{'name': doseName, ...campos alterados}`; linha nova (`isNew`) gera todos os campos.
- [ ] **Step 2: Run → fail**
- [ ] **Step 3: Implement** — colunas `name`(220, required), `active_ingredient`(200), `dosage_per_kg`(140, decimal, mono), `cost_per_kg`(140, decimal, mono). `onAddRow` → adiciona `GridRow(id: 'new-$n', isNew: true, values: {})` em estado local; validator: `name` vazio em linha nova → erro; `dosage_per_kg` ≤ 0 → erro. `onSave` → `upsertDoses` → invalidate → SnackBar.
- [ ] **Step 4: Tests + analyze + smoke; commit**

```bash
git add lib/features/planilhas/presentation/doses_grid_view.dart lib/features/sanitario/presentation/sanitario_screen.dart test/features/planilhas/doses_grid_view_test.dart
git commit -m "feat(planilhas): edição em grade do catálogo de doses"
```

---

### Task 11: Sanitário — grade multi-dose

**Files:**
- Create: `lib/features/planilhas/presentation/sanitario_grade_screen.dart`
- Modify: `lib/core/router/router.dart` (GoRoute `AppRoutes.sanitarioGrade` top-level), `sanitario_screen.dart` (botão "Grade" `OutlinedButton.icon(Icons.grid_on)` no header da tab Aplicações, desktop+canEdit → `context.push(AppRoutes.sanitarioGrade)`)
- Test: `test/features/planilhas/sanitario_grade_test.dart`

**Interfaces:**
- Consumes: `loteListByPropertyProvider`, `animalListByLotProvider(lotId)`, `doseListByPropertyProvider`, `resolveActiveKgPerUa(ref)`, `totalUaForCategories`, `totalVolumeMl`, `totalCost`, `formatUa`, `sanitaryApplicationRepositoryProvider.findRecentIdenticalApplication`, `bulkRepositoryProvider.registerSanitary`.
- Produces: `SanitarioGradeScreen()`; função pura `List<Map<String,dynamic>> gradeToRows({required Map<String /*doseId*/, Set<String /*animalId*/>> marks, required List<Animal> animals, required List<Dose> doses, required DateTime date})` → `[{animal_number, dose_name, applied_at:'yyyy-MM-dd'}]`.

- [ ] **Step 1: Test** `gradeToRows` — 2 doses × 3 animais marcados parcialmente → linhas corretas; data formatada.
- [ ] **Step 2: Run → fail**
- [ ] **Step 3: Implement**

Tela `Scaffold` com `CampoAppBar(title: 'Sanitário', subtitle: 'aplicação em grade')`; header: título "Aplicação em grade" + sub mono; `DropdownButtonFormField<Lot>` Lote; campo Data (`TextFormField` dd/MM/yyyy default hoje, `showDatePicker` no ícone); botão "Adicionar dose" → `showModalBottomSheet`/menu com `doseListByPropertyProvider` menos já adicionadas. Estado: `String? _lotId; DateTime _date; List<Dose> _doses; Map<String, Set<String>> _marks; Map<String,Set<String>> _initial = {}`. Grid custom simples (não `EditableGrid` — checkbox tem semântica própria, ponytail): `Column` com header (Nº | Categoria | UA | doses…), linha "marcar todos" por coluna (`Checkbox(tristate)`), `ListView` de animais, rodapé `statsStrip` com totais por dose (`n animais · ml · R$`), `_SaveBar` reutilizada (exportar de `editable_grid.dart` como widget público `GridSaveBar`) com texto "K aplicações serão registradas · D doses em A animais", botão "Registrar aplicações".
`onSave`: para cada dose com marcação, `findRecentIdenticalApplication(lotId, doseId, date)`; se alguma duplicada → diálogo "Já existe aplicação de X neste lote nesta data. Registrar mesmo assim?" (reusa o texto do `_DuplicateConfirmDialog` atual); depois `registerSanitary(propertyId, gradeToRows(...))` → invalidate → SnackBar "K aplicações registradas" → `context.pop()`.

- [ ] **Step 4: Rota + botão; tests + analyze + smoke; commit**

```bash
git add lib/features/planilhas/presentation/sanitario_grade_screen.dart lib/core/router lib/features/sanitario test/features/planilhas/sanitario_grade_test.dart
git commit -m "feat(planilhas): aplicação sanitária em grade multi-dose"
```

---

### Task 12: Fechamento — docs, graphify, PROD

**Files:**
- Modify: `.planning/STATE.md` (ou o que `/gsd-quick` gerar), `CLAUDE.md` seção Conventions (1 linha: "Planilhas: `SheetSchema` é fonte única de colunas; import/export/grade leem dele").

- [ ] **Step 1:** `flutter test` completo → tudo verde; `flutter analyze` limpo.
- [ ] **Step 2:** `graphify update .`
- [ ] **Step 3:** Perguntar ao usuário antes de `supabase db push` (PROD). Após push, rodar `supabase test db` contra dev e registrar em STATE.
- [ ] **Step 4:** Commit docs:
```bash
git add CLAUDE.md .planning
git commit -m "docs(planilhas): convenção SheetSchema + estado"
```

---

## Self-review

**Spec coverage:** export 4 entidades (T6); import 3 passos + mapeamento salvo + modelo + limite 5k (T7); validação client (T4) + server (T1); grade animais (T9), doses (T10), multi-dose (T11), DG mantém existente + import (T7); permissões via RLS/guardas (T1) + `canEdit` na UI; export-only cols (T3/T6); erros com linha (T1/T7); testes unit/widget/pgTAP (T1,2,3,4,5,7,8). Sem gaps.

**Placeholders:** nenhum "TBD"; T7/T8/T9/T11 têm esqueletos com trechos "…" em código de UI — intencional (layout detalhado no mockup), mas toda função/estado/nome está definido.

**Type consistency:** `GridChange{rowId, values}`, `GridRow{id, values, isNew}`, `GridColumn{key,label,width,type,options,editable,mono}` usados igual em T8–T11; `ImportRow.values` keys = `SheetColumn.key`; RPC row shapes idênticos em T1/T5/T7/T9/T10/T11; `BulkImportException` definido em T5 (adicionar no código de T5 ao executar — classe `class BulkImportException implements Exception { const BulkImportException(this.message); final String message; }` e wrap das 3 chamadas rpc em `on PostgrestException catch (e) => throw BulkImportException(e.message)`).
