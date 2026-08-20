/// One row of `list_property_members(p_property_id)`.
///
/// Simple, hand-written models for membership/invite results (Phase 10):
/// these are result shapes returned by RPCs (`list_property_members`,
/// `list_my_invites`) or a plain select (`invites`) — not editable entities —
/// the same category as `PropertyMembership`, `LotWithPaddockName`, and
/// `IatfMembershipView` elsewhere in this project. No freezed/json_serializable
/// codegen (planner decision, 10-03-PLAN.md).
///
/// `role` holds the raw `role_enum` value from Postgres. `isSelf` is computed
/// server-side (`pm.user_id = auth.uid()`) and decides whether the row offers
/// "Sair da fazenda" or "Remover membro".
class PropertyMember {
  const PropertyMember({
    required this.userId,
    required this.email,
    required this.role,
    required this.createdAt,
    required this.isSelf,
  });

  final String userId;
  final String email;
  final String role;
  final DateTime createdAt;
  final bool isSelf;

  factory PropertyMember.fromJson(Map<String, dynamic> json) => PropertyMember(
        userId: json['user_id'] as String,
        email: json['email'] as String,
        role: json['role'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        isSelf: json['is_self'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PropertyMember &&
          other.userId == userId &&
          other.email == email &&
          other.role == role &&
          other.createdAt == createdAt &&
          other.isSelf == isSelf;

  @override
  int get hashCode => Object.hash(userId, email, role, createdAt, isSelf);
}

/// One row of the `invites` table (property-manager view, read via
/// `.from('invites')` under the `managers_can_read_property_invites` policy).
class Invite {
  const Invite({
    required this.id,
    required this.propertyId,
    required this.invitedEmail,
    required this.role,
    required this.status,
    required this.invitedBy,
    required this.createdAt,
    this.resolvedAt,
  });

  final String id;
  final String propertyId;
  final String invitedEmail;
  final String role;
  final String status;
  final String invitedBy;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  factory Invite.fromJson(Map<String, dynamic> json) => Invite(
        id: json['id'] as String,
        propertyId: json['property_id'] as String,
        invitedEmail: json['invited_email'] as String,
        role: json['role'] as String,
        status: json['status'] as String,
        invitedBy: json['invited_by'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        resolvedAt: json['resolved_at'] == null
            ? null
            : DateTime.parse(json['resolved_at'] as String),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Invite &&
          other.id == id &&
          other.propertyId == propertyId &&
          other.invitedEmail == invitedEmail &&
          other.role == role &&
          other.status == status &&
          other.invitedBy == invitedBy &&
          other.createdAt == createdAt &&
          other.resolvedAt == resolvedAt;

  @override
  int get hashCode => Object.hash(
        id,
        propertyId,
        invitedEmail,
        role,
        status,
        invitedBy,
        createdAt,
        resolvedAt,
      );
}

/// One row of `list_my_invites()` — the invitee's own view. Required as an
/// RPC (not a policy read) because the invitee is not yet a member and RLS on
/// `properties` would otherwise hide the farm name.
class MyInvite {
  const MyInvite({
    required this.id,
    required this.propertyId,
    required this.propertyName,
    required this.role,
    required this.createdAt,
  });

  final String id;
  final String propertyId;
  final String propertyName;
  final String role;
  final DateTime createdAt;

  factory MyInvite.fromJson(Map<String, dynamic> json) => MyInvite(
        id: json['id'] as String,
        propertyId: json['property_id'] as String,
        propertyName: json['property_name'] as String,
        role: json['role'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MyInvite &&
          other.id == id &&
          other.propertyId == propertyId &&
          other.propertyName == propertyName &&
          other.role == role &&
          other.createdAt == createdAt;

  @override
  int get hashCode =>
      Object.hash(id, propertyId, propertyName, role, createdAt);
}

/// Maps a raw `role_enum` value to its pt-BR display label. Unknown values
/// are returned unchanged — never throws.
String roleLabel(String role) => switch (role) {
      'veterinarian' => 'Veterinário',
      'owner' => 'Proprietário',
      'reader' => 'Leitor',
      _ => role,
    };

/// Maps a raw `invites.status` value to its pt-BR display label. Unknown
/// values are returned unchanged — never throws.
String inviteStatusLabel(String status) => switch (status) {
      'pending' => 'Pendente',
      'accepted' => 'Aceito',
      'declined' => 'Recusado',
      'revoked' => 'Revogado',
      _ => status,
    };
