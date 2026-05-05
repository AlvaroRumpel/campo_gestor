import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../test/test_helper.dart';

/// AUTH-05 / D-08 — cross-tenant isolation negative test.
///
/// Pre-requisite: `supabase start` must be running locally and the seed
/// from supabase/seed.sql must be applied (`supabase db reset`).
///
/// Run with: flutter test integration_test/rls_isolation_test.dart -d windows
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    try {
      await Supabase.initialize(
        url: testSupabaseUrl(),
        anonKey: testSupabaseAnonKey(),
      );
    } catch (e) {
      // Already initialized — ignore.
    }
  });

  test('userA cannot read property_members rows belonging to userB', () async {
    final client = Supabase.instance.client;

    // Sign in as user A
    final aResp = await client.auth.signInWithPassword(
      email: 'userA@test.com',
      password: 'senha123A',
    );
    expect(aResp.session, isNotNull,
        reason: 'Seed must be applied — supabase db reset before running');

    // Try to read property_members of userB (should return empty due to RLS)
    final rows = await client
        .from('property_members')
        .select()
        .eq('user_id', 'bbbb2222-0000-0000-0000-000000000002');

    expect(rows, isEmpty,
        reason: 'RLS must block userA from seeing userB memberships');

    // Try to read Fazenda Beta (should return empty — userA is not a member)
    final propRows = await client
        .from('propriedades')
        .select()
        .eq('id', 'bbbbbbbb-0000-0000-0000-000000000002');

    expect(propRows, isEmpty,
        reason: 'RLS must block userA from seeing Fazenda Beta');

    await client.auth.signOut();
  }, skip: const bool.fromEnvironment('SKIP_INTEGRATION', defaultValue: false));

  test('userA can read their own property and membership', () async {
    final client = Supabase.instance.client;

    await client.auth.signInWithPassword(
      email: 'userA@test.com',
      password: 'senha123A',
    );

    final ownProp = await client
        .from('propriedades')
        .select()
        .eq('id', 'aaaaaaaa-0000-0000-0000-000000000001');

    expect(ownProp, hasLength(1));
    expect(ownProp.first['nome'], 'Fazenda Alpha');

    await client.auth.signOut();
  }, skip: const bool.fromEnvironment('SKIP_INTEGRATION', defaultValue: false));
}
