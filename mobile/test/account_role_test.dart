import 'package:flutter_test/flutter_test.dart';
import 'package:foodloop/features/auth/domain/account_role.dart';

void main() {
  group('AccountRole.fromWire', () {
    test('parses the roles the backend issues', () {
      expect(AccountRole.fromWire('consumer'), AccountRole.consumer);
      expect(AccountRole.fromWire('partner'), AccountRole.partner);
      expect(AccountRole.fromWire('partner').isPartner, isTrue);
    });

    test('fails closed on anything unrecognised', () {
      // A role this build has never heard of must not become partner access.
      for (final value in [null, '', 'admin', 'ops_admin', 'PARTNER', 'x']) {
        expect(AccountRole.fromWire(value), AccountRole.consumer, reason: value);
      }
    });
  });

  group('email addresses carry no authority', () {
    test('a foodloop.com address is not a partner role', () {
      // Stage C deleted `roleForEmail()`. This test stands guard over that:
      // the address a user types must never influence what they may do, and
      // the only way to become a partner is for the server to say so.
      expect(AccountRole.fromWire('someone@foodloop.com'), AccountRole.consumer);
    });
  });

  group('AccountStatus.fromWire', () {
    test('parses the statuses the backend issues', () {
      expect(AccountStatus.fromWire('active'), AccountStatus.active);
      expect(AccountStatus.fromWire('suspended'), AccountStatus.suspended);
      expect(AccountStatus.fromWire('disabled'), AccountStatus.disabled);
    });

    test('an unknown status is treated as disabled', () {
      expect(AccountStatus.fromWire(null), AccountStatus.disabled);
      expect(AccountStatus.fromWire('weird'), AccountStatus.disabled);
    });
  });
}
