/// Which side of FoodLoop an account belongs to.
///
/// There is one sign-in screen for everyone; the account decides which app
/// they land in. Consumers rescue and share food; partners are businesses
/// (restaurants, caterers, hotels) whose access is granted from the ops
/// console, not by signing up in the app.
enum AccountRole {
  consumer,
  partner;

  bool get isPartner => this == AccountRole.partner;
}

/// The email domain that marks a partner account.
const String kPartnerEmailDomain = 'foodloop.com';

/// Decides an account's role from the email it signed in with.
///
/// **This is a stand-in, not authorization.** A partner is really a business
/// that the ops console has granted access to, and only the server can say
/// whether a given account holds that grant. Until the Phase 3 auth service
/// exists there is no server to ask, so the domain stands in for the grant so
/// the partner app is reachable and testable.
///
/// Phase 3 replaces this with the role claim on the authenticated session and
/// deletes the domain rule — a client-side check like this is trivially
/// bypassed by typing a different address, so it must never be what actually
/// protects partner data.
AccountRole roleForEmail(String email) {
  final normalised = email.trim().toLowerCase();
  // Guards against "foodloop.com" appearing anywhere but the domain, e.g.
  // "foodloop.com@example.org".
  final at = normalised.lastIndexOf('@');
  if (at == -1) return AccountRole.consumer;

  final domain = normalised.substring(at + 1);
  return domain == kPartnerEmailDomain
      ? AccountRole.partner
      : AccountRole.consumer;
}
