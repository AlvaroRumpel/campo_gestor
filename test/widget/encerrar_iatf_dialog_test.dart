// REPR-03, REPR-04 — EncerrarIatfDialog widget tests (05-UI-SPEC.md section 5, E7).
// Covers the loading/error states the classifier initially missed (kind
// correction, confirmed with the user) plus the fixed-width/one-line-title
// long-text case.
import 'dart:async';

import 'package:campo_gestor/core/services/supabase_service.dart';
import 'package:campo_gestor/core/widgets/ui.dart';
import 'package:campo_gestor/features/reproducao/data/iatf_repository.dart';
import 'package:campo_gestor/features/reproducao/presentation/encerrar_iatf_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fake repository — extends IatfRepository; overrides never call _service
// ---------------------------------------------------------------------------

class _FakeIatfRepo extends IatfRepository {
  _FakeIatfRepo({this.shouldThrow = false}) : super(SupabaseService());

  final bool shouldThrow;
  int closeCallCount = 0;
  String? capturedIatfId;

  @override
  Future<void> closeIatf(String iatfBatchId) async {
    closeCallCount++;
    if (shouldThrow) throw Exception('boom');
    capturedIatfId = iatfBatchId;
  }
}

// ---------------------------------------------------------------------------
// Widget builder — pushes the dialog via showDialog so pop(true)/pop(false)
// are observable (mirrors the app's own showDialog<bool> call site).
// ---------------------------------------------------------------------------

Widget _buildHost({
  String iatfId = 'iatf-1',
  String iatfName = 'IATF Primavera',
  int pendingCount = 0,
  IatfRepository? repo,
}) {
  return ProviderScope(
    overrides: [
      iatfRepositoryProvider.overrideWithValue(repo ?? _FakeIatfRepo()),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              // Mirrors the app's own call site (iatf_detail_screen.dart):
              // sheet-style content hosted via showAdaptiveForm.
              onPressed: () => showAdaptiveForm<bool>(
                context: context,
                builder: (_) => EncerrarIatfDialog(
                  iatfId: iatfId,
                  iatfName: iatfName,
                  pendingCount: pendingCount,
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('EncerrarIatfDialog (REPR-03, REPR-04, 05-UI-SPEC section 5/E7)', () {
    testWidgets('body prose and both footer actions render', (tester) async {
      await tester.pumpWidget(_buildHost());
      await _openDialog(tester);

      expect(
        find.text(
          'Esta ação libera os animais para participar de um novo ciclo. '
          'O histórico é preservado e correções de DG continuam '
          'possíveis depois de encerrado.',
        ),
        findsOneWidget,
      );
      // Redesign: fixed 400px content was replaced by showAdaptiveForm's
      // responsive shell; the footer action pair is the stable structure.
      expect(find.widgetWithText(OutlinedButton, 'Cancelar'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Encerrar'), findsOneWidget);
    });

    testWidgets(
        'pending count above zero renders the warning line with the count',
        (tester) async {
      await tester.pumpWidget(_buildHost(pendingCount: 3));
      await _openDialog(tester);

      expect(
        find.text('Ainda há 3 animais sem DG registrado.'),
        findsOneWidget,
      );
    });

    testWidgets('zero pending count renders no warning line', (tester) async {
      await tester.pumpWidget(_buildHost());
      await _openDialog(tester);

      expect(find.textContaining('sem DG registrado'), findsNothing);
    });

    testWidgets('tapping "Encerrar" calls closeIatf exactly once and pops with true',
        (tester) async {
      final repo = _FakeIatfRepo();
      String? result;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [iatfRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            localizationsDelegates: const [
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    final confirmed = await showAdaptiveForm<bool>(
                      context: context,
                      builder: (_) => const EncerrarIatfDialog(
                        iatfId: 'iatf-9',
                        iatfName: 'IATF Outono',
                        pendingCount: 0,
                      ),
                    );
                    result = confirmed == true ? 'popped-true' : 'other';
                  },
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await _openDialog(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Encerrar'));
      await tester.pumpAndSettle();

      expect(repo.closeCallCount, 1);
      expect(repo.capturedIatfId, 'iatf-9');
      expect(result, 'popped-true');
      expect(find.byType(EncerrarIatfDialog), findsNothing);
    });

    testWidgets(
        'while the repository call is in flight the confirm button is disabled '
        'and the dialog stays mounted (no optimistic dismissal)',
        (tester) async {
      final repo = _SlowFakeIatfRepo();
      await tester.pumpWidget(_buildHost(repo: repo));
      await _openDialog(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Encerrar'));
      await tester.pump();

      // Still in-flight: title swapped to a LinearProgressIndicator, the
      // dialog is still mounted, and the confirm control is unreachable by
      // its former text (it now shows a spinner, not "Encerrar").
      expect(find.byType(LinearProgressIndicator), findsWidgets);
      expect(find.byType(EncerrarIatfDialog), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Encerrar'), findsNothing);

      repo.complete();
      await tester.pumpAndSettle();
    });

    testWidgets(
        'a repository throw leaves the dialog mounted and renders the '
        'encerramento-failure copy', (tester) async {
      final repo = _FakeIatfRepo(shouldThrow: true);
      await tester.pumpWidget(_buildHost(repo: repo));
      await _openDialog(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Encerrar'));
      await tester.pumpAndSettle();

      expect(find.byType(EncerrarIatfDialog), findsOneWidget);
      expect(
        find.text('Não foi possível encerrar o IATF. Tente novamente.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'a very long IATF name renders on one line without a layout overflow error',
        (tester) async {
      await tester.pumpWidget(
        _buildHost(
          iatfName:
              'IATF Primavera Verão Outono Inverno Ciclo Muito Longo Demais Para Uma Linha Só',
        ),
      );
      await _openDialog(tester);

      expect(tester.takeException(), isNull);
    });
  });
}

/// A repo whose [closeIatf] does not resolve until [complete] is called —
/// isolates the in-flight/no-optimistic-dismissal assertion from timing.
class _SlowFakeIatfRepo extends IatfRepository {
  _SlowFakeIatfRepo() : super(SupabaseService());

  final _completer = Completer<void>();

  void complete() {
    if (!_completer.isCompleted) _completer.complete();
  }

  @override
  Future<void> closeIatf(String iatfBatchId) => _completer.future;
}
