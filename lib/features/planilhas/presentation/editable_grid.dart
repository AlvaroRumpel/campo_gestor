// Grade editável genérica: dirty-tracking por célula, 1 botão Salvar que
// envia só as linhas alteradas, navegação por teclado (Tab/Enter/Esc) e
// colagem de bloco TSV do Excel (Ctrl+V).
//
// ponytail: sem virtualização horizontal nem seleção múltipla de células —
// adicionar se as grades passarem de ~10 colunas.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/header_matcher.dart';
import '../domain/sheet_schema.dart';

class GridColumn {
  const GridColumn({
    required this.key,
    required this.label,
    required this.width,
    this.type = SheetColumnType.text,
    this.options,
    this.editable = true,
    this.mono = false,
    this.flex = false,
    this.suggestions,
  });

  final String key;
  final String label;
  final double width;
  final SheetColumnType type;

  /// Quando presente, célula vira dropdown (valor interno → label pt-BR).
  final Map<String, String>? options;
  final bool editable;
  final bool mono;

  /// true = ocupa o espaço restante (uma por grade, tipicamente observação).
  final bool flex;

  /// Sugestões para coluna de texto (search-select): em edição a célula
  /// vira autocomplete filtrando esta lista; digitação livre continua valendo.
  final List<String>? suggestions;
}

class GridRow {
  const GridRow({required this.id, required this.values, this.isNew = false});
  final String id;
  final Map<String, Object?> values;
  final bool isNew;
}

class GridChange {
  const GridChange({required this.rowId, required this.values});
  final String rowId;

  /// Só as keys alteradas.
  final Map<String, Object?> values;
}

typedef GridValidator = String? Function(
    String key, Object? value, Map<String, Object?> row);

/// Bloco TSV da área de transferência → matriz de células.
List<List<String>> parseClipboardTsv(String text) {
  final lines = text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n')
      .where((l) => l.isNotEmpty)
      .toList();
  return [for (final l in lines) l.split('\t')];
}

class EditableGrid extends StatefulWidget {
  const EditableGrid({
    super.key,
    required this.columns,
    required this.rows,
    required this.onSave,
    this.validator,
    this.footer,
    this.saveLabel = 'Salvar alterações',
    this.changeNoun = 'linhas',
  });

  final List<GridColumn> columns;
  final List<GridRow> rows;
  final Future<void> Function(List<GridChange> changes) onSave;
  final GridValidator? validator;
  final Widget? footer;
  final String saveLabel;

  /// Substantivo plural da contagem na barra ("animais", "doses").
  /// O singular é derivado removendo o "s"/"is" final quando a contagem é 1.
  final String changeNoun;

  @override
  State<EditableGrid> createState() => _EditableGridState();
}

class _EditableGridState extends State<EditableGrid> {
  final _edits = <String, Map<String, Object?>>{};
  final _errors = <String, String>{}; // '$rowId|$key' → mensagem
  (int, int)? _editing; // (rowIdx, colIdx) em edição inline
  (int, int)? _focused; // célula focada (alvo do Ctrl+V)
  bool _saving = false;
  final _gridFocus = FocusNode();

  bool get _dirty => _edits.isNotEmpty;
  int get _dirtyCells => _edits.values.fold(0, (n, m) => n + m.length);

  Object? _value(GridRow r, String k) =>
      _edits[r.id]?.containsKey(k) == true ? _edits[r.id]![k] : r.values[k];

  Map<String, Object?> _effectiveRow(GridRow r) =>
      {...r.values, ...?_edits[r.id]};

  void _set(GridRow r, GridColumn c, Object? v) {
    setState(() {
      final original = r.values[c.key];
      final m = _edits.putIfAbsent(r.id, () => {});
      if (v == original || (v == null && original == null)) {
        m.remove(c.key);
        if (m.isEmpty) _edits.remove(r.id);
      } else {
        m[c.key] = v;
      }
      final err = widget.validator?.call(c.key, v, _effectiveRow(r));
      final ek = '${r.id}|${c.key}';
      if (err == null) {
        _errors.remove(ek);
      } else {
        _errors[ek] = err;
      }
    });
  }

  /// Texto digitado → valor tipado da coluna. Inválido = erro na célula.
  void _commitText(GridRow r, GridColumn c, String text) {
    final s = text.trim();
    Object? v;
    var parseError = false;
    if (s.isEmpty) {
      v = null;
    } else {
      switch (c.type) {
        case SheetColumnType.integer:
          v = int.tryParse(s);
          parseError = v == null;
        case SheetColumnType.decimal:
          v = double.tryParse(s.replaceAll(',', '.'));
          parseError = v == null;
        case SheetColumnType.date:
          try {
            v = DateFormat('dd/MM/yyyy').parseStrict(s);
          } on FormatException {
            parseError = true;
          }
        case SheetColumnType.enumeration:
          final n = normalizeHeader(s);
          final opts = c.options ?? const {};
          for (final e in opts.entries) {
            if (normalizeHeader(e.key) == n ||
                normalizeHeader(e.value) == n) {
              v = e.key;
              break;
            }
          }
          parseError = v == null;
        case SheetColumnType.text:
          v = s;
      }
    }
    if (parseError) {
      setState(() => _errors['${r.id}|${c.key}'] = '${c.label}: "$s" inválido');
      return;
    }
    _set(r, c, v);
  }

  List<GridColumn> get _cols => widget.columns;

  void _moveFocus(int dRow, int dCol) {
    final from = _editing ?? _focused;
    if (from == null) return;
    var (row, col) = from;
    if (dCol != 0) {
      // Tab: varre células editáveis na leitura natural.
      var i = row * _cols.length + col;
      final total = widget.rows.length * _cols.length;
      do {
        i += dCol;
        if (i < 0 || i >= total) return;
      } while (!_cols[i % _cols.length].editable);
      row = i ~/ _cols.length;
      col = i % _cols.length;
    } else {
      row += dRow;
      if (row < 0 || row >= widget.rows.length) return;
    }
    setState(() {
      _editing = (row, col);
      _focused = (row, col);
    });
  }

  Future<void> _paste() async {
    final target = _focused;
    if (target == null) return;
    final data = await Clipboard.getData('text/plain');
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    final block = parseClipboardTsv(text);
    final (startRow, startCol) = target;
    setState(() {
      for (var i = 0; i < block.length; i++) {
        final rowIdx = startRow + i;
        if (rowIdx >= widget.rows.length) break;
        for (var j = 0; j < block[i].length; j++) {
          final colIdx = startCol + j;
          if (colIdx >= _cols.length) break;
          final c = _cols[colIdx];
          if (!c.editable) continue;
          _commitText(widget.rows[rowIdx], c, block[i][j]);
        }
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.onSave([
        for (final e in _edits.entries)
          GridChange(rowId: e.key, values: Map.of(e.value)),
      ]);
      setState(() {
        _edits.clear();
        _errors.clear();
        _editing = null;
      });
    } catch (_) {
      // onSave já mostrou o erro (SnackBar); edições ficam para nova tentativa.
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _discard() => setState(() {
        _edits.clear();
        _errors.clear();
        _editing = null;
      });

  Future<bool> _confirmDiscard() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descartar alterações?'),
        content: Text('$_dirtyCells células alteradas serão perdidas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Continuar editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  void dispose() {
    _gridFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await _confirmDiscard();
        if (ok && context.mounted) {
          _discard();
          Navigator.of(context).pop();
        }
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyV, control: true):
              _paste,
        },
        child: Focus(
          focusNode: _gridFocus,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.rows.length,
                  itemBuilder: (context, i) => _row(i),
                ),
              ),
              if (widget.footer != null) widget.footer!,
              if (_dirty)
                _SaveBar(
                  dirtyCells: _dirtyCells,
                  dirtyRows: _edits.length,
                  changeNoun: widget.changeNoun,
                  error: _errors.values.firstOrNull,
                  canSave: _errors.isEmpty && !_saving,
                  saving: _saving,
                  saveLabel: widget.saveLabel,
                  onDiscard: _discard,
                  onSave: _save,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Container(
        constraints: const BoxConstraints(minHeight: 36),
        color: AppColors.surfaceVariant,
        child: Row(
          children: [
            for (final c in _cols)
              c.flex
                  ? Expanded(child: _headerCell(c))
                  : SizedBox(width: c.width, child: _headerCell(c)),
          ],
        ),
      );

  Widget _headerCell(GridColumn c) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text(
          c.label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: AppColors.textSecondary,
          ),
        ),
      );

  Widget _row(int rowIdx) {
    final r = widget.rows[rowIdx];
    return Row(
      children: [
        for (var colIdx = 0; colIdx < _cols.length; colIdx++)
          _cols[colIdx].flex
              ? Expanded(child: _cell(rowIdx, colIdx, r))
              : SizedBox(
                  width: _cols[colIdx].width,
                  child: _cell(rowIdx, colIdx, r),
                ),
      ],
    );
  }

  Widget _cell(int rowIdx, int colIdx, GridRow r) {
    final c = _cols[colIdx];
    final v = _value(r, c.key);
    final isDirty = _edits[r.id]?.containsKey(c.key) ?? false;
    final error = _errors['${r.id}|${c.key}'];
    final isEditing = _editing == (rowIdx, colIdx);
    final isFocused = _focused == (rowIdx, colIdx);

    Widget content;
    if (isEditing && c.editable && c.options == null) {
      content = _InlineEditor(
        suggestions: c.suggestions,
        initial: _displayText(c, v),
        mono: c.mono || c.type == SheetColumnType.integer ||
            c.type == SheetColumnType.decimal,
        onCommit: (text) {
          _commitText(r, c, text);
          setState(() => _editing = null);
        },
        onCommitAndNext: (text) {
          _commitText(r, c, text);
          _moveFocus(1, 0);
        },
        onCommitAndTab: (text, backwards) {
          _commitText(r, c, text);
          _moveFocus(0, backwards ? -1 : 1);
        },
        onCancel: () => setState(() => _editing = null),
      );
    } else if (c.options != null && c.editable) {
      content = DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: v as String?,
          isExpanded: true,
          isDense: true,
          hint: const Text('—', style: TextStyle(fontSize: 14)),
          style: const TextStyle(fontSize: 14, color: AppColors.ink),
          items: [
            for (final e in c.options!.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (nv) {
            _set(r, c, nv);
            setState(() => _focused = (rowIdx, colIdx));
          },
        ),
      );
    } else {
      content = Text(
        _displayText(c, v).isEmpty ? '—' : _displayText(c, v),
        overflow: TextOverflow.ellipsis,
        style: c.mono ||
                c.type == SheetColumnType.integer ||
                c.type == SheetColumnType.decimal
            ? monoStyle(size: 14)
            : const TextStyle(fontSize: 14),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: !c.editable || c.options != null
          ? () => setState(() => _focused = (rowIdx, colIdx))
          : () => setState(() {
                _editing = (rowIdx, colIdx);
                _focused = (rowIdx, colIdx);
              }),
      child: Container(
        height: 44,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: !c.editable
              ? AppColors.surfaceSubtle
              : isEditing
                  ? AppColors.surface
                  : isDirty
                      ? AppColors.accentContainer
                      : null,
          border: error != null
              ? Border.all(color: AppColors.danger, width: 2)
              : isFocused || isEditing
                  ? Border.all(color: AppColors.primary, width: 2)
                  : const Border(
                      bottom: BorderSide(color: AppColors.divider),
                      right: BorderSide(color: AppColors.divider),
                    ),
        ),
        child: content,
      ),
    );
  }

  String _displayText(GridColumn c, Object? v) {
    if (v == null) return '';
    if (v is DateTime) return DateFormat('dd/MM/yyyy').format(v);
    if (c.options != null) return c.options![v] ?? v.toString();
    if (v is double) {
      return v == v.roundToDouble()
          ? v.toInt().toString()
          : v.toString().replaceAll('.', ',');
    }
    return v.toString();
  }
}

class _InlineEditor extends StatefulWidget {
  const _InlineEditor({
    required this.initial,
    required this.mono,
    required this.onCommit,
    required this.onCommitAndNext,
    required this.onCommitAndTab,
    required this.onCancel,
    this.suggestions,
  });

  final List<String>? suggestions;
  final String initial;
  final bool mono;
  final void Function(String) onCommit;
  final void Function(String) onCommitAndNext;
  final void Function(String, bool backwards) onCommitAndTab;
  final VoidCallback onCancel;

  @override
  State<_InlineEditor> createState() => _InlineEditorState();
}

class _InlineEditorState extends State<_InlineEditor> {
  late final _ctrl = TextEditingController(text: widget.initial);
  final _autoFocusNode = FocusNode();
  bool _handled = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _autoFocusNode.dispose();
    super.dispose();
  }

  Widget _field([TextEditingController? ctrl, FocusNode? focus]) => TextField(
        controller: ctrl ?? _ctrl,
        focusNode: focus,
        autofocus: true,
        decoration: null,
        style:
            widget.mono ? monoStyle(size: 14) : const TextStyle(fontSize: 14),
        textInputAction: TextInputAction.done,
        onSubmitted: (text) {
          _handled = true;
          widget.onCommitAndNext(text);
        },
      );

  @override
  Widget build(BuildContext context) {
    final suggestions = widget.suggestions;
    final hasSuggestions = suggestions != null && suggestions.isNotEmpty;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          _handled = true;
          widget.onCancel();
        },
        const SingleActivator(LogicalKeyboardKey.tab): () {
          _handled = true;
          widget.onCommitAndTab(_ctrl.text, false);
        },
        const SingleActivator(LogicalKeyboardKey.tab, shift: true): () {
          _handled = true;
          widget.onCommitAndTab(_ctrl.text, true);
        },
      },
      child: Focus(
        onFocusChange: (has) {
          if (!has && !_handled) widget.onCommit(_ctrl.text);
        },
        child: !hasSuggestions
            ? _field()
            // Search-select: RawAutocomplete usa o Overlay raiz — as
            // sugestões flutuam sobre as linhas seguintes sem clip.
            : RawAutocomplete<String>(
                textEditingController: _ctrl,
                focusNode: _autoFocusNode,
                optionsBuilder: (value) {
                  final q = normalizeHeader(value.text);
                  return [
                    for (final s in suggestions)
                      if (q.isEmpty || normalizeHeader(s).contains(q)) s,
                  ];
                },
                onSelected: (s) {
                  _handled = true;
                  widget.onCommit(s);
                },
                fieldViewBuilder: (context, ctrl, focus, onSubmit) =>
                    _field(ctrl, focus),
                optionsViewBuilder: (context, onSelected, options) => Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(8),
                    color: AppColors.surface,
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxHeight: 200, maxWidth: 240),
                      child: ListView(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        children: [
                          for (final s in options.take(6))
                            InkWell(
                              onTap: () => onSelected(s),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                child: Text(s,
                                    style: const TextStyle(fontSize: 13.5)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class GridSaveBar extends StatelessWidget {
  const GridSaveBar({
    super.key,
    required this.summary,
    this.error,
    required this.canSave,
    required this.saving,
    required this.saveLabel,
    required this.onDiscard,
    required this.onSave,
  });

  final Widget summary;
  final String? error;
  final bool canSave;
  final bool saving;
  final String saveLabel;
  final VoidCallback onDiscard;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: AppColors.ink,
      child: Row(
        children: [
          Expanded(
            child: DefaultTextStyle(
              style: const TextStyle(fontSize: 14, color: AppColors.onGreen),
              child: summary,
            ),
          ),
          if (error != null) ...[
            const Icon(Icons.warning_amber_rounded,
                size: 16, color: AppColors.gold),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                error!,
                style: const TextStyle(fontSize: 13, color: AppColors.gold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 14),
          ],
          OutlinedButton(
            onPressed: saving ? null : onDiscard,
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: AppColors.onGreen,
              disabledForegroundColor: AppColors.onGreenMuted,
              side: const BorderSide(color: AppColors.onGreen, width: 1.5),
            ),
            child: const Text('Descartar'),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: canSave ? onSave : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.onAccent,
              disabledBackgroundColor:
                  AppColors.accent.withValues(alpha: 0.4),
            ),
            child: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(saveLabel),
          ),
        ],
      ),
    );
  }
}

/// "animais" → "animal", "doses" → "dose", "linhas" → "linha".
String singularize(String plural) {
  if (plural.endsWith('ais')) return '${plural.substring(0, plural.length - 2)}l';
  if (plural.endsWith('s')) return plural.substring(0, plural.length - 1);
  return plural;
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.dirtyCells,
    required this.dirtyRows,
    required this.changeNoun,
    required this.error,
    required this.canSave,
    required this.saving,
    required this.saveLabel,
    required this.onDiscard,
    required this.onSave,
  });

  final int dirtyCells;
  final int dirtyRows;
  final String changeNoun;
  final String? error;
  final bool canSave;
  final bool saving;
  final String saveLabel;
  final VoidCallback onDiscard;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final cellWord = dirtyCells == 1 ? 'célula alterada' : 'células alteradas';
    final noun = dirtyRows == 1 ? singularize(changeNoun) : changeNoun;
    return GridSaveBar(
      summary: Text('$dirtyCells $cellWord em $dirtyRows $noun'),
      error: error,
      canSave: canSave,
      saving: saving,
      saveLabel: saveLabel,
      onDiscard: onDiscard,
      onSave: onSave,
    );
  }
}
