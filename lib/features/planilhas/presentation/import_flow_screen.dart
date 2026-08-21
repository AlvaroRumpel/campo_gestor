// Fluxo de importação em 3 passos: arquivo → mapear colunas → revisar e
// importar. Uma tela para as 4 entidades — o SheetSchema dita colunas,
// validação e RPC de destino. Gravação é tudo-ou-nada (RPCs bulk).
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/current_property_provider.dart';
import '../../../core/providers/invalidate_property_data.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/campo_app_bar.dart';
import '../../../core/widgets/ui.dart';
import '../../animais/data/animal_repository.dart';
import '../../lotes/data/lote_repository.dart';
import '../../piquetes/data/piquete_model.dart';
import '../../piquetes/data/piquete_repository.dart';
import '../../reproducao/data/iatf_model.dart';
import '../../reproducao/data/iatf_repository.dart';
import '../../sanitario/data/dose_repository.dart';
import '../data/bulk_repository.dart';
import '../data/column_mapping.dart';
import '../data/download.dart';
import '../data/sheet_codec.dart';
import '../domain/header_matcher.dart';
import '../domain/import_preview.dart';
import '../domain/sheet_schema.dart';

const _kMaxRows = 5000;
final _dateOnlyFmt = DateFormat('yyyy-MM-dd');

class ImportFlowScreen extends ConsumerStatefulWidget {
  const ImportFlowScreen({super.key, required this.entity, this.iatfId});

  final SheetEntity entity;

  /// Obrigatório quando [entity] é [SheetEntity.dg].
  final String? iatfId;

  @override
  ConsumerState<ImportFlowScreen> createState() => _ImportFlowScreenState();
}

class _ImportFlowScreenState extends ConsumerState<ImportFlowScreen> {
  int _step = 0;
  String? _fileName;
  SheetTable? _table;
  Map<int, String> _mapping = {};
  Set<String> _autoKeys = {};
  List<ImportRow> _rows = [];
  bool _saving = false;
  String? _serverError;

  SheetSchema get schema => schemaFor(widget.entity);

  Future<void> _pickFile() async {
    final f = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'csv'],
    );
    if (f == null) return;
    try {
      final t = decodeSheet(f.name, await f.readAsBytes());
      if (t.headers.isEmpty) {
        throw const FormatException(
            'Planilha vazia ou sem cabeçalho na linha 1');
      }
      if (t.rows.length > _kMaxRows) {
        throw FormatException(
            'Planilha com ${t.rows.length} linhas — o limite é $_kMaxRows');
      }
      final saved = await ColumnMappingStore().load(widget.entity, t.headers);
      final auto = autoMatch(t.headers, schema);
      setState(() {
        _fileName = f.name;
        _table = t;
        _mapping = saved ?? auto;
        _autoKeys = saved == null ? auto.values.toSet() : const {};
        _step = 1;
      });
      if (saved != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mapeamento reaproveitado')),
        );
      }
    } on FormatException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  void _downloadTemplate() {
    final bytes = encodeXlsx(
      sheetName: schema.sheetName,
      headers: schema.importHeaders,
      rows: schema.templateRows(),
    );
    downloadBytes('modelo_${schema.sheetName.toLowerCase()}.xlsx', bytes);
  }

  ImportContext _buildContext() {
    final animals =
        ref.read(animalListByPropertyProvider).asData?.value ?? const [];
    final lots = ref.read(loteListByPropertyProvider).asData?.value ?? const [];
    final doses = ref.read(doseListByPropertyProvider).asData?.value ?? const [];
    final members = widget.iatfId == null
        ? const <IatfMembershipView>[]
        : (ref.read(iatfMembershipsProvider(widget.iatfId!)).asData?.value ??
            const <IatfMembershipView>[]);
    final paddocks =
        ref.read(paddockListProvider).asData?.value ?? const <Paddock>[];
    return ImportContext(
      existingAnimalNumbers: {
        for (final a in animals)
          if (a.animal.deletedAt == null) a.animal.number,
      },
      lotNamesLower: {for (final l in lots) l.name.toLowerCase()},
      doseNamesLower: {for (final d in doses) d.name.toLowerCase()},
      iatfAnimalNumbers: {
        for (final m in members)
          if (!m.animalDeleted) m.animalNumber,
      },
      paddockNamesLower: {for (final p in paddocks) p.name.toLowerCase()},
    );
  }

  Future<void> _goReview(Map<int, String> mapping, bool remember) async {
    if (remember) {
      await ColumnMappingStore().save(widget.entity, _table!.headers, mapping);
    }
    setState(() {
      _mapping = mapping;
      _rows = validateRows(
        schema: schema,
        table: _table!,
        mapping: mapping,
        ctx: _buildContext(),
      );
      _step = 2;
    });
  }

  Future<void> _commit() async {
    final property = ref.read(currentPropertyProvider).asData?.value;
    if (property == null) return;
    final valid =
        _rows.where((r) => r.status != ImportRowStatus.error).toList();
    if (valid.isEmpty) return;
    setState(() {
      _saving = true;
      _serverError = null;
    });
    try {
      Map<String, dynamic> ser(ImportRow r) => {
            for (final e in r.values.entries)
              e.key: e.value is DateTime
                  ? _dateOnlyFmt.format(e.value as DateTime)
                  : e.value,
          };
      final bulk = ref.read(bulkRepositoryProvider);
      String msg;
      switch (widget.entity) {
        case SheetEntity.animais:
          final res =
              await bulk.upsertAnimals(property.id, valid.map(ser).toList());
          msg = '${res.created} animais criados · ${res.updated} atualizados';
        case SheetEntity.doses:
          final res =
              await bulk.upsertDoses(property.id, valid.map(ser).toList());
          msg = '${res.created} doses criadas · ${res.updated} atualizadas';
        case SheetEntity.sanitario:
          final res =
              await bulk.registerSanitary(property.id, valid.map(ser).toList());
          msg = '${res.applications} aplicações registradas · '
              '${res.animals} animais';
        case SheetEntity.dg:
          final members = ref
                  .read(iatfMembershipsProvider(widget.iatfId!))
                  .asData
                  ?.value ??
              const <IatfMembershipView>[];
          final byNumber = {
            for (final m in members) m.animalNumber: m.animalId,
          };
          await ref.read(iatfRepositoryProvider).saveDgRecords(
            iatfBatchId: widget.iatfId!,
            records: [
              for (final r in valid)
                {
                  'animal_id': byNumber[r.values['animal_number']],
                  'result': r.values['result'],
                  'exam_date':
                      _dateOnlyFmt.format(r.values['exam_date'] as DateTime),
                  if (r.values['observation'] != null)
                    'observation': r.values['observation'],
                },
            ],
          );
          msg = '${valid.length} diagnósticos lançados';
        case SheetEntity.lotes:
          final res =
              await bulk.upsertLots(property.id, valid.map(ser).toList());
          msg = '${res.created} lotes criados · ${res.updated} atualizados';
        case SheetEntity.piquetes:
          final res =
              await bulk.upsertPaddocks(property.id, valid.map(ser).toList());
          msg = '${res.created} piquetes criados · ${res.updated} atualizados';
        case SheetEntity.gastos:
          final res =
              await bulk.upsertExpenses(property.id, valid.map(ser).toList());
          msg = '${res.created} gastos criados · ${res.updated} atualizados';
      }
      ref.invalidatePropertyData();
      if (!mounted) return;
      final destination = switch (widget.entity) {
        SheetEntity.animais => AppRoutes.animais,
        SheetEntity.doses || SheetEntity.sanitario => AppRoutes.sanitario,
        SheetEntity.dg => null, // pop já volta para o IATF
        SheetEntity.lotes || SheetEntity.piquetes => AppRoutes.piquetes,
        SheetEntity.gastos => AppRoutes.gastos,
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        action: destination == null
            ? null
            : SnackBarAction(
                label: 'Ver',
                onPressed: () {
                  final router = GoRouter.maybeOf(context);
                  router?.go(destination);
                },
              ),
      ));
      context.pop();
    } on BulkImportException catch (e) {
      setState(() => _serverError = e.message);
    } catch (_) {
      setState(() => _serverError = 'Falha ao importar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CampoAppBar(title: 'Importar planilha', showBack: true),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Stepper(current: _step, entityTitle: schema.title),
          Expanded(
            child: switch (_step) {
              0 => FileStep(
                  schema: schema,
                  onPick: _pickFile,
                  onTemplate: _downloadTemplate,
                  onCancel: () => context.pop(),
                ),
              1 => MappingStep(
                  schema: schema,
                  table: _table!,
                  initial: _mapping,
                  autoKeys: _autoKeys,
                  fileName: _fileName ?? '',
                  onBack: () => setState(() => _step = 0),
                  onNext: _goReview,
                ),
              _ => ReviewStep(
                  schema: schema,
                  mapping: _mapping,
                  rows: _rows,
                  saving: _saving,
                  serverError: _serverError,
                  onBack: () => setState(() => _step = 1),
                  onCommit: _commit,
                ),
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stepper
// ---------------------------------------------------------------------------

class _Stepper extends StatelessWidget {
  const _Stepper({required this.current, required this.entityTitle});
  final int current; // 0..2
  final String entityTitle;

  static const _labels = ['Arquivo', 'Mapear colunas', 'Revisar e importar'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            _circle(i),
            const SizedBox(width: 10),
            Text(
              _labels[i],
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: i <= current
                    ? AppColors.ink
                    : AppColors.textTertiary,
              ),
            ),
            if (i < 2)
              Container(
                width: 48,
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                color: AppColors.chipBorder,
              ),
          ],
          const Spacer(),
          Text(
            entityTitle,
            style: monoStyle(size: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _circle(int i) {
    if (i < current) {
      return Container(
        width: 26,
        height: 26,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary,
        ),
        child: const Icon(Icons.check, size: 14, color: AppColors.onGreen),
      );
    }
    final active = i == current;
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? AppColors.accent : null,
        border: active
            ? null
            : Border.all(color: AppColors.outlineBorder, width: 1.5),
      ),
      child: Text(
        '${i + 1}',
        style: monoStyle(
          size: 12,
          weight: FontWeight.w700,
          color: active ? AppColors.onAccent : AppColors.textTertiary,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Passo 1 — arquivo
// ---------------------------------------------------------------------------

class FileStep extends StatelessWidget {
  const FileStep({
    super.key,
    required this.schema,
    required this.onPick,
    required this.onTemplate,
    required this.onCancel,
  });

  final SheetSchema schema;
  final VoidCallback onPick;
  final VoidCallback onTemplate;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.description_outlined,
                            size: 44, color: AppColors.greenMid),
                        const SizedBox(height: 12),
                        const Text(
                          'Escolha a planilha',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '.xlsx ou .csv · até 5.000 linhas · '
                          'cabeçalho na linha 1',
                          style: TextStyle(
                              fontSize: 13.5, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: onPick,
                          icon: const Icon(Icons.upload_outlined, size: 20),
                          label: const Text('Escolher arquivo'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                SizedBox(
                  width: 340,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionCard(
                        title: 'Modelo',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Planilha vazia com as colunas certas e '
                              '2 linhas de exemplo.',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 6),
                            TextButton.icon(
                              onPressed: onTemplate,
                              icon: const Icon(Icons.download_outlined,
                                  size: 18),
                              label: Text(
                                  'Baixar modelo ${schema.sheetName}.xlsx'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      SectionCard(
                        title: 'Como funciona',
                        child: Text(
                          _howItWorks,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.accentContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Planilhas de outros softwares funcionam: no '
                          'próximo passo você liga as colunas deles aos '
                          'campos do Campo Gestor.',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.accentTextDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _FooterBar(children: [
          const Spacer(),
          TextButton(onPressed: onCancel, child: const Text('Cancelar')),
        ]),
      ],
    );
  }

  String get _howItWorks => switch (schema.entity) {
        SheetEntity.animais =>
          'Número existente na propriedade → atualiza o animal.\n'
              'Número novo ou vazio → cria o animal (precisa do lote).',
        SheetEntity.doses =>
          'Nome existente no catálogo → atualiza a dose.\n'
              'Nome novo → cria a dose.',
        SheetEntity.sanitario =>
          'Cada linha é um animal + dose + data. Linhas do mesmo lote, '
              'dose e data viram uma única aplicação.',
        SheetEntity.dg =>
          'Cada linha lança um DG para um animal deste IATF. Lançamentos '
              'são aditivos — correções ficam no histórico.',
        SheetEntity.lotes =>
          'Nome existente na propriedade → atualiza o lote (piquete).\n'
              'Nome novo → cria o lote (precisa do piquete).',
        SheetEntity.piquetes =>
          'Nome existente → atualiza área e capacidade.\n'
              'Nome novo → cria o piquete.',
        SheetEntity.gastos =>
          'Cada linha vira um gasto novo no piquete indicado.',
      };
}

// ---------------------------------------------------------------------------
// Passo 2 — mapear colunas
// ---------------------------------------------------------------------------

class MappingStep extends StatefulWidget {
  const MappingStep({
    super.key,
    required this.schema,
    required this.table,
    required this.initial,
    required this.autoKeys,
    required this.fileName,
    required this.onBack,
    required this.onNext,
  });

  final SheetSchema schema;
  final SheetTable table;
  final Map<int, String> initial;

  /// Keys preenchidas pelo auto-match (ganham o chip "automático").
  final Set<String> autoKeys;
  final String fileName;
  final VoidCallback onBack;
  final void Function(Map<int, String> mapping, bool remember) onNext;

  @override
  State<MappingStep> createState() => _MappingStepState();
}

class _MappingStepState extends State<MappingStep> {
  late final Map<int, String> _mapping = Map.of(widget.initial);
  bool _remember = true;

  List<String> get _missingRequired => [
        for (final c in widget.schema.requiredColumns)
          if (!_mapping.containsValue(c.key)) c.label,
      ];

  String _sample(int col) {
    final vals = widget.table.rows
        .map((r) => col < r.length ? r[col] : '')
        .where((v) => v.isNotEmpty)
        .take(3)
        .toList();
    return vals.isEmpty ? '—' : vals.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final missing = _missingRequired;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 10),
          child: Row(
            children: [
              const Icon(Icons.description_outlined,
                  size: 28, color: AppColors.primary),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.fileName,
                      style: monoStyle(size: 13, weight: FontWeight.w700)),
                  Text(
                    '${widget.table.rows.length} linhas · '
                    '${widget.table.headers.length} colunas',
                    style:
                        monoStyle(size: 11.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const Spacer(),
              if (missing.isNotEmpty) ...[
                const Text('Faltam obrigatórios: ',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
                for (final m in missing)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: StatusChip(m, kind: StatusKind.danger),
                  ),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: widget.table.headers.length,
            itemBuilder: (context, i) => _row(i),
          ),
        ),
        _FooterBar(children: [
          Checkbox(
            value: _remember,
            onChanged: (v) => setState(() => _remember = v ?? true),
          ),
          const Flexible(
            child: Text(
              'Lembrar este mapeamento para planilhas iguais',
              style: TextStyle(fontSize: 13.5),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Voltar'),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: missing.isEmpty
                ? () => widget.onNext(_mapping, _remember)
                : null,
            child: const Text('Revisar'),
          ),
        ]),
      ],
    );
  }

  Widget _row(int i) {
    final key = _mapping[i];
    final isAuto = key != null && widget.autoKeys.contains(key);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 200,
            child: Text(
              widget.table.headers[i],
              style: monoStyle(size: 13.5, weight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              _sample(i),
              style: monoStyle(size: 12.5, color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 260,
            child: DropdownButtonFormField<String?>(
              initialValue: key,
              isDense: true,
              isExpanded: true,
              decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Ignorar coluna',
                      style: TextStyle(color: AppColors.textTertiary)),
                ),
                for (final c in widget.schema.importColumns)
                  DropdownMenuItem<String?>(
                    value: c.key,
                    enabled: !_mapping.containsValue(c.key) ||
                        _mapping[i] == c.key,
                    child: Text(
                      c.required ? '${c.label} *' : c.label,
                      style: TextStyle(
                        color: !_mapping.containsValue(c.key) ||
                                _mapping[i] == c.key
                            ? null
                            : AppColors.textTertiary,
                      ),
                    ),
                  ),
              ],
              onChanged: (v) => setState(() {
                if (v == null) {
                  _mapping.remove(i);
                } else {
                  _mapping[i] = v;
                }
              }),
            ),
          ),
          SizedBox(
            width: 120,
            child: isAuto
                ? const Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: StatusChip('automático', kind: StatusKind.positive),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Passo 3 — revisar
// ---------------------------------------------------------------------------

class ReviewStep extends StatefulWidget {
  const ReviewStep({
    super.key,
    required this.schema,
    required this.mapping,
    required this.rows,
    required this.saving,
    required this.serverError,
    required this.onBack,
    required this.onCommit,
  });

  final SheetSchema schema;
  final Map<int, String> mapping;
  final List<ImportRow> rows;
  final bool saving;
  final String? serverError;
  final VoidCallback onBack;
  final VoidCallback onCommit;

  @override
  State<ReviewStep> createState() => _ReviewStepState();
}

class _ReviewStepState extends State<ReviewStep> {
  bool _onlyErrors = false;

  @override
  Widget build(BuildContext context) {
    final creates = widget.rows
        .where((r) => r.status == ImportRowStatus.create)
        .length;
    final updates = widget.rows
        .where((r) => r.status == ImportRowStatus.update)
        .length;
    final errors =
        widget.rows.where((r) => r.status == ImportRowStatus.error).length;
    final valid = creates + updates;
    final visible = _onlyErrors
        ? widget.rows
            .where((r) => r.status == ImportRowStatus.error)
            .toList()
        : widget.rows;
    final cols = [
      for (final c in widget.schema.importColumns)
        if (widget.mapping.containsValue(c.key)) c,
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 10),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _countChip('$creates novas', AppColors.positiveChipBg,
                          AppColors.primaryDarkText),
                      const SizedBox(width: 8),
                      _countChip('$updates atualizações',
                          AppColors.neutralChipBg, AppColors.ink),
                      const SizedBox(width: 8),
                      _countChip('$errors com erro', AppColors.dangerChipBg,
                          AppColors.dangerText),
                    ],
                  ),
                ),
              ),
              Checkbox(
                value: _onlyErrors,
                onChanged: (v) => setState(() => _onlyErrors = v ?? false),
              ),
              const Text('Mostrar só erros',
                  style: TextStyle(fontSize: 13.5)),
            ],
          ),
        ),
        if (widget.serverError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: WarningBanner(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  widget.serverError!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.accentTextDark,
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: visible.length + 1,
            itemBuilder: (context, i) =>
                i == 0 ? _header(cols) : _row(visible[i - 1], cols),
          ),
        ),
        _FooterBar(children: [
          const Expanded(
            child: Text(
              'Linhas com erro ficam de fora. O resto entra numa única '
              'operação — se algo falhar no servidor, nada é gravado.',
              style:
                  TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          TextButton.icon(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Voltar'),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed:
                valid == 0 || widget.saving ? null : widget.onCommit,
            child: widget.saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('Importar $valid válidas'),
          ),
        ]),
      ],
    );
  }

  Widget _countChip(String label, Color bg, Color fg) => Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
      );

  Widget _header(List<SheetColumn> cols) => Container(
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        color: AppColors.surfaceVariant,
        child: Row(
          children: [
            const SizedBox(width: 40, child: OverlineLabel('#')),
            for (final c in cols)
              Expanded(child: OverlineLabel(c.label.toUpperCase())),
            const SizedBox(width: 240, child: OverlineLabel('RESULTADO')),
          ],
        ),
      );

  Widget _row(ImportRow r, List<SheetColumn> cols) {
    final (bar, label) = switch (r.status) {
      ImportRowStatus.create => (AppColors.primary, 'Nova'),
      ImportRowStatus.update => (AppColors.greenMid, 'Atualiza'),
      ImportRowStatus.error => (AppColors.danger, 'Erro'),
    };
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: r.status == ImportRowStatus.error
            ? AppColors.dangerContainer
            : r.status == ImportRowStatus.update
                ? AppColors.surfaceSubtle
                : null,
        border: Border(
          left: BorderSide(color: bar, width: 3),
          bottom: const BorderSide(color: AppColors.divider),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text('${r.index}',
                style:
                    monoStyle(size: 11.5, color: AppColors.textTertiary)),
          ),
          for (final c in cols)
            Expanded(
              child: Text(
                _display(r.values[c.key], c),
                style: c.type == SheetColumnType.integer ||
                        c.type == SheetColumnType.decimal
                    ? monoStyle(size: 13.5)
                    : const TextStyle(fontSize: 13.5),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          SizedBox(
            width: 240,
            child: Row(
              children: [
                StatusChip(
                  label,
                  kind: switch (r.status) {
                    ImportRowStatus.create => StatusKind.positive,
                    ImportRowStatus.update => StatusKind.neutral,
                    ImportRowStatus.error => StatusKind.danger,
                  },
                ),
                if (r.errors.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      r.errors.join(' · '),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.dangerText,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _display(Object? v, SheetColumn c) {
    if (v == null) return '—';
    if (v is DateTime) return DateFormat('dd/MM/yyyy').format(v);
    if (c.type == SheetColumnType.enumeration) {
      return c.enumValues[v] ?? v.toString();
    }
    return v.toString();
  }
}

// ---------------------------------------------------------------------------
// Rodapé comum
// ---------------------------------------------------------------------------

class _FooterBar extends StatelessWidget {
  const _FooterBar({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(children: children),
    );
  }
}
