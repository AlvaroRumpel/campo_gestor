import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_providers.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';
import 'membro_models.dart';

/// Repository for property members and invites (MEMB-01/02/03).
///
/// All Supabase access flows through SupabaseService — this file must NEVER
/// import supabase_flutter directly (D-06). Every write below routes through
/// a SECURITY DEFINER RPC from `20260814_11_membership_lifecycle.sql`; there
/// is no direct INSERT/UPDATE/DELETE grant on `property_members` or
/// `invites`.
class MembroRepository {
  MembroRepository(this._service);
  final SupabaseService _service;

  // ---------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------

  /// All members of [propertyId], including email and the server-computed
  /// `is_self` flag.
  ///
  /// This **cannot** be a `.from('property_members').select()`: the
  /// `members_read_own_memberships` policy only returns the caller's own
  /// row, and `auth.users.email` is not readable by `authenticated`. Must go
  /// through the `list_property_members` RPC.
  Future<List<PropertyMember>> fetchMembers(String propertyId) async {
    final result = await _service.client.rpc(
      'list_property_members',
      params: {'p_property_id': propertyId},
    );
    return (result as List)
        .map((r) => PropertyMember.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Pending invites for [propertyId] — the manager's view, authorized by
  /// the `managers_can_read_property_invites` policy.
  Future<List<Invite>> fetchPropertyInvites(String propertyId) async {
    final rows = await _service.client
        .from('invites')
        .select()
        .eq('property_id', propertyId)
        .eq('status', 'pending')
        .order('created_at');
    return (rows as List)
        .map((r) => Invite.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Pending invites for the current user — the invitee's view.
  ///
  /// Must be an RPC, not a policy read: the invitee is not yet a member, so
  /// RLS on `properties` would hide the farm name that `list_my_invites`
  /// joins in server-side.
  Future<List<MyInvite>> fetchMyInvites() async {
    final result = await _service.client.rpc('list_my_invites');
    return (result as List)
        .map((r) => MyInvite.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------

  Future<void> createInvite({
    required String propertyId,
    required String email,
    required String role,
  }) async {
    await _service.client.rpc('create_invite', params: {
      'p_property_id': propertyId,
      'p_email': email,
      'p_role': role,
    });
  }

  Future<void> revokeInvite(String inviteId) async {
    await _service.client.rpc('revoke_invite', params: {
      'p_invite_id': inviteId,
    });
  }

  /// Accepts the invite identified by [inviteId]. Takes **only** the invite
  /// id — never an email parameter. The server derives the caller's identity
  /// via `current_user_email()`, so the client cannot spoof accepting
  /// someone else's invite.
  Future<void> acceptInvite(String inviteId) async {
    await _service.client.rpc('accept_invite', params: {
      'p_invite_id': inviteId,
    });
  }

  /// Declines the invite identified by [inviteId]. Same identity-derivation
  /// rule as [acceptInvite] — only the invite id, no email parameter.
  Future<void> declineInvite(String inviteId) async {
    await _service.client.rpc('decline_invite', params: {
      'p_invite_id': inviteId,
    });
  }

  Future<void> removeMember({
    required String propertyId,
    required String userId,
  }) async {
    await _service.client.rpc('remove_member', params: {
      'p_property_id': propertyId,
      'p_target_user_id': userId,
    });
  }

  Future<void> updateMemberRole({
    required String propertyId,
    required String userId,
    required String newRole,
  }) async {
    await _service.client.rpc('update_member_role', params: {
      'p_property_id': propertyId,
      'p_target_user_id': userId,
      'p_new_role': newRole,
    });
  }

  Future<void> leaveProperty(String propertyId) async {
    await _service.client.rpc('leave_property', params: {
      'p_property_id': propertyId,
    });
  }
}

final membroRepositoryProvider = Provider<MembroRepository>(
  (ref) => MembroRepository(ref.watch(supabaseServiceProvider)),
);

final propertyMembersProvider =
    FutureProvider.family<List<PropertyMember>, String>(
  (ref, propertyId) =>
      ref.read(membroRepositoryProvider).fetchMembers(propertyId),
);

final propertyInvitesProvider = FutureProvider.family<List<Invite>, String>(
  (ref, propertyId) =>
      ref.read(membroRepositoryProvider).fetchPropertyInvites(propertyId),
);

/// The invitee's own pending invites. Watches [authNotifierProvider] so a
/// session switch (login/logout, switching accounts) reloads the invite
/// list for the newly active user.
final myInvitesProvider = FutureProvider<List<MyInvite>>((ref) {
  ref.watch(authNotifierProvider);
  return ref.read(membroRepositoryProvider).fetchMyInvites();
});
