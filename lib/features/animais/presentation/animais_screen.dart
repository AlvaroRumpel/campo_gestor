import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../piquetes/data/piquete_model.dart';
import '../../piquetes/data/piquete_repository.dart';
import '../data/animal_constants.dart';
import '../data/animal_model.dart';
import '../data/animal_repository.dart';

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

  @override
  Widget build(BuildContext context) {
    final animalsAsync = ref.watch(animalListByPropertyProvider);
    final paddocksAsync = ref.watch(paddockListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Animais')),
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

          // Filter animals in-memory
          final filtered = animals.where((aw) {
            final a = aw.animal;
            if (!_showArchived && a.deletedAt != null) return false;
            if (_query.isNotEmpty &&
                !a.number.toString().contains(_query)) {
              return false;
            }
            if (_category != null && a.category != _category) return false;
            if (_lotId != null && a.lotId != _lotId) return false;
            if (_paddockId != null && aw.paddockId != _paddockId) return false;
            return true;
          }).toList()
            ..sort((a, b) => a.animal.number.compareTo(b.animal.number));

          final totalUa = calcTotalUa(filtered.map((aw) => aw.animal));
          final uaStr = totalUa.toStringAsFixed(1).replaceAll('.', ',');
          final summaryText = '${filtered.length} animais · $uaStr UA total';

          final paddocks = paddocksAsync.asData?.value ?? const <Paddock>[];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: SearchBar(
                  controller: _searchCtrl,
                  hintText: 'Buscar por número...',
                  leading: const Icon(Icons.search),
                  trailing: _query.isEmpty
                      ? null
                      : [
                          IconButton(
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close),
                          ),
                        ],
                  onChanged: _onSearchChanged,
                ),
              ),
              const SizedBox(height: 0),
              // Filter row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('Todas'),
                      selected: _category == null,
                      onSelected: (_) => setState(() => _category = null),
                      showCheckmark: false,
                    ),
                    const SizedBox(width: 8),
                    for (final c in kCategories) ...[
                      FilterChip(
                        label: Text(kCategoryLabels[c]!),
                        selected: _category == c,
                        onSelected: (sel) =>
                            setState(() => _category = sel ? c : null),
                        showCheckmark: false,
                      ),
                      const SizedBox(width: 8),
                    ],
                    const SizedBox(width: 8),
                    _LotDropdown(
                      allLots: allLots,
                      value: _lotId,
                      onChanged: (v) => setState(() => _lotId = v),
                    ),
                    const SizedBox(width: 8),
                    _PaddockDropdown(
                      paddocks: paddocks,
                      value: _paddockId,
                      onChanged: (v) => setState(() => _paddockId = v),
                    ),
                  ],
                ),
              ),
              // Summary bar
              Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      summaryText,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              // Archived toggle
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text('Mostrar arquivados'),
                    Switch(
                      value: _showArchived,
                      onChanged: (v) => setState(() => _showArchived = v),
                    ),
                  ],
                ),
              ),
              // List
              Expanded(
                child: filtered.isEmpty
                    ? (animals.where((aw) =>
                                _showArchived || aw.animal.deletedAt == null)
                            .isEmpty &&
                        animals.isEmpty)
                        ? const _EmptyAllState()
                        : filtered.isEmpty && animals.isNotEmpty
                            ? const _EmptyFilterState()
                            : const _EmptyAllState()
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) => _AnimalListTile(
                          item: filtered[i],
                          showArchived: _showArchived,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private widgets
// ---------------------------------------------------------------------------

class _LotDropdown extends StatelessWidget {
  const _LotDropdown({
    required this.allLots,
    required this.value,
    required this.onChanged,
  });

  final Map<String, String> allLots;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String?>(
      value: value,
      hint: const Text('Todos os lotes'),
      underline: const SizedBox(),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('Todos os lotes'),
        ),
        ...allLots.entries.map(
          (e) => DropdownMenuItem<String?>(
            value: e.key,
            child: Text(e.value),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class _PaddockDropdown extends StatelessWidget {
  const _PaddockDropdown({
    required this.paddocks,
    required this.value,
    required this.onChanged,
  });

  final List<Paddock> paddocks;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String?>(
      value: value,
      hint: const Text('Todos os piquetes'),
      underline: const SizedBox(),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('Todos os piquetes'),
        ),
        ...paddocks.map(
          (p) => DropdownMenuItem<String?>(
            value: p.id,
            child: Text(p.name),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class _AnimalListTile extends StatelessWidget {
  const _AnimalListTile({
    required this.item,
    required this.showArchived,
  });

  final AnimalWithContext item;
  final bool showArchived;

  @override
  Widget build(BuildContext context) {
    final a = item.animal;
    final categoryLabel = kCategoryLabels[a.category] ?? a.category;
    final isArchived = a.deletedAt != null;

    return ListTile(
      title: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '#${a.number}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: ' · $categoryLabel'),
          ],
        ),
      ),
      subtitle: Text(
        '${item.lotName} · ${item.paddockName}',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
      ),
      trailing: (isArchived && showArchived)
          ? _ArchiveBadge(baixaReason: a.baixaReason)
          : null,
      onTap: () => context.go(AppRoutes.animalDetail(a.id)),
    );
  }
}

class _ArchiveBadge extends StatelessWidget {
  const _ArchiveBadge({required this.baixaReason});

  final String? baixaReason;

  String _label(String? reason) => switch (reason) {
        'sale' => 'Vendido',
        'death' => 'Morto',
        'discard' => 'Descartado',
        _ => 'Arquivado',
      };

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(_label(baixaReason)));
  }
}

class _EmptyAllState extends StatelessWidget {
  const _EmptyAllState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.pets_outlined,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum animal cadastrado',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Crie um lote no piquete para registrar os animais da fazenda.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFilterState extends StatelessWidget {
  const _EmptyFilterState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum animal encontrado',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tente ajustar os filtros ou a busca por número.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
