// Quick task 260813-wmm — prova que AuthScaffold vira um card centrado de
// 440px em >=600px (raio nos 4 cantos, nao encosta no rodape) e mantem a
// folha inferior intacta abaixo de 600px, sem duplicar o child recebido.
import 'package:campo_gestor/features/auth/presentation/auth_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildScaffold() {
  return const MaterialApp(
    home: AuthScaffold(
      title: 'Campo Gestor',
      tagline: 'Gestao de pecuaria',
      child: Text('form-sentinel'),
    ),
  );
}

Future<void> _pump(WidgetTester tester, Size size) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(size);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_buildScaffold());
  await tester.pump();
}

void main() {
  testWidgets('>=600px mostra card centrado de 440', (tester) async {
    await _pump(tester, const Size(900, 800));

    final cardFinder = find.byKey(AuthScaffold.cardKey);
    expect(cardFinder, findsOneWidget);
    expect(tester.getSize(cardFinder).width, 440);
    expect(find.byKey(AuthScaffold.sheetKey), findsNothing);

    final cardBottom = tester.getBottomLeft(cardFinder).dy;
    expect(cardBottom, lessThan(800));
  });

  testWidgets('<600px mantem a folha inferior', (tester) async {
    await _pump(tester, const Size(400, 800));

    expect(find.byKey(AuthScaffold.sheetKey), findsOneWidget);
    expect(find.byKey(AuthScaffold.cardKey), findsNothing);
  });

  testWidgets('o filho atravessa as duas larguras sem duplicar', (tester) async {
    await _pump(tester, const Size(900, 800));
    expect(find.text('form-sentinel'), findsOneWidget);

    await _pump(tester, const Size(400, 800));
    expect(find.text('form-sentinel'), findsOneWidget);
  });
}
