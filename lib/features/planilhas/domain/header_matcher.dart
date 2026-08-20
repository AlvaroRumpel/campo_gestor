// Normalização de cabeçalhos e auto-match contra o SheetSchema — o coração
// do "aceita planilha de qualquer software": comparação sem acento, caixa
// ou pontuação, com aliases por coluna.
import 'sheet_schema.dart';

const _accents = 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
const _plain = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';

String normalizeHeader(String h) {
  final sb = StringBuffer();
  for (final rune in h.runes) {
    final ch = String.fromCharCode(rune);
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

/// Índice da coluna do arquivo → key do schema. Cada key é usada no máximo
/// uma vez (primeira coluna que casar vence).
Map<int, String> autoMatch(List<String> headers, SheetSchema schema) {
  final result = <int, String>{};
  final used = <String>{};
  for (var i = 0; i < headers.length; i++) {
    final h = normalizeHeader(headers[i]);
    if (h.isEmpty) continue;
    for (final c in schema.importColumns) {
      if (used.contains(c.key)) continue;
      final candidates = {
        normalizeHeader(c.label),
        normalizeHeader(c.key.replaceAll('_', ' ')),
        ...c.aliases.map(normalizeHeader),
      };
      if (candidates.contains(h)) {
        result[i] = c.key;
        used.add(c.key);
        break;
      }
    }
  }
  return result;
}
