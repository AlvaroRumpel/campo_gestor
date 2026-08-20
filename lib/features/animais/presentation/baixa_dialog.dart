import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/invalidate_property_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../reproducao/data/iatf_repository.dart';
import '../data/animal_constants.dart';
import '../data/animal_model.dart';
import '../data/animal_repository.dart';

/// Sheet destrutivo de baixa (spec 4.15) — conteúdo para [showAdaptiveForm]
/// (ANIM-04, D-17).
///
/// Motivo em 3 botões verticais 52h (Venda/Morte/Descarte, selecionado =
/// fundo vermelho), data mono com picker, observação opcional e banner de
/// aviso quando o animal participa de um IATF ativo.
///
/// Submit chama [AnimalRepository.registerBaixa]. Em sucesso invalida
/// [animalByIdProvider], [animalListByPropertyProvider],
/// [reproductiveHistoryByAnimalProvider] e as famílias
/// [iatfActiveMembershipsProvider] / [iatfMembershipsProvider] /
/// [iatfListByPropertyProvider] (G-05-1), e faz pop com true.
class BaixaDialog extends ConsumerStatefulWidget {
  const BaixaDialog({super.key, required this.animal});

  final Animal animal;

  @override
  ConsumerState<BaixaDialog> createState() => _BaixaDialogState();
}

class _BaixaDialogState extends ConsumerState<BaixaDialog> {
  BaixaReason? _reason;
  DateTime _date = DateTime.now();
  final _obsCtrl = TextEditingController();
  late final TextEditingController _dateCtrl;
  bool _saving = false;
  // dd/MM/yyyy pattern doesn't need locale symbol data — safe to create eagerly.
  final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _dateCtrl = TextEditingController(text: _dateFmt.format(_date));
  }

  @override
  void dispose() {
    _obsCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null && mounted) {
      setState(() {
        _date = picked;
        _dateCtrl.text = _dateFmt.format(picked);
      });
    }
  }

  Future<void> _submit() async {
    if (_reason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione o motivo da baixa')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final obsText = _obsCtrl.text.trim();
      await ref.read(animalRepositoryProvider).registerBaixa(
            id: widget.animal.id,
            reason: _reason!,
            date: _date,
            observation: obsText.isEmpty ? null : obsText,
          );
      // D-19: a baixa também desativa a participação em IATF ativo no servidor
      // (trg_animals_baixa_deactivates_atf), então nada escapa do refetch.
      ref.invalidatePropertyData();
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao registrar baixa. Tente novamente.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static IconData _reasonIcon(BaixaReason r) => switch (r) {
        BaixaReason.sale => Icons.sell_outlined,
        BaixaReason.death => Icons.heart_broken_outlined,
        BaixaReason.discard => Icons.block,
      };

  @override
  Widget build(BuildContext context) {
    // ponytail: aproxima "está em IATF ativo" pelo histórico reprodutivo
    // (entrada com iatfActive) — provider já existente; um animal removido de
    // um IATF ainda ativo geraria falso positivo, caso raro e inofensivo.
    final historyAsync =
        ref.watch(reproductiveHistoryByAnimalProvider(widget.animal.id));
    final activeIatfName = historyAsync.asData?.value
        .where((e) => e.iatfActive)
        .map((e) => e.iatfName)
        .firstOrNull;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Dar baixa no #${widget.animal.number}',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
                children: [
                  TextSpan(text: 'O animal sai do rebanho ativo. '),
                  TextSpan(
                    text: 'Todo o histórico é preservado',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: ' — nada é apagado.'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'MOTIVO *',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final r in BaixaReason.values) ...[
                      _ReasonButton(
                        label: r.label,
                        icon: _reasonIcon(r),
                        selected: _reason == r,
                        onTap: () => setState(() => _reason = r),
                      ),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 6),
                    TextFormField(
                      readOnly: true,
                      style: monoStyle(size: 15.5, weight: FontWeight.w600),
                      decoration: InputDecoration(
                        labelText: 'Data da baixa',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today, size: 22),
                          onPressed: _pickDate,
                        ),
                      ),
                      controller: _dateCtrl,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _obsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Observação',
                        hintText:
                            'Comprador, peso, lote de venda… (opcional)',
                      ),
                      maxLines: 3,
                      textInputAction: TextInputAction.newline,
                    ),
                    if (activeIatfName != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.dangerContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline,
                                size: 19, color: AppColors.danger),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    height: 1.4,
                                    color: AppColors.onDangerContainer,
                                  ),
                                  children: [
                                    TextSpan(
                                        text:
                                            'O #${widget.animal.number} está no '),
                                    TextSpan(
                                      text: activeIatfName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                    const TextSpan(
                                      text:
                                          ' — a baixa também encerra a participação dele nesse ciclo.',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  flex: 10,
                  child: OutlinedButton(
                    onPressed:
                        _saving ? null : () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 54),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 15,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: AppColors.onDanger,
                      minimumSize: const Size(0, 54),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Confirmar baixa'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Botão de motivo 52h (spec 4.15): selecionado = fundo `#A32D14`.
class _ReasonButton extends StatelessWidget {
  const _ReasonButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.onDanger : AppColors.ink;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.danger : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: selected
              ? null
              : Border.all(color: AppColors.outlineBorder),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
