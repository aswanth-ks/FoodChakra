import '../domain/account.dart';
import '../domain/account_role.dart';

/// Wire format for the authenticated account (`/auth/me`, and the `user`
/// object inside a token response).
///
/// DTOs own JSON parsing and convert to a domain entity, so the domain stays
/// independent of the API shape.
class AccountDto {
  const AccountDto({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.status,
    required this.emailVerified,
    required this.isStaff,
    this.partnerId,
    this.createdAt,
  });

  final String id;
  final String email;
  final String fullName;
  final String role;
  final String status;
  final bool emailVerified;
  final bool isStaff;
  final String? partnerId;
  final DateTime? createdAt;

  factory AccountDto.fromJson(Map<String, dynamic> json) => AccountDto(
    id: json['id'] as String? ?? '',
    email: json['email'] as String? ?? '',
    fullName: json['full_name'] as String? ?? '',
    role: json['role'] as String? ?? 'consumer',
    status: json['status'] as String? ?? 'disabled',
    emailVerified: json['email_verified'] as bool? ?? false,
    isStaff: json['is_staff'] as bool? ?? false,
    partnerId: json['partner_id'] as String?,
    // Tolerates absence and malformed values alike: a profile without a
    // membership date is better than one that refuses to load.
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
  );

  Account toDomain() => Account(
    id: id,
    email: email,
    fullName: fullName,
    role: AccountRole.fromWire(role),
    status: AccountStatus.fromWire(status),
    emailVerified: emailVerified,
    isStaff: isStaff,
    partnerId: partnerId,
    createdAt: createdAt,
  );
}

/// Wire format for register / login / refresh.
class TokenPairDto {
  const TokenPairDto({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final AccountDto user;

  factory TokenPairDto.fromJson(Map<String, dynamic> json) => TokenPairDto(
    accessToken: json['access_token'] as String? ?? '',
    refreshToken: json['refresh_token'] as String? ?? '',
    user: AccountDto.fromJson(
      (json['user'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
  );
}
