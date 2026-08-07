import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

/// The whole error vocabulary the three sanitary write surfaces (register,
/// estorno, dose save) branch on (D-35). Four reasons — do not add a fifth.
enum SanitaryApplicationErrorReason {
  /// SQLSTATE 42501 — the caller is not a veterinarian.
  forbidden,

  /// SQLSTATE P0002 — the submitted animal selection no longer matches the
  /// lot's current membership (D-32 concurrency abort).
  compositionChanged,

  /// SQLSTATE P0003 (RPC pre-check) or 23505 (unique-index backstop) — the
  /// application was already reversed.
  alreadyReversed,

  /// Every other SQLSTATE — the caller-supplied fallback message.
  invalidState,
}

/// A phase-owned exception mapping every SQLSTATE the two sanitary RPCs can
/// raise to one of the four [SanitaryApplicationErrorReason]s and one
/// authored pt-BR sentence (D-35). No raw database text ever reaches a
/// screen.
class SanitaryApplicationException implements Exception {
  const SanitaryApplicationException(this.reason, this.message);

  final SanitaryApplicationErrorReason reason;
  final String message;

  /// Maps a driver [PostgrestException] to its
  /// [SanitaryApplicationException].
  ///
  /// [fallbackMessage] is required because the UI-SPEC's copywriting
  /// contract gives three different generic-failure strings — one for
  /// registration, one for estorno, one for dose save — and hard-coding any
  /// single one here would put the wrong sentence on two of the three
  /// screens.
  factory SanitaryApplicationException.fromPostgrest(
    PostgrestException e, {
    required String fallbackMessage,
  }) {
    switch (e.code) {
      case '42501':
        return const SanitaryApplicationException(
          SanitaryApplicationErrorReason.forbidden,
          'Apenas veterinários podem registrar aplicações sanitárias.',
        );
      case 'P0002':
        // The RPC's RAISE EXCEPTION message IS the UI-SPEC's exact copy
        // template ("[N] animais mudaram desde que a tela foi aberta —
        // recarregue.") — authored once, in SQL, never restated as a Dart
        // literal here.
        return SanitaryApplicationException(
          SanitaryApplicationErrorReason.compositionChanged,
          e.message,
        );
      case 'P0003':
      case '23505':
        return const SanitaryApplicationException(
          SanitaryApplicationErrorReason.alreadyReversed,
          'Esta aplicação já foi estornada.',
        );
      default:
        return SanitaryApplicationException(
          SanitaryApplicationErrorReason.invalidState,
          fallbackMessage,
        );
    }
  }

  @override
  String toString() => message;
}

/// Routes any caught [Object] into a [SanitaryApplicationException] — the
/// one line every catch block in the sanitary widgets needs.
///
/// Returns [error] unchanged when it already is one, routes a
/// [PostgrestException] through [SanitaryApplicationException.fromPostgrest],
/// and otherwise wraps it as [SanitaryApplicationErrorReason.invalidState]
/// with [fallbackMessage]. No raw database (or other) error text can reach a
/// screen through this path.
SanitaryApplicationException asSanitaryException(
  Object error, {
  required String fallbackMessage,
}) {
  if (error is SanitaryApplicationException) return error;
  if (error is PostgrestException) {
    return SanitaryApplicationException.fromPostgrest(
      error,
      fallbackMessage: fallbackMessage,
    );
  }
  return SanitaryApplicationException(
    SanitaryApplicationErrorReason.invalidState,
    fallbackMessage,
  );
}
