import 'package:flutter_test/flutter_test.dart';

import 'package:campo_gestor/features/membros/data/membro_models.dart';

void main() {
  group('PropertyMember.fromJson', () {
    test('produces the five fields with DateTime/bool coercion', () {
      final member = PropertyMember.fromJson({
        'user_id': 'u1',
        'email': 'vet@example.com',
        'role': 'veterinarian',
        'created_at': '2026-08-14T10:00:00Z',
        'is_self': true,
      });

      expect(member.userId, 'u1');
      expect(member.email, 'vet@example.com');
      expect(member.role, 'veterinarian');
      expect(member.createdAt, DateTime.parse('2026-08-14T10:00:00Z'));
      expect(member.isSelf, true);
    });

    test('missing is_self defaults to false without throwing', () {
      final member = PropertyMember.fromJson({
        'user_id': 'u1',
        'email': 'vet@example.com',
        'role': 'veterinarian',
        'created_at': '2026-08-14T10:00:00Z',
      });

      expect(member.isSelf, false);
    });
  });

  group('Invite.fromJson', () {
    test('produces the seven fields', () {
      final invite = Invite.fromJson({
        'id': 'i1',
        'property_id': 'p1',
        'invited_email': 'novo@example.com',
        'role': 'owner',
        'status': 'pending',
        'invited_by': 'u1',
        'created_at': '2026-08-14T10:00:00Z',
        'resolved_at': null,
      });

      expect(invite.id, 'i1');
      expect(invite.propertyId, 'p1');
      expect(invite.invitedEmail, 'novo@example.com');
      expect(invite.role, 'owner');
      expect(invite.status, 'pending');
      expect(invite.invitedBy, 'u1');
      expect(invite.createdAt, DateTime.parse('2026-08-14T10:00:00Z'));
      expect(invite.resolvedAt, isNull);
    });

    test('null resolved_at produces resolvedAt == null', () {
      final invite = Invite.fromJson({
        'id': 'i1',
        'property_id': 'p1',
        'invited_email': 'novo@example.com',
        'role': 'owner',
        'status': 'pending',
        'invited_by': 'u1',
        'created_at': '2026-08-14T10:00:00Z',
      });

      expect(invite.resolvedAt, isNull);
    });
  });

  group('MyInvite.fromJson', () {
    test('produces propertyName filled', () {
      final myInvite = MyInvite.fromJson({
        'id': 'i1',
        'property_id': 'p1',
        'property_name': 'Fazenda X',
        'role': 'reader',
        'created_at': '2026-08-14T10:00:00Z',
      });

      expect(myInvite.id, 'i1');
      expect(myInvite.propertyId, 'p1');
      expect(myInvite.propertyName, 'Fazenda X');
      expect(myInvite.role, 'reader');
      expect(myInvite.createdAt, DateTime.parse('2026-08-14T10:00:00Z'));
    });
  });

  group('roleLabel', () {
    test('maps the three known roles', () {
      expect(roleLabel('veterinarian'), 'Veterinário');
      expect(roleLabel('owner'), 'Proprietário');
      expect(roleLabel('reader'), 'Leitor');
    });

    test('unknown value returns itself', () {
      expect(roleLabel('alien'), 'alien');
    });
  });

  group('inviteStatusLabel', () {
    test('maps the four known statuses', () {
      expect(inviteStatusLabel('pending'), 'Pendente');
      expect(inviteStatusLabel('accepted'), 'Aceito');
      expect(inviteStatusLabel('declined'), 'Recusado');
      expect(inviteStatusLabel('revoked'), 'Revogado');
    });

    test('unknown value returns itself', () {
      expect(inviteStatusLabel('mystery'), 'mystery');
    });
  });
}
