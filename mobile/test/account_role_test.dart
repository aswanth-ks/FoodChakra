import 'package:flutter_test/flutter_test.dart';
import 'package:foodloop/features/auth/domain/account_role.dart';

void main() {
  group('roleForEmail', () {
    test('a foodloop.com address is a partner', () {
      expect(roleForEmail('name@foodloop.com'), AccountRole.partner);
      expect(roleForEmail('greenleaf@foodloop.com'), AccountRole.partner);
    });

    test('is case- and whitespace-insensitive', () {
      expect(roleForEmail('  Name@FoodLoop.COM '), AccountRole.partner);
    });

    test('any other address is a consumer', () {
      expect(roleForEmail('name@gmail.com'), AccountRole.consumer);
      expect(roleForEmail('name@foodloop.co'), AccountRole.consumer);
      expect(roleForEmail('name@my-foodloop.com'), AccountRole.consumer);
    });

    test('the domain must be the domain, not part of the local name', () {
      // The rule reads the last @-segment, so an address that merely mentions
      // the partner domain cannot claim partner access.
      expect(roleForEmail('foodloop.com@example.org'), AccountRole.consumer);
      expect(roleForEmail('a@foodloop.com@example.org'), AccountRole.consumer);
    });

    test('a malformed address falls back to consumer', () {
      expect(roleForEmail(''), AccountRole.consumer);
      expect(roleForEmail('not-an-email'), AccountRole.consumer);
    });
  });
}
