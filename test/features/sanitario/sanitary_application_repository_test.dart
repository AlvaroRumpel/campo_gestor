// G-06-9 regression test — proves the per-animal containment filter is sent
// as valid JSON at the HTTP request level.
//
// postgrest-dart 2.7.0's `.contains()` branches on the runtime type of the
// value: a String is forwarded verbatim, a List is stringified into a
// Postgres array literal via Dart's Map.toString (never JSON). A Dart List
// can never express jsonb-array containment correctly with this client —
// only a pre-encoded JSON String survives. flutter analyze cannot catch
// this; only a test that inspects the outgoing request holds the contract.
//
// Does not mock the Supabase query-builder chain (brittle — see
// lote_repository_test.dart / atf_repository_test.dart headers). Instead a
// loopback HttpServer captures the real request the postgrest client sends.
import 'dart:convert';
import 'dart:io';

import 'package:campo_gestor/core/services/supabase_service.dart';
import 'package:campo_gestor/features/sanitario/data/sanitary_application_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseService extends Mock implements SupabaseService {}

void main() {
  late HttpServer server;
  late SupabaseClient client;
  late MockSupabaseService mockService;
  late SanitaryApplicationRepository repo;
  late String capturedQuery;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      capturedQuery = request.uri.query;
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write('[]');
      await request.response.close();
    });

    client = SupabaseClient('http://127.0.0.1:${server.port}', 'test-anon-key');

    mockService = MockSupabaseService();
    when(() => mockService.client).thenReturn(client);
    repo = SanitaryApplicationRepository(mockService);
  });

  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });

  test('fetchSanitaryHistoryByAnimal sends the containment filter as JSON '
      '(G-06-9)', () async {
    const animalId = '123e4567-e89b-12d3-a456-426614174000';

    await repo.fetchSanitaryHistoryByAnimal(animalId);

    final params = Uri.splitQueryString(capturedQuery);
    final filterValue = params['composition_snapshot'];
    expect(filterValue, isNotNull);
    expect(filterValue, startsWith('cs.'));

    // Structural comparison after jsonDecode, not string equality — this
    // states the contract (valid JSON, one object keyed animal_id) rather
    // than binding to the exact encoding.
    final decoded = jsonDecode(filterValue!.substring('cs.'.length));
    expect(decoded, [
      {'animal_id': animalId},
    ]);
  });
}
