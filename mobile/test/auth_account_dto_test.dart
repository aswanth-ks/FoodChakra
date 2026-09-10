import 'package:flutter_test/flutter_test.dart';
import 'package:foodloop/features/auth/data/auth_dto.dart';
import 'package:foodloop/features/auth/domain/account_role.dart';

void main() {
  Map<String, dynamic> payload({
    String email = 'someone@foodloop.com',
    String role = 'consumer',
  }) => {
    'id': '68c0f1',
    'email': email,
    'full_name': 'Asha Rao',
    'role': role,
    'status': 'active',
    'email_verified': false,
    'is_staff': false,
    'partner_id': null,
  };

  test('the role comes from the server, never from the email address', () {
    // A foodloop.com address the server calls a consumer stays a consumer.
    final account = AccountDto.fromJson(payload()).toDomain();

    expect(account.role, AccountRole.consumer);
    expect(account.isPartner, isFalse);
  });

  test('a partner account is recognised from the server field', () {
    final account = AccountDto.fromJson(
      payload(email: 'kitchen@example.com', role: 'partner'),
    ).toDomain();

    expect(account.role, AccountRole.partner);
    expect(account.isPartner, isTrue);
  });

  test('a malformed payload degrades to the least-privileged account', () {
    final account = AccountDto.fromJson(const {}).toDomain();

    expect(account.role, AccountRole.consumer);
    expect(account.status, AccountStatus.disabled);
    expect(account.isStaff, isFalse);
  });

  test('token responses carry both tokens and the account', () {
    final tokens = TokenPairDto.fromJson({
      'access_token': 'a',
      'refresh_token': 'r',
      'user': payload(role: 'partner'),
    });

    expect(tokens.accessToken, 'a');
    expect(tokens.refreshToken, 'r');
    expect(tokens.user.toDomain().isPartner, isTrue);
  });
}
