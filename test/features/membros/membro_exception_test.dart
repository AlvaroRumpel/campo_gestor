import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:campo_gestor/features/membros/data/membro_exception.dart';

void main() {
  group('MembroException.fromPostgrest', () {
    test('23514 with propertyName interpolates the farm name', () {
      final e = MembroException.fromPostgrest(
        const PostgrestException(message: 'x', code: '23514'),
        fallbackMessage: 'fallback',
        propertyName: 'Fazenda X',
      );

      expect(e.reason, MembroErrorReason.lastVeterinarian);
      expect(
        e.message,
        'Não é possível concluir: Fazenda X ficaria sem nenhum veterinário responsável.',
      );
    });

    test('23514 without propertyName uses "esta fazenda"', () {
      final e = MembroException.fromPostgrest(
        const PostgrestException(message: 'x', code: '23514'),
        fallbackMessage: 'fallback',
      );

      expect(e.reason, MembroErrorReason.lastVeterinarian);
      expect(
        e.message,
        'Não é possível concluir: esta fazenda ficaria sem nenhum veterinário responsável.',
      );
    });

    test('23505 produces alreadyInvited', () {
      final e = MembroException.fromPostgrest(
        const PostgrestException(message: 'x', code: '23505'),
        fallbackMessage: 'fallback',
      );

      expect(e.reason, MembroErrorReason.alreadyInvited);
      expect(e.message, contains('já foi convidado'));
    });

    test('P0002 produces staleState', () {
      final e = MembroException.fromPostgrest(
        const PostgrestException(message: 'x', code: 'P0002'),
        fallbackMessage: 'fallback',
      );

      expect(e.reason, MembroErrorReason.staleState);
    });

    test('42501 produces forbidden', () {
      final e = MembroException.fromPostgrest(
        const PostgrestException(message: 'x', code: '42501'),
        fallbackMessage: 'fallback',
      );

      expect(e.reason, MembroErrorReason.forbidden);
    });

    test('22023 produces invalidInput', () {
      final e = MembroException.fromPostgrest(
        const PostgrestException(message: 'x', code: '22023'),
        fallbackMessage: 'fallback',
      );

      expect(e.reason, MembroErrorReason.invalidInput);
    });

    test('22P02 produces invalidInput', () {
      final e = MembroException.fromPostgrest(
        const PostgrestException(message: 'x', code: '22P02'),
        fallbackMessage: 'fallback',
      );

      expect(e.reason, MembroErrorReason.invalidInput);
    });

    test('23503 produces notFound', () {
      final e = MembroException.fromPostgrest(
        const PostgrestException(message: 'x', code: '23503'),
        fallbackMessage: 'fallback',
      );

      expect(e.reason, MembroErrorReason.notFound);
    });

    test('unknown code produces invalidState with fallbackMessage', () {
      final e = MembroException.fromPostgrest(
        const PostgrestException(message: 'x', code: '99999'),
        fallbackMessage: 'fallback message',
      );

      expect(e.reason, MembroErrorReason.invalidState);
      expect(e.message, 'fallback message');
    });
  });

  group('asMembroException', () {
    test('returns a MembroException unchanged', () {
      const original = MembroException(MembroErrorReason.forbidden, 'x');
      final result = asMembroException(original, fallbackMessage: 'fallback');
      expect(identical(result, original), true);
    });

    test('routes a PostgrestException through fromPostgrest', () {
      final result = asMembroException(
        const PostgrestException(message: 'x', code: '23514'),
        fallbackMessage: 'fallback',
        propertyName: 'Fazenda X',
      );
      expect(result.reason, MembroErrorReason.lastVeterinarian);
    });

    test('non-PostgrestException, non-MembroException produces invalidState '
        'with fallbackMessage', () {
      final result = asMembroException(
        Exception('random'),
        fallbackMessage: 'fallback message',
      );
      expect(result.reason, MembroErrorReason.invalidState);
      expect(result.message, 'fallback message');
    });
  });
}
