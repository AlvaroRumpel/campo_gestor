import 'package:campo_gestor/core/services/supabase_service.dart';
import 'package:campo_gestor/features/auth/data/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseService extends Mock implements SupabaseService {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _FakeUserAttributes extends Fake implements UserAttributes {}

void main() {
  late _MockSupabaseService service;
  late _MockGoTrueClient auth;
  late AuthRepository repo;

  setUpAll(() {
    registerFallbackValue(_FakeUserAttributes());
  });

  setUp(() {
    service = _MockSupabaseService();
    auth = _MockGoTrueClient();
    when(() => service.auth).thenReturn(auth);
    repo = AuthRepository(service);
  });

  test('signUp delegates to GoTrueClient.signUp with email and password',
      () async {
    when(() => auth.signUp(email: any(named: 'email'), password: any(named: 'password')))
        .thenAnswer((_) async => AuthResponse(session: null, user: null));

    await repo.signUp(email: 'a@b.com', password: 'pass1234');

    verify(() => auth.signUp(email: 'a@b.com', password: 'pass1234')).called(1);
  });

  test('signIn delegates to signInWithPassword', () async {
    when(() => auth.signInWithPassword(
            email: any(named: 'email'), password: any(named: 'password')))
        .thenAnswer((_) async => AuthResponse(session: null, user: null));

    await repo.signIn(email: 'a@b.com', password: 'pass1234');

    verify(() => auth.signInWithPassword(email: 'a@b.com', password: 'pass1234'))
        .called(1);
  });

  test('signOut delegates to GoTrueClient.signOut', () async {
    when(() => auth.signOut()).thenAnswer((_) async {});
    await repo.signOut();
    verify(() => auth.signOut()).called(1);
  });

  test('resetPasswordForEmail uses configured redirect URL', () async {
    when(() => auth.resetPasswordForEmail(any(),
            redirectTo: any(named: 'redirectTo')))
        .thenAnswer((_) async {});

    await repo.resetPasswordForEmail('a@b.com');

    verify(() => auth.resetPasswordForEmail('a@b.com',
        redirectTo: 'http://127.0.0.1:3000/reset-password')).called(1);
  });

  test('updatePassword calls updateUser with new password', () async {
    when(() => auth.updateUser(any())).thenAnswer(
      (_) async => UserResponse.fromJson({
        'id': '',
        'aud': '',
        'created_at': '',
        'app_metadata': <String, dynamic>{},
      }),
    );

    await repo.updatePassword('newpass1');

    verify(() => auth.updateUser(any(that: isA<UserAttributes>()))).called(1);
  });
}
