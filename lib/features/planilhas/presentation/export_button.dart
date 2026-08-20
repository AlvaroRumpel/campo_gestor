// Botão "Exportar .xlsx" — gera a planilha da entidade com as linhas
// visíveis (filtros da tela aplicados) e dispara o download.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/download.dart';
import '../data/sheet_codec.dart';
import '../domain/header_matcher.dart';
import '../domain/sheet_schema.dart';

String exportFileName(String entity, String propertyName, [DateTime? now]) {
  final slug = normalizeHeader(propertyName).replaceAll(' ', '-');
  return 'campo-gestor_${entity}_${slug}_'
      '${DateFormat('yyyyMMdd').format(now ?? DateTime.now())}.xlsx';
}

/// Linhas na ordem das colunas do schema; enums viram label pt-BR;
/// DateTime passa direto (vira data real no xlsx).
List<List<Object?>> rowsForExport(
  SheetSchema schema,
  List<Map<String, Object?>> rows,
) =>
    [
      for (final r in rows)
        [
          for (final c in schema.columns)
            c.type == SheetColumnType.enumeration && r[c.key] != null
                ? (c.enumValues[r[c.key]] ?? r[c.key])
                : r[c.key],
        ],
    ];

class ExportButton extends StatelessWidget {
  const ExportButton({
    super.key,
    required this.schema,
    required this.rows,
    required this.fileName,
    this.compact = false,
    this.iconColor,
  });

  final SheetSchema schema;
  final List<Map<String, Object?>> rows;
  final String fileName;

  /// true = só ícone (AppBar/mobile); false = OutlinedButton com label.
  final bool compact;

  /// Cor do ícone no modo compacto (ex.: onGreen em AppBar verde).
  final Color? iconColor;

  void _export(BuildContext context) {
    final bytes = encodeXlsx(
      sheetName: schema.sheetName,
      headers: schema.columns.map((c) => c.label).toList(),
      rows: rowsForExport(schema, rows),
    );
    downloadBytes(fileName, bytes);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${rows.length} linhas exportadas')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return IconButton(
        tooltip: 'Exportar .xlsx',
        icon: Icon(Icons.download_outlined, color: iconColor),
        onPressed: rows.isEmpty ? null : () => _export(context),
      );
    }
    return OutlinedButton.icon(
      onPressed: rows.isEmpty ? null : () => _export(context),
      icon: const Icon(Icons.download_outlined, size: 20),
      label: const Text('Exportar'),
    );
  }
}
