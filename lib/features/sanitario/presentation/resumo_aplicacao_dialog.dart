import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/current_property_provider.dart';
import '../../animais/data/animal_model.dart';
import '../../propriedades/data/propriedade_repository.dart';
import '../data/dose_model.dart';
import '../data/sanitary_application_exception.dart';
import '../data/sanitary_application_repository.dart';
import '../data/sanitary_calculations.dart';

/// The two outcomes `ResumoAplicacaoDialog` can pop with, beyond the plain
/// `null` a "Voltar" tap pops — the contract 06-09's
/// `SanitaryAnimalSelectionScreen` branches on.
enum ResumoAplicacaoOutcome {
  /// The RPC call succeeded and a new frozen row exists.
  registered,

  /// The RPC rejected a stale composition (P0002) and the user asked to
  /// reload — the caller re-fetches the lot's current active animals,
  /// preserving still-valid deselections (D-32/D-33).
  reload,
}

/// The value `ResumoAplicacaoDialog` pops with on anything other than a
/// plain "Voltar" tap. [animalCount] is only meaningful when [outcome] is
/// [ResumoAplicacaoOutcome.registered] — the caller shows the locked success
/// snackbar with that count (D-24).
class ResumoAplicacaoResult {
  const ResumoAplicacaoResult(this.outcome, {this.animalCount});

  final ResumoAplicacaoOutcome outcome;
  final int? animalCount;
}

/// The confirm-before-INSERT dialog (SANI-02, D-23/D-34/D-35/D-36) — the
/// single irreversible write in this phase. Shows a totals preview, an
/// always-on permanence warning, an extra-confirmation gate when an
/// identical recent application is detected, and performs the one RPC call.
///
/// Takes the selected [Animal] values (not just their ids) so the UA/volume
/// preview can be computed from their categories without a second query —
/// display-only figures the RPC independently re-derives server-side
/// (T-06-02); no total is ever sent back to the server.
class ResumoAplicacaoDialog extends ConsumerStatefulWidget {
  const ResumoAplicacaoDialog({
    super.key,
    required this.lotId,
    required this.lotName,
    required this.dose,
    required this.appliedAt,
    required this.selectedAnimals,
    required this.deselectedCount,
  });

  final String lotId;
  final String lotName;
  final Dose dose;
  final DateTime appliedAt;
  final List<Animal> selectedAnimals;
  final int deselectedCount;

  @override
  ConsumerState<ResumoAplicacaoDialog> createState() =>
      _ResumoAplicacaoDialogState();
}

class _ResumoAplicacaoDialogState extends ConsumerState<ResumoAplicacaoDialog> {
  static final _dateFmt = DateFormat('dd/MM/yyyy');

  String? _duplicateApplicationId;
  bool _duplicateAcknowledged = false;
  bool _saving = false;
  SanitaryApplicationException? _error;

  @override
  void initState() {
    super.initState();
    _checkDuplicate();
  }

  /// D-34: fire-and-forget lookup for a recent identical application. A
  /// failure is treated as "no duplicate found" — warning the user twice is
  /// a worse outcome than blocking a legitimate write over a lookup hiccup.
  Future<void> _checkDuplicate() async {
    String? id;
    try {
      id = await ref
          .read(sanitaryApplicationRepositoryProvider)
          .findRecentIdenticalApplication(
            lotId: widget.lotId,
            doseId: widget.dose.id,
            appliedAt: widget.appliedAt,
          );
    } catch (_) {
      id = null;
    }
    if (mounted) setState(() => _duplicateApplicationId = id);
  }

  /// D-12: the active property's UA factor, defaulting to 400 while the
  /// property list is still loading or the active property can't be
  /// resolved yet — this is a display-only preview, never a value sent to
  /// the server.
  double _resolveKgPerUa() {
    final currentId = ref.watch(currentPropertyProvider).asData?.value?.id;
    final properties = ref.watch(propertyListProvider).asData?.value;
    if (currentId == null || properties == null) return 400;
    for (final property in properties) {
      if (property.id == currentId) return property.kgPerUa;
    }
    return 400;
  }

  void _handleReload() {
    Navigator.pop(
      context,
      const ResumoAplicacaoResult(ResumoAplicacaoOutcome.reload),
    );
  }

  /// Registers the application (SANI-02). On success invalidates every
  /// provider a caller downstream could otherwise show stale data from and
  /// pops with the registered outcome; on failure maps the error into the
  /// inline slot and leaves every previewed value plus the duplicate
  /// acknowledgement intact (D-36).
  Future<void> _confirm() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(sanitaryApplicationRepositoryProvider)
          .registerApplication(
            lotId: widget.lotId,
            doseId: widget.dose.id,
            appliedAt: widget.appliedAt,
            animalIds: [for (final a in widget.selectedAnimals) a.id],
          );
      if (!mounted) return;
      ref.invalidate(sanitaryApplicationListByPropertyProvider);
      ref.invalidate(sanitaryApplicationsByLotProvider(widget.lotId));
      for (final animal in widget.selectedAnimals) {
        ref.invalidate(sanitaryHistoryByAnimalProvider(animal.id));
      }
      final count = widget.selectedAnimals.length;
      Navigator.pop(
        context,
        ResumoAplicacaoResult(
          ResumoAplicacaoOutcome.registered,
          animalCount: count,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = asSanitaryException(
          e,
          fallbackMessage:
              'Não foi possível registrar a aplicação. Tente novamente.',
        );
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final kgPerUa = _resolveKgPerUa();
    final totalUa = totalUaForCategories(
      widget.selectedAnimals.map((a) => a.category),
    );
    final volumeMl = totalVolumeMl(totalUa, widget.dose.dosagePerKg, kgPerUa);
    final cost = totalCost(totalUa, widget.dose.costPerKg, kgPerUa);
    final animalCount = widget.selectedAnimals.length;
    final showDuplicateWarning = _duplicateApplicationId != null;
    final confirmDisabled =
        _saving || (showDuplicateWarning && !_duplicateAcknowledged);
    final totalsStyle = theme.textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w600,
      color: colorScheme.primary,
    );

    return AlertDialog(
      title: const Text('Confirmar aplicação'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _KvRow(label: 'Dose', value: Text(widget.dose.name)),
              const SizedBox(height: 8),
              _KvRow(label: 'Lote', value: Text(widget.lotName)),
              const SizedBox(height: 8),
              _KvRow(
                label: 'Data',
                value: Text(_dateFmt.format(widget.appliedAt)),
              ),
              const SizedBox(height: 16),
              Text(
                '${Intl.plural(animalCount, one: '1 animal', other: '$animalCount animais', locale: 'pt_BR')} '
                '· ${formatUa(totalUa)} UA',
                style: totalsStyle,
              ),
              Text(
                'Volume total: ${formatVolumeMl(volumeMl)}',
                style: totalsStyle,
              ),
              if (widget.dose.costPerKg != null)
                Text(
                  'Custo total: ${formatCurrencyBrl(cost!)}',
                  style: totalsStyle,
                ),
              if (widget.deselectedCount > 0) ...[
                const SizedBox(height: 8),
                Text(
                  Intl.plural(
                    widget.deselectedCount,
                    one: '1 animal desmarcado.',
                    other: '${widget.deselectedCount} animais desmarcados.',
                    locale: 'pt_BR',
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _buildPermanenceWarning(theme, colorScheme),
              if (showDuplicateWarning) ...[
                const SizedBox(height: 16),
                _buildDuplicateWarning(theme, colorScheme),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                _buildErrorSlot(theme, colorScheme, _error!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Voltar'),
        ),
        FilledButton(
          onPressed: confirmDisabled ? null : _confirm,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Registrar aplicação'),
        ),
      ],
    );
  }

  /// Always rendered (D-23): the write is irreversible by design, so one
  /// wrong tap must not become a permanent record.
  Widget _buildPermanenceWarning(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: colorScheme.onSurface),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Este registro é permanente e não pode ser editado ou apagado '
              'depois de confirmado.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  /// D-34: a recent identical application (same dose + lot + date) was
  /// found — never a server-side block, only an extra client confirmation.
  /// The checkbox is what [confirmDisabled] in [build] gates on.
  Widget _buildDuplicateWarning(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber,
                  color: colorScheme.onTertiaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Uma aplicação idêntica (mesma dose, lote e data) já foi '
                    'registrada recentemente. Confirmar mesmo assim?',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          CheckboxListTile(
            value: _duplicateAcknowledged,
            onChanged: (v) =>
                setState(() => _duplicateAcknowledged = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: colorScheme.onTertiaryContainer,
            title: Text(
              'Sim, registrar mesmo assim',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// D-35/D-36: the RPC's mapped message, plus the "Recarregar" recovery
  /// action only when the failure is the composition-changed reason (D-32).
  /// Never a snackbar — the only snackbar this flow shows is success, and
  /// that is the caller's responsibility after this dialog pops.
  Widget _buildErrorSlot(
    ThemeData theme,
    ColorScheme colorScheme,
    SanitaryApplicationException error,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            error.message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.error,
            ),
          ),
        ),
        if (error.reason == SanitaryApplicationErrorReason.compositionChanged)
          TextButton(onPressed: _handleReload, child: const Text('Recarregar')),
      ],
    );
  }
}

/// Shared 120px-label key-value row (`animal_detail_screen.dart`'s `_KvRow`
/// pattern) — the [value] slot wraps rather than truncates, per this
/// dialog's must-have that dose/lote names never clip.
class _KvRow extends StatelessWidget {
  const _KvRow({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: value),
      ],
    );
  }
}
