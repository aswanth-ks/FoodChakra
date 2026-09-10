/// Which side of FoodLoop an account belongs to.
///
/// There is one sign-in screen for everyone; the account decides which app
/// they land in. Consumers rescue and share food; partners are businesses
/// (restaurants, caterers, hotels) whose access is granted from the ops
/// console, not by signing up in the app.
///
/// **The server decides this, and only the server.** The role arrives on the
/// authenticated session from `GET /api/v1/auth/me` and is stored on
/// [Account]. The previous `roleForEmail()` helper — which read the email's
/// domain — was deleted in Stage C: a client-side check like that is bypassed
/// by typing a different address, so it must never be what protects partner
/// data.
enum AccountRole {
  consumer,
  partner;

  bool get isPartner => this == AccountRole.partner;

  /// Parses the server's wire value.
  ///
  /// An unrecognised role degrades to [consumer], the least-privileged option.
  /// Failing closed matters: a future server role this build has never heard
  /// of must not fall through to partner access.
  static AccountRole fromWire(String? value) => switch (value) {
    'partner' => AccountRole.partner,
    _ => AccountRole.consumer,
  };
}

/// Whether an account may sign in, as decided by the backend.
enum AccountStatus {
  active,
  suspended,
  disabled;

  static AccountStatus fromWire(String? value) => switch (value) {
    'active' => AccountStatus.active,
    'suspended' => AccountStatus.suspended,
    _ => AccountStatus.disabled,
  };
}
