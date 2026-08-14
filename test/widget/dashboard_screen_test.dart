// Redesign 4.1 — DashboardScreen (Início): KPIs, banner "Precisa de você
// hoje", Lotação por piquete, Prenhez e Gastos; layouts mobile (<600px) e
// desktop (>=600px); estados vazios sem crash.
import 'package:campo_gestor/features/animais/data/animal_model.dart';
import 'package:campo_gestor/features/animais/data/animal_repository.dart';
import 'package:campo_gestor/features/auth/data/property_repository.dart';
import 'package:campo_gestor/core/providers/current_property_provider.dart';
import 'package:campo_gestor/features/auth/providers/auth_provider.dart';
import 'package:campo_gestor/features/dashboard/data/dashboard_providers.dart';
import 'package:campo_gestor/features/dashboard/presentation/dashboard_screen.dart';
import 'package:campo_gestor/features/membros/data/membro_models.dart';
import 'package:campo_gestor/features/membros/data/membro_repository.dart';
import 'package:campo_gestor/features/membros/presentation/invite_banner.dart';
import 'package:campo_gestor/features/piquetes/data/piquete_model.dart';
import 'package:campo_gestor/features/piquetes/data/piquete_repository.dart';
import 'package:campo_gestor/features/reproducao/data/atf_model.dart';
import 'package:campo_gestor/features/reproducao/data/atf_repository.dart';
import 'package:campo_gestor/features/reproducao/data/dg_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
// Override is not re-exported by flutter_riverpod in Riverpod 3.x; riverpod is
// a transitive dependency, not a direct one — import the specific file.
import 'package:riverpod/misc.dart' show Override;
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;

// ---------------------------------------------------------------------------
// Sample data
// ---------------------------------------------------------------------------

const _prop = SelectedProperty(id: 'prop-1', name: 'Fazenda Alpha');
const _vetMembership = PropertyMembership(property: _prop, role: 'veterinarian');
const _readerMembership = PropertyMembership(property: _prop, role: 'reader');

final _invite1 = MyInvite(
  id: 'invite-1',
  propertyId: 'prop-2',
  propertyName: 'Fazenda Beta',
  role: 'veterinarian',
  createdAt: DateTime(2026, 1, 1),
);
final _invite2 = MyInvite(
  id: 'invite-2',
  propertyId: 'prop-3',
  propertyName: 'Fazenda Gama',
  role: 'reader',
  createdAt: DateTime(2026, 1, 2),
);

final _paddockOver = Paddock(
  id: 'pad-1',
  propertyId: 'prop-1',
  name: 'Piquete 3',
  areaHa: 22.0,
  uaCapacity: 3.0,
  createdAt: DateTime(2026, 1, 1),
);
final _paddockOk = Paddock(
  id: 'pad-2',
  propertyId: 'prop-1',
  name: 'Piquete 1',
  areaHa: 8.5,
  uaCapacity: 12.0,
  createdAt: DateTime(2026, 1, 1),
);

AnimalWithContext _animal(int n, String category, String paddockId) =>
    AnimalWithContext(
      animal: Animal(
        id: 'animal-$n',
        propertyId: 'prop-1',
        lotId: 'lot-A',
        category: category,
        number: n,
        createdAt: DateTime(2026, 2, 1),
      ),
      lotName: 'Lote A',
      paddockId: paddockId,
      paddockName: paddockId == 'pad-1' ? 'Piquete 3' : 'Piquete 1',
    );

/// 4 vacas no Piquete 3 (4,0 UA > 3,0 capacidade) + 2 terneiros no Piquete 1
/// (1,0 UA) = 6 ativos, 5,0 UA.
final _animals = [
  _animal(1, 'vaca', 'pad-1'),
  _animal(2, 'vaca', 'pad-1'),
  _animal(3, 'vaca', 'pad-1'),
  _animal(4, 'vaca', 'pad-1'),
  _animal(5, 'terneiro', 'pad-2'),
  _animal(6, 'terneiro', 'pad-2'),
];

final _atfOutubro = AtfSummary(
  atf: AtfBatch(
    id: 'atf-1',
    propertyId: 'prop-1',
    name: 'ATF Outubro',
    implantationDate: DateTime(2026, 7, 1),
    inseminationDate: DateTime(2026, 7, 10),
    active: true,
    createdAt: DateTime(2026, 7, 1),
  ),
  animalCount: 25,
  dgSummary: const DgSummary(pregnant: 11, total: 18, pending: 7),
);

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState?> build() async => null;
}

Widget _buildScreen({
  List<Paddock> paddocks = const [],
  List<AnimalWithContext> animals = const [],
  List<AtfSummary> atfs = const [],
  MonthExpenses month = const MonthExpenses(total: 0, perAnimal: null),
  PropertyMembership membership = _vetMembership,
  Override? inviteOverride,
}) {
  return ProviderScope(
    overrides: [
      memberPropertiesProvider.overrideWith((ref) async => [membership]),
      authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
      paddockListProvider.overrideWith((ref) async => paddocks),
      animalListByPropertyProvider.overrideWith((ref) async => animals),
      atfListByPropertyProvider.overrideWith((ref) async => atfs),
      monthExpensesProvider.overrideWith((ref) async => month),
      inviteOverride ?? myInvitesProvider.overrideWith((ref) async => const []),
    ],
    child: const MaterialApp(
      localizationsDelegates: [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      home: DashboardScreen(),
    ),
  );
}

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('mobile: KPIs, banner com DGs pendentes e piquete estourado',
      (tester) async {
    _setSize(tester, const Size(400, 900));
    await tester.pumpWidget(_buildScreen(
      paddocks: [_paddockOver, _paddockOk],
      animals: _animals,
      atfs: [_atfOutubro],
      month: const MonthExpenses(total: 12480.0, perAnimal: 57.78),
    ));
    await tester.pumpAndSettle();

    // KPIs do header verde
    expect(find.text('6'), findsOneWidget); // animais ativos
    expect(find.text('5,0'), findsOneWidget); // UA no rebanho
    expect(find.text('0,16'), findsOneWidget); // 5,0 UA / 30,5 ha
    expect(find.text('Veterinário'), findsOneWidget); // role badge

    // Banner: DG pendente por ATF ativo + piquete acima da capacidade
    expect(find.text('PRECISA DE VOCÊ HOJE'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('DGs pendentes no ATF Outubro'), findsOneWidget);
    expect(find.text('1,0'), findsOneWidget); // 4,0 − 3,0 UA de excesso
    expect(find.text('UA acima da capacidade no Piquete 3'), findsOneWidget);

    // Lotação por piquete (ordenado pelo mais lotado)
    expect(find.text('Lotação por piquete'), findsOneWidget);
    expect(find.text('4,0 / 3,0'), findsOneWidget);
    expect(find.text('1,0 / 12,0'), findsOneWidget);

    // Prenhez + Gastos
    expect(find.text('11 de 18 DGs · ATF Outubro'), findsOneWidget);
    expect(find.text('R\$ 12.480,00'), findsOneWidget);
    expect(find.text('R\$ 57,78 por animal'), findsOneWidget);
  });

  testWidgets('mobile: sem dados — banner oculto, estados vazios, sem crash',
      (tester) async {
    _setSize(tester, const Size(400, 900));
    await tester.pumpWidget(_buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('PRECISA DE VOCÊ HOJE'), findsNothing);
    expect(find.text('0'), findsOneWidget); // 0 animais ativos
    expect(find.text('Nenhum piquete cadastrado.'), findsOneWidget);
    expect(find.text('Nenhum ATF ativo.'), findsOneWidget);
    expect(find.text('R\$ 0,00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile: banner oculto quando ATF ativo não tem DG pendente',
      (tester) async {
    _setSize(tester, const Size(400, 900));
    final completeAtf = AtfSummary(
      atf: _atfOutubro.atf,
      animalCount: 18,
      dgSummary: const DgSummary(pregnant: 11, total: 18, pending: 0),
    );
    await tester.pumpWidget(_buildScreen(
      paddocks: [_paddockOk],
      animals: [_animal(1, 'vaca', 'pad-2')],
      atfs: [completeAtf],
    ));
    await tester.pumpAndSettle();

    expect(find.text('PRECISA DE VOCÊ HOJE'), findsNothing);
    expect(find.text('11 de 18 DGs · ATF Outubro'), findsOneWidget);
  });

  testWidgets('desktop (>=600px): header "Bom dia" + grid 2 colunas',
      (tester) async {
    _setSize(tester, const Size(1000, 800));
    await tester.pumpWidget(_buildScreen(
      paddocks: [_paddockOver, _paddockOk],
      animals: _animals,
      atfs: [_atfOutubro],
      month: const MonthExpenses(total: 12480.0, perAnimal: 57.78),
    ));
    await tester.pumpAndSettle();

    // Header desktop: saudação + fazenda · data longa + 3 KPIs à direita
    expect(
      find.textContaining(RegExp('^(Bom dia|Boa tarde|Boa noite)')),
      findsOneWidget,
    );
    expect(find.textContaining('Fazenda Alpha · '), findsOneWidget);
    expect(find.text('animais ativos'), findsOneWidget);
    expect(find.text('UA no rebanho'), findsOneWidget);
    expect(find.text('UA/ha média'), findsOneWidget);

    // Banner desktop com itens em cards brancos
    expect(find.text('PRECISA DE VOCÊ HOJE'), findsOneWidget);
    expect(find.text('DGs pendentes no ATF Outubro'), findsOneWidget);

    // Grid: Lotação (col A) + Prenhez/Gastos (col B)
    expect(find.text('Lotação por piquete'), findsOneWidget);
    expect(find.text('11 de 18 DGs · ATF Outubro'), findsOneWidget);
    expect(find.text('R\$ 12.480,00'), findsOneWidget);
  });

  // ---------------------------------------------------------------------
  // MEMB-01 — banner de convites pendentes (10-09)
  // ---------------------------------------------------------------------

  testWidgets('mobile: sem convites, nenhum InviteBanner é renderizado',
      (tester) async {
    _setSize(tester, const Size(400, 900));
    await tester.pumpWidget(_buildScreen());
    await tester.pumpAndSettle();

    expect(find.byType(InviteBanner), findsNothing);
  });

  testWidgets(
      'mobile: um convite pendente mostra InviteBanner acima do '
      '_AlertsBanner', (tester) async {
    _setSize(tester, const Size(400, 900));
    await tester.pumpWidget(_buildScreen(
      paddocks: [_paddockOver],
      animals: _animals,
      atfs: [_atfOutubro],
      inviteOverride: myInvitesProvider.overrideWith((ref) async => [_invite1]),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(InviteBanner), findsOneWidget);
    expect(find.text('PRECISA DE VOCÊ HOJE'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(InviteBanner)).dy,
      lessThan(tester.getTopLeft(find.text('PRECISA DE VOCÊ HOJE')).dy),
    );
  });

  testWidgets('mobile: dois convites pendentes mostram dois InviteBanner',
      (tester) async {
    _setSize(tester, const Size(400, 900));
    await tester.pumpWidget(_buildScreen(
      inviteOverride: myInvitesProvider
          .overrideWith((ref) async => [_invite1, _invite2]),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(InviteBanner), findsNWidgets(2));
  });

  testWidgets(
      'mobile: banner de convite aparece mesmo com papel não-veterinário',
      (tester) async {
    _setSize(tester, const Size(400, 900));
    await tester.pumpWidget(_buildScreen(
      membership: _readerMembership,
      inviteOverride: myInvitesProvider.overrideWith((ref) async => [_invite1]),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(InviteBanner), findsOneWidget);
  });

  testWidgets(
      'mobile: myInvitesProvider em erro não renderiza banner e não quebra',
      (tester) async {
    _setSize(tester, const Size(400, 900));
    await tester.pumpWidget(_buildScreen(
      inviteOverride:
          myInvitesProvider.overrideWith((ref) async => throw Exception('x')),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(InviteBanner), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'desktop: convite pendente mostra InviteBanner na coluna principal, '
      'acima do _AlertsBanner', (tester) async {
    _setSize(tester, const Size(1000, 800));
    await tester.pumpWidget(_buildScreen(
      paddocks: [_paddockOver],
      animals: _animals,
      atfs: [_atfOutubro],
      inviteOverride: myInvitesProvider.overrideWith((ref) async => [_invite1]),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(InviteBanner), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(InviteBanner)).dy,
      lessThan(tester.getTopLeft(find.text('PRECISA DE VOCÊ HOJE')).dy),
    );
  });
}
