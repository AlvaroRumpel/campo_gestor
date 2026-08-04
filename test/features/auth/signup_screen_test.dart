import 'package:campo_gestor/features/auth/data/auth_repository.dart';
import 'package:campo_gestor/features/auth/presentation/signup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

GoRouter _buildRouter() => GoRouter(
      initialLocation: '/signup',
      routes: [
        GoRoute(
          path: '/signup',
          builder: (context, state) => const SignupScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) =>
              const Scaffold(body: Text('login-screen')),
        ),
      ],
    );

Widget _buildScreen(AuthRepository repo) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp.router(routerConfig: _buildRouter()),
  );
}

Future<void> _fillAndSubmit(WidgetTester tester) async {
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'), 'a@b.com');
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Senha'), 'pass1234');
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirmar senha'), 'pass1234');
  await tester.tap(find.widgetWithText(FilledButton, 'Criar conta'));
  await tester.pump();
  await tester.pump();
}

void main() {
  late _MockAuthRepository repo;

  setUp(() {
    repo = _MockAuthRepository();
  });

  testWidgets(
      'successful signUp shows confirm-email SnackBar and navigates to /login',
      (tester) async {
    when(() => repo.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenAnswer((_) async => AuthResponse(session: null, user: null));

    await tester.pumpWidget(_buildScreen(repo));
    await _fillAndSubmit(tester);

    expect(find.text('Confirme seu email para ativar a conta'), findsOneWidget);
    expect(find.text('login-screen'), findsOneWidget);
  });

  testWidgets(
      'AuthException on signUp shows the exception message and stays on /signup',
      (tester) async {
    when(() => repo.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenThrow(const AuthException('email already registered'));

    await tester.pumpWidget(_buildScreen(repo));
    await _fillAndSubmit(tester);

    expect(find.text('email already registered'), findsOneWidget);
    expect(find.text('login-screen'), findsNothing);
  });
}
