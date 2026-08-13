import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/current_property_provider.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/campo_app_bar.dart';
import '../../../core/widgets/ui.dart';
import '../../auth/data/property_repository.dart';
import '../../piquetes/data/piquete_model.dart';
import '../../piquetes/data/piquete_repository.dart';
import '../data/animal_constants.dart';
import '../data/animal_model.dart';
import '../data/animal_repository.dart';
import 'animal_form_dialog.dart';

/// Lista densa de animais (spec 4.3): filtros + faixa de totais + lista
/// branca agrupada por piquete/lote com linhas densas (spec 3.9).
class AnimaisScreen extends ConsumerStatefulWidget {
  const AnimaisScreen({super.key});

  @override
  ConsumerState<AnimaisScreen> createState() => _AnimaisScreenState();
}

class _AnimaisScreenState extends ConsumerState<AnimaisScreen> {
  String _query = '';
  String? _category; // null = 'Todas'
  String? _lotId; // null = 'Todos os lotes'
  String? _paddockId; // null = 'Todos os piquetes'
  bool _showArchived = false;
  Timer? _debounce;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = v.trim());
    });
  }

  bool _canEdit(
    SelectedProperty? current,
    List<PropertyMembership>? members,
  ) {
    if (current == null || members == null) return false;
    final role = members
        .where((m) => m.property.id == current.id)
        .map((m) => m.role)
        .firstOrNull;
    return role == 'veterinarian';
  }

  /// Non-category filters (search, archived toggle, lote, piquete) — shared
  /// by the visible list and by the per-category chip counts.
  bool _passesBaseFilters(AnimalWithContext aw) {
    final a = aw.animal;
    // D-17: an exact-number search bypasses the archived toggle — a
    // partial/substring match still respects it.
    final isExactNumberMatch =
        _query.isNotEmpty && a.number.toString() == _query;
    if (!_showArchived && a.deletedAt != null && !isExactNumberMatch) {
      return false;
    }
    if (_query.isNotEmpty && !a.number.toString().contains(_query)) {
      return false;
    }
    if (_lotId != null && a.lotId != _lotId) return false;
    if (_paddockId != null && aw.paddockId != _paddockId) return false;
    return true;
  }

  Future<void> _openCreateForm(SelectedProperty property) async {
    await showAdaptiveForm<bool>(
      context: context,
      builder: (_) => AnimalFormDialog(propertyId: property.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final animalsAsync = ref.watch(animalListByPropertyProvider);
    final paddocksAsync = ref.watch(paddockListProvider);
    final currentPropAsync = ref.watch(currentPropertyProvider);
    final membersAsync = ref.watch(memberPropertiesProvider);

    final currentProperty = currentPropAsync.asData?.value;
    final canEdit = _canEdit(currentProperty, membersAsync.asData?.value);

    return Scaffold(
      appBar: const CampoAppBar(title: 'Animais'),
      floatingActionButton: (canEdit && currentProperty != null)
          ? FloatingActionButton.extended(
              onPressed: () => _openCreateForm(currentProperty),
              icon: const Icon(Icons.add, size: 22),
              label: const Text('Animal'),
            )
          : null,
      body: animalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) =>
            const Center(child: Text('Erro ao carregar animais.')),
        data: (animals) {
          // Build deduplicated lot map from animal context
          final allLots = <String, String>{};
          for (final aw in animals) {
            allLots[aw.animal.lotId] = aw.lotName;
          }

          final base = animals.where(_passesBaseFilters).toList();

          // Per-category counts on the base filters (spec 3.5: "Vaca 98").
          final categoryCounts = <String, int>{};
          for (final aw in base) {
            categoryCounts.update(
              aw.animal.category,
              (n) => n + 1,
              ifAbsent: () => 1,
            );
          }

          final filtered = base
              .where((aw) => _category == null || aw.animal.category == _category)
              .toList()
            ..sort((a, b) => a.animal.number.compareTo(b.animal.number));

          final totalUa = calcTotalUa(filtered.map((aw) => aw.animal));
          final paddocks = paddocksAsync.asData?.value ?? const <Paddock>[];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Bloco de filtros (spec 4.3)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _searchCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Buscar número',
                        prefixIcon: const Icon(Icons.search,
                            size: 22, color: AppColors.textSecondary),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _query = '');
                                },
                                icon: const Icon(Icons.close, size: 20),
                              ),
                      ),
                      onChanged: _onSearchChanged,
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _CategoryChip(
                            label: 'Todas',
                            count: base.length,
                            selected: _category == null,
                            onSelected: (_) => setState(() => _category = null),
                          ),
                          for (final c in kCategories) ...[
                            const SizedBox(width: 8),
                            _CategoryChip(
                              label: kCategoryLabels[c]!,
                              count: categoryCounts[c] ?? 0,
                              selected: _category == c,
                              onSelected: (sel) =>
                                  setState(() => _category = sel ? c : null),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _FilterMenuChip(
                          addLabel: '+ Lote',
                          selectedLabel:
                              _lotId == null ? null : allLots[_lotId],
                          entries: allLots,
                          onSelected: (id) => setState(() => _lotId = id),
                          onCleared: () => setState(() => _lotId = null),
                        ),
                        const SizedBox(width: 8),
                        _FilterMenuChip(
                          addLabel: '+ Piquete',
                          selectedLabel: _paddockId == null
                              ? null
                              : paddocks
                                  .where((p) => p.id == _paddockId)
                                  .map((p) => p.name)
                                  .firstOrNull,
                          entries: {for (final p in paddocks) p.id: p.name},
                          onSelected: (id) => setState(() => _paddockId = id),
                          onCleared: () => setState(() => _paddockId = null),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Faixa de totais + toggle arquivados (spec 3.9)
              StatsStrip(
                child: Row(
                  children: [
                    Text(
                      '${filtered.length} animais · ${_fmtUa(totalUa)} UA',
                      style: monoStyle(size: 13, weight: FontWeight.w600),
                    ),
                    const Spacer(),
                    const Text(
                      'arquivados',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Switch(
                      value: _showArchived,
                      onChanged: (v) => setState(() => _showArchived = v),
                    ),
                  ],
                ),
              ),
              // Lista branca agrupada
              Expanded(
                child: filtered.isEmpty
                    ? animals.isEmpty
                        ? const EmptyState(
                            icon: Icons.pets_outlined,
                            title: 'Nenhum animal cadastrado',
                            message:
                                'Crie um lote no piquete para registrar os animais da fazenda.',
                          )
                        : const EmptyState(
                            icon: Icons.search_off,
                            title: 'Nenhum animal encontrado',
                            message:
                                'Tente ajustar os filtros ou a busca por número.',
                          )
                    : _GroupedAnimalList(items: filtered),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _fmtUa(double ua) => ua.toStringAsFixed(1).replaceAll('.', ',');

// ---------------------------------------------------------------------------
// Private widgets
// ---------------------------------------------------------------------------

/// Filter chip de categoria com contagem embutida em mono (spec 3.5).
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final int count;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? AppColors.onGreen : AppColors.ink,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '$count',
            style: monoStyle(
              size: 11.5,
              color: selected
                  ? AppColors.onGreenSecondary
                  : AppColors.textTertiary,
            ),
          ),
        ],
      ),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
    );
  }
}

/// Chip de filtro lote/piquete: "+ Lote" abre menu; selecionado vira chip
/// removível "Lote A ✕" (spec 3.5).
class _FilterMenuChip extends StatelessWidget {
  const _FilterMenuChip({
    required this.addLabel,
    required this.selectedLabel,
    required this.entries,
    required this.onSelected,
    required this.onCleared,
  });

  final String addLabel;
  final String? selectedLabel;
  final Map<String, String> entries;
  final ValueChanged<String> onSelected;
  final VoidCallback onCleared;

  @override
  Widget build(BuildContext context) {
    final label = selectedLabel;
    if (label != null) {
      // Chip removível — tap remove o filtro.
      return InkWell(
        onTap: onCleared,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0x1A3D5435),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryDarkText,
                ),
              ),
              const SizedBox(width: 5),
              const Icon(Icons.close,
                  size: 16, color: AppColors.primaryDarkText),
            ],
          ),
        ),
      );
    }
    return PopupMenuButton<String>(
      tooltip: addLabel,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final e in entries.entries)
          PopupMenuItem<String>(value: e.key, child: Text(e.value)),
      ],
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.chipBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              addLabel,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const Icon(Icons.expand_more,
                size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Item da lista achatada: cabeçalho de grupo ou linha de animal.
class _ListEntry {
  const _ListEntry.header(this.headerTitle, this.headerCount, this.headerUa)
      : item = null;
  const _ListEntry.row(this.item)
      : headerTitle = null,
        headerCount = 0,
        headerUa = 0;
  final AnimalWithContext? item;
  final String? headerTitle;
  final int headerCount;
  final double headerUa;
}

/// Lista branca agrupada por piquete + lote (spec 3.9).
class _GroupedAnimalList extends StatelessWidget {
  const _GroupedAnimalList({required this.items});

  final List<AnimalWithContext> items;

  @override
  Widget build(BuildContext context) {
    // Agrupa por piquete+lote, ordena grupos por nome.
    final groups = <String, List<AnimalWithContext>>{};
    for (final aw in items) {
      groups.putIfAbsent('${aw.paddockName} ${aw.lotName}', () => [])
          .add(aw);
    }
    final keys = groups.keys.toList()..sort();

    final entries = <_ListEntry>[];
    for (final key in keys) {
      final group = groups[key]!;
      final first = group.first;
      entries.add(_ListEntry.header(
        '${first.paddockName} · ${first.lotName}'.toUpperCase(),
        group.length,
        calcTotalUa(group.map((aw) => aw.animal)),
      ));
      entries.addAll(group.map(_ListEntry.row));
    }

    return ColoredBox(
      color: AppColors.surface,
      child: ListView.builder(
        itemCount: entries.length,
        itemBuilder: (ctx, i) {
          final e = entries[i];
          if (e.headerTitle != null) {
            return _GroupHeader(
              title: e.headerTitle!,
              count: e.headerCount,
              ua: e.headerUa,
            );
          }
          return _AnimalDenseRow(item: e.item!);
        },
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.title,
    required this.count,
    required this.ua,
  });

  final String title;
  final int count;
  final double ua;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: const BoxDecoration(
        color: AppColors.surfaceVariant,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: monoStyle(
                size: 10.5,
                weight: FontWeight.w700,
                color: AppColors.primaryDarkText,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Text(
            '$count · ${_fmtUa(ua)} UA',
            style: monoStyle(size: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Linha densa (spec 3.9): número mono → categoria·raça + lote·piquete →
/// chip de status + UA. Arquivado: fundo tingido, textos esmaecidos,
/// número riscado.
class _AnimalDenseRow extends StatelessWidget {
  const _AnimalDenseRow({required this.item});

  final AnimalWithContext item;

  @override
  Widget build(BuildContext context) {
    final a = item.animal;
    final categoryLabel = kCategoryLabels[a.category] ?? a.category;
    final isArchived = a.deletedAt != null;
    final primaryColor = isArchived ? AppColors.textTertiary : AppColors.ink;
    final secondaryColor =
        isArchived ? AppColors.textTertiary : AppColors.textSecondary;
    final breed = a.breed;
    final line1 = breed == null || breed.trim().isEmpty
        ? categoryLabel
        : '$categoryLabel · $breed';
    final ua = kUaWeights[a.category] ?? 0.0;

    return InkWell(
      onTap: () => context.go(AppRoutes.animalDetail(a.id)),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isArchived ? const Color(0x0823281E) : null,
          border: const Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 46),
              child: Text(
                '#${a.number}',
                style: monoStyle(
                  size: 17,
                  weight: FontWeight.w700,
                  color: primaryColor,
                ).copyWith(
                  decoration: isArchived ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: primaryColor,
                    ),
                  ),
                  Text(
                    '${item.lotName} · ${item.paddockName}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: secondaryColor),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isArchived) ...[
                  StatusChip(
                    _baixaLabel(a.baixaReason),
                    kind: a.baixaReason == null
                        ? StatusKind.neutral
                        : StatusKind.danger,
                  ),
                  const SizedBox(height: 3),
                ],
                Text(
                  '${_fmtUa(ua)} UA',
                  style: monoStyle(size: 12.5, color: secondaryColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _baixaLabel(String? reason) => switch (reason) {
        'sale' => 'Vendido',
        'death' => 'Morte',
        'discard' => 'Descarte',
        _ => 'Arquivado',
      };
}
