import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

/// The error vocabulary the membership/invite write surfaces (Phase 10)
/// branch on — every SQLSTATE the 9 RPCs in `membro_repository.dart` can
/// raise, mapped to one of these reasons plus one authored pt-BR sentence
/// (mirrors `sanitary_application_exception.dart`, D-35's precedent).
enum MembroErrorReason {
  /// SQLSTATE 42501 — the caller is not a veterinarian/owner (or, for
  /// `accept_invite`/`decline_invite`, the invite does not belong to them).
  forbidden,

  /// SQLSTATE 23514 — `assert_not_last_veterinarian` guard: the action would
  /// leave the farm without any veterinarian.
  lastVeterinarian,

  /// SQLSTATE 23505 — the email already has a pending invite, or is already
  /// a member of the property.
  alreadyInvited,

  /// SQLSTATE P0002 — concurrent state changed since the screen loaded
  /// (e.g. an invite was already accepted/declined/revoked).
  staleState,

  /// SQLSTATE 23503 — the referenced row (invite/member) no longer exists.
  notFound,

  /// SQLSTATE 22023 or 22P02 — invalid email or invalid role input.
  invalidInput,

  /// Every other SQLSTATE, or a non-`PostgrestException` error — the
  /// caller-supplied fallback message.
  invalidState,
}

/// A phase-owned exception mapping every SQLSTATE the membership RPCs can
/// raise to one of the [MembroErrorReason]s and one authored pt-BR sentence.
/// No raw database text ever reaches a screen.
class MembroException implements Exception {
  const MembroException(this.reason, this.message);

  final MembroErrorReason reason;
  final String message;

  /// Maps a driver [PostgrestException] to its [MembroException].
  ///
  /// [propertyName] interpolates into the last-veterinarian guard message
  /// when available; [fallbackMessage] covers any SQLSTATE not explicitly
  /// mapped below.
  factory MembroException.fromPostgrest(
    PostgrestException e, {
    required String fallbackMessage,
    String? propertyName,
  }) {
    switch (e.code) {
      case '42501':
        return const MembroException(
          MembroErrorReason.forbidden,
          'Você não tem permissão para esta ação.',
        );
      case '23514':
        return MembroException(
          MembroErrorReason.lastVeterinarian,
          'Não é possível concluir: ${propertyName ?? 'esta fazenda'} ficaria sem nenhum veterinário responsável.',
        );
      case '23505':
        return const MembroException(
          MembroErrorReason.alreadyInvited,
          'Este e-mail já foi convidado ou já é membro desta fazenda.',
        );
      case 'P0002':
        return const MembroException(
          MembroErrorReason.staleState,
          'Não foi possível concluir. Atualize a lista e tente novamente.',
        );
      case '23503':
        return const MembroException(
          MembroErrorReason.notFound,
          'Registro não encontrado. Atualize a lista e tente novamente.',
        );
      case '22023':
      case '22P02':
        return const MembroException(
          MembroErrorReason.invalidInput,
          'Informe um e-mail válido e um papel válido.',
        );
      default:
        return MembroException(MembroErrorReason.invalidState, fallbackMessage);
    }
  }

  @override
  String toString() => message;
}

/// Routes any caught [Object] into a [MembroException] — the one line every
/// catch block in the membros widgets needs.
///
/// Returns [error] unchanged when it already is one, routes a
/// [PostgrestException] through [MembroException.fromPostgrest], and
/// otherwise wraps it as [MembroErrorReason.invalidState] with
/// [fallbackMessage]. Never throws.
MembroException asMembroException(
  Object error, {
  required String fallbackMessage,
  String? propertyName,
}) {
  if (error is MembroException) return error;
  if (error is PostgrestException) {
    return MembroException.fromPostgrest(
      error,
      fallbackMessage: fallbackMessage,
      propertyName: propertyName,
    );
  }
  return MembroException(MembroErrorReason.invalidState, fallbackMessage);
}
