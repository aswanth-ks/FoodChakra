import 'account_role.dart';

/// The signed-in account, exactly as the backend reports it.
///
/// Every field here is server-supplied. Nothing about identity or permission
/// is derived on the client — see [AccountRole] for why.
class Account {
  const Account({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.status,
    required this.emailVerified,
    this.isStaff = false,
    this.partnerId,
  });

  final String id;
  final String email;
  final String fullName;
  final AccountRole role;
  final AccountStatus status;
  final bool emailVerified;

  /// Whether the account may open the operations console. Not used by the
  /// mobile app; carried so the session shape matches the API.
  final bool isStaff;

  /// The business this account acts for. Non-null only for partners.
  final String? partnerId;

  bool get isPartner => role.isPartner;
}
