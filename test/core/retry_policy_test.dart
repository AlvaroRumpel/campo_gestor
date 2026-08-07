// G-06-9 regression test — the app-wide provider retry policy stops
// retrying a deterministic PostgrestException on the first failure, while
// still delegating ordinary (potentially transient) exceptions to
// riverpod's default backoff.
import 'package:campo_gestor/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('providerRetryPolicy (G-06-9)', () {
    test('returns null for a PostgrestException — no retry', () {
      const error = PostgrestException(message: 'invalid input syntax');

      final result = providerRetryPolicy(0, error);

      expect(result, isNull);
    });

    test(
      'delegates an ordinary Exception to ProviderContainer.defaultRetry',
      () {
        // An ordinary Exception, not an Error subclass — defaultRetry
        // refuses to retry Errors, so this must be Exception to exercise
        // the delegating branch for the right reason.
        final error = Exception('transient network failure');

        final result = providerRetryPolicy(0, error);
        final expected = ProviderContainer.defaultRetry(0, error);

        expect(result, isNotNull);
        expect(result, expected);
      },
    );
  });
}
