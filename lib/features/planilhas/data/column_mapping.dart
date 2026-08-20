// Persiste o mapeamento coluna-do-arquivo → campo por (entidade, cabeçalhos):
// reimportar planilha com o mesmo layout pula o passo de mapear.
// ponytail: shared_preferences local (por navegador); sincronizar no banco só
// se virar pedido.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/header_matcher.dart';
import '../domain/sheet_schema.dart';

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
    return {
      for (final en in map.entries) int.parse(en.key): en.value as String,
    };
  }

  Future<void> save(
    SheetEntity e,
    List<String> headers,
    Map<int, String> mapping,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      keyFor(e, headers),
      jsonEncode({for (final en in mapping.entries) '${en.key}': en.value}),
    );
  }
}
