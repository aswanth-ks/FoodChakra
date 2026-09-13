import 'package:flutter/material.dart';

import '../../auth/domain/account_role.dart';
import '../../../shared/widgets/consumer_nav_bar.dart';
import 'widgets/rescue_widgets.dart';

/// "FoodLoop Consumer Profile Screen".
///
/// Faithful translation of the Stitch design
/// (screen `1c0764bd3d524834be8cb9cb61e9900f`).
///
/// Every value shown here comes from the signed-in account and the user's own
/// completed records. The name, membership date and counts used to be
/// constructor defaults — a name, "member since 2026", 48 meal boxes and 3
/// shares — which meant every account saw one person's invented figures. They
/// are required parameters now, so there is nothing left for the screen to
/// fall back to and no way to render it without real data.
///
/// Settings rows remain callbacks left null by the router: their destinations
/// genuinely do not exist yet, and an inert row is honest where a placeholder
/// screen would not be.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.name,
    required this.email,
    required this.role,
    required this.emailVerified,
    this.mealBoxesRescued,
    this.foodShares,
    this.statsError,
    this.onRetryStats,
    this.memberSinceLabel,
    this.versionLabel = 'FoodLoop Version 2.4.0 · Consumer Edition',
    this.onBack,
    this.onEditProfile,
    this.onPersonalInformation,
    this.onSavedLocations,
    this.onFoodPreferences,
    this.onNotifications,
    this.onPrivacy,
    this.onSafetyInformation,
    this.onHelpCenter,
    this.onContactSupport,
    this.onTerms,
    this.onPrivacyPolicy,
    this.onSignOut,
    this.onSelectTab,
  });

  /// The account holder's name, exactly as the server reports it.
  final String name;

  /// The account's email address, from the session — never typed in here.
  final String email;

  /// The server-assigned role. Never inferred from the email address.
  final AccountRole role;

  /// Whether the server considers the address confirmed.
  final bool emailVerified;

  /// Real completed counts. Zero is a true answer and renders as "0".
  ///
  /// Null while they are still being fetched, or when fetching them failed.
  /// The identity above them comes from the session and is already known, so
  /// the page no longer waits on these: it used to sit behind one spinner
  /// until two more requests finished, hiding a name it had in hand the whole
  /// time. A dash is shown rather than a zero, because zero is a claim.
  final int? mealBoxesRescued;
  final int? foodShares;

  /// Non-null when the counts could not be loaded. The rest of Profile still
  /// works; only this strip reports a problem and offers a retry.
  final Object? statsError;

  final VoidCallback? onRetryStats;

  /// "FoodLoop member since 2026", or null when the server gave no creation
  /// date — in which case the line is omitted rather than invented.
  final String? memberSinceLabel;

  final String versionLabel;

  /// Null when the screen is the nav-tab root, which has nothing to pop.
  final VoidCallback? onBack;

  final VoidCallback? onEditProfile;
  final VoidCallback? onPersonalInformation;
  final VoidCallback? onSavedLocations;
  final VoidCallback? onFoodPreferences;
  final VoidCallback? onNotifications;
  final VoidCallback? onPrivacy;
  final VoidCallback? onSafetyInformation;
  final VoidCallback? onHelpCenter;
  final VoidCallback? onContactSupport;
  final VoidCallback? onTerms;
  final VoidCallback? onPrivacyPolicy;

  /// Invoked once the user confirms in the dialog, never straight from the
  /// button — signing out is destructive and the design offers no undo.
  final VoidCallback? onSignOut;

  final void Function(ConsumerTab tab)? onSelectTab;

  /// "Aswanth" -> "A".
  String get _monogram =>
      name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RescueColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Sign out?',
          style: rescueFont(17, 600, color: RescueColors.ink),
        ),
        content: Text(
          'You will need to sign in again to rescue or share food.',
          style: rescueFont(14, 400, color: RescueColors.muted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: rescueFont(14, 500, color: RescueColors.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Sign out',
              style: rescueFont(14, 600, color: _destructive),
            ),
          ),
        ],
      ),
    );

    if (confirmed ?? false) onSignOut?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RescueColors.surface,
      bottomNavigationBar: ConsumerNavBar(
        current: ConsumerTab.profile,
        onSelect: onSelectTab,
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                _ProfileAppBar(onBack: onBack),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    children: [
                      _IdentityCard(
                        monogram: _monogram,
                        name: name,
                        email: email,
                        role: role,
                        emailVerified: emailVerified,
                        memberSinceLabel: memberSinceLabel,
                        onEditProfile: onEditProfile,
                      ),
                      const SizedBox(height: 24),
                      _ContributionCard(
                        mealBoxesRescued: mealBoxesRescued,
                        foodShares: foodShares,
                        error: statsError,
                        onRetry: onRetryStats,
                      ),
                      const SizedBox(height: 24),
                      _SettingsSection(
                        title: 'Account',
                        entries: [
                          _MenuEntry(
                            icon: Icons.person_outline_rounded,
                            title: 'Personal information',
                            subtitle: 'Name and email',
                            onTap: onPersonalInformation,
                          ),
                          _MenuEntry(
                            icon: Icons.location_on_outlined,
                            title: 'Saved locations',
                            subtitle: 'Manage pickup locations',
                            onTap: onSavedLocations,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _SettingsSection(
                        title: 'Preferences',
                        entries: [
                          _MenuEntry(
                            icon: Icons.restaurant_menu_rounded,
                            title: 'Food preferences',
                            subtitle: 'Dietary and rescue preferences',
                            onTap: onFoodPreferences,
                          ),
                          _MenuEntry(
                            icon: Icons.notifications_none_rounded,
                            title: 'Notifications',
                            subtitle: 'Rescue updates and reminders',
                            onTap: onNotifications,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _SettingsSection(
                        title: 'Privacy & safety',
                        entries: [
                          _MenuEntry(
                            icon: Icons.lock_outline_rounded,
                            title: 'Privacy',
                            subtitle: 'Location and account privacy',
                            onTap: onPrivacy,
                          ),
                          _MenuEntry(
                            icon: Icons.shield_outlined,
                            title: 'Safety information',
                            subtitle: 'Food rescue safety guidance',
                            onTap: onSafetyInformation,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _SettingsSection(
                        title: 'Help & support',
                        entries: [
                          _MenuEntry(
                            icon: Icons.help_outline_rounded,
                            title: 'Help center',
                            subtitle: 'Get answers to common questions',
                            onTap: onHelpCenter,
                          ),
                          _MenuEntry(
                            icon: Icons.chat_bubble_outline_rounded,
                            title: 'Contact support',
                            subtitle: 'Need help with FoodLoop?',
                            onTap: onContactSupport,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _SettingsSection(
                        title: 'About',
                        entries: [
                          _MenuEntry(
                            icon: Icons.description_outlined,
                            title: 'Terms of service',
                            onTap: onTerms,
                          ),
                          _MenuEntry(
                            icon: Icons.privacy_tip_outlined,
                            title: 'Privacy policy',
                            onTap: onPrivacyPolicy,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _SignOutButton(onPressed: () => _confirmSignOut(context)),
                      const SizedBox(height: 12),
                      Text(
                        versionLabel,
                        textAlign: TextAlign.center,
                        style: rescueFont(11, 400, color: _version),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const Color _sage = Color(0xFFEAF1EC);
const Color _chevron = Color(0xFFA3ACA5);
const Color _divider = Color(0xFFF2F0EB);
const Color _destructive = Color(0xFFB93838);
const Color _destructiveBorder = Color(0xFFF3DEDE);
const Color _version = Color(0xFF9CA7A0);
const Color _labelMuted = Color(0xFF6B7971);

class _ProfileAppBar extends StatelessWidget {
  const _ProfileAppBar({this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0EEE8))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          if (onBack != null)
            RescueIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              tooltip: 'Go back',
              onPressed: onBack,
            )
          else
            const SizedBox(width: 40),
          Expanded(
            child: Text(
              'Profile',
              textAlign: TextAlign.center,
              style: rescueFont(
                17,
                600,
                color: RescueColors.ink,
                letterSpacing: -0.3,
              ),
            ),
          ),
          // Balancer, mirroring the design's empty right slot.
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.monogram,
    required this.name,
    required this.email,
    required this.role,
    required this.emailVerified,
    required this.memberSinceLabel,
    this.onEditProfile,
  });

  final String monogram;
  final String name;
  final String email;
  final AccountRole role;
  final bool emailVerified;
  final String? memberSinceLabel;
  final VoidCallback? onEditProfile;

  @override
  Widget build(BuildContext context) {
    return RescueCard(
      radius: 16,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: RescueColors.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              monogram,
              style: rescueFont(
                20,
                700,
                color: Colors.white,
                letterSpacing: -0.4,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: rescueFont(
                    19,
                    700,
                    color: RescueColors.ink,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: rescueFont(12.5, 400, color: RescueColors.muted),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _RoleChip(role: role),
                    if (!emailVerified) ...[
                      const SizedBox(width: 6),
                      Text(
                        'Unverified',
                        style: rescueFont(11, 600, color: _destructive),
                      ),
                    ],
                  ],
                ),
                // Omitted entirely when the server gave no creation date.
                if (memberSinceLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    memberSinceLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: rescueFont(12, 400, color: _labelMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onEditProfile,
            style: TextButton.styleFrom(
              foregroundColor: RescueColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Edit profile',
              style: rescueFont(13, 600, color: RescueColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

/// The server-assigned role, shown as given. There are two, and neither is
/// derived on the client.
class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final AccountRole role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: RescueColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        role.isPartner ? 'Partner' : 'Consumer',
        style: rescueFont(11, 600, color: RescueColors.primary),
      ),
    );
  }
}

class _ContributionCard extends StatelessWidget {
  const _ContributionCard({
    required this.mealBoxesRescued,
    required this.foodShares,
    this.error,
    this.onRetry,
  });

  final int? mealBoxesRescued;
  final int? foodShares;
  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return RescueCard(
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LIFETIME CONTRIBUTION',
                style: rescueFont(
                  11,
                  700,
                  color: _labelMuted,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                // Says what it actually is. Calling an unknown figure a
                // "verified count" is the sort of small lie that makes a
                // whole screen untrustworthy.
                error != null
                    ? 'Unavailable'
                    : (mealBoxesRescued == null
                          ? 'Loading'
                          : 'Verified count'),
                style: rescueFont(11, 400, color: const Color(0xFF8A978F)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  value: mealBoxesRescued?.toString() ?? '—',
                  label: 'Meal boxes rescued',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  value: foodShares?.toString() ?? '—',
                  label: 'Food shares',
                ),
              ),
            ],
          ),
          // Only this strip failed. The name, email and settings above it are
          // unaffected and stay usable.
          if (error != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Couldn't load your totals.",
                    style: rescueFont(12, 400, color: _labelMuted),
                  ),
                ),
                if (onRetry != null)
                  TextButton(
                    onPressed: onRetry,
                    style: TextButton.styleFrom(
                      foregroundColor: RescueColors.primary,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Try again',
                      style: rescueFont(12, 600, color: RescueColors.primary),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RescueColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0EEE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: rescueFont(
              26,
              800,
              color: RescueColors.primary,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: rescueFont(12, 500, color: RescueColors.muted),
          ),
        ],
      ),
    );
  }
}

/// One row in a settings group.
class _MenuEntry {
  const _MenuEntry({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;

  /// Absent on the About rows, which are single-line in the design.
  final String? subtitle;

  final VoidCallback? onTap;
}

/// Uppercase heading plus a white card of hairline-divided rows.
class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.entries});

  final String title;
  final List<_MenuEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: rescueFont(13, 700, color: _labelMuted, letterSpacing: 0.9),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: RescueColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: RescueColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08141A1A),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, thickness: 1, color: _divider),
                  _SettingsRow(entry: entries[i]),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.entry});

  final _MenuEntry entry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: entry.onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              IconTile(
                icon: entry.icon,
                size: 40,
                iconSize: 20,
                background: _sage,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: rescueFont(
                        15,
                        600,
                        color: RescueColors.ink,
                        height: 1.2,
                      ),
                    ),
                    if (entry.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        entry.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: rescueFont(12, 400, color: _labelMuted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: _chevron,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.logout_rounded, size: 18, color: _destructive),
        label: Text(
          'Sign out',
          style: rescueFont(14, 600, color: _destructive),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: RescueColors.card,
          side: const BorderSide(color: _destructiveBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
