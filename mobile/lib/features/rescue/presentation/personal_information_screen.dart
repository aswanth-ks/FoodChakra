import 'package:flutter/material.dart';

import '../../auth/domain/account_role.dart';
import 'widgets/rescue_widgets.dart';

/// What the server actually holds about this account.
///
/// Every row is a real field from `/auth/me`. Where the backend has nothing,
/// the row says "Not provided" rather than inventing something plausible — a
/// profile that quietly makes up a join date is a profile nobody can trust
/// about anything else either.
class PersonalInformationScreen extends StatelessWidget {
  const PersonalInformationScreen({
    super.key,
    required this.fullName,
    required this.email,
    required this.role,
    required this.emailVerified,
    this.memberSince,
    this.onBack,
    this.onEdit,
  });

  final String fullName;
  final String email;
  final AccountRole role;
  final bool emailVerified;

  /// When the account was created, as the server recorded it. Null for an
  /// older session that predates the field.
  final DateTime? memberSince;

  final VoidCallback? onBack;
  final VoidCallback? onEdit;

  static const List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static String _dateLabel(DateTime when) {
    final local = when.toLocal();
    return '${local.day} ${_months[local.month - 1]} ${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RescueColors.surface,
      appBar: AppBar(
        backgroundColor: RescueColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back, size: 20),
          color: RescueColors.ink,
          tooltip: 'Go back',
        ),
        title: Text(
          'Personal information',
          style: rescueFont(16, 700, color: RescueColors.ink),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            RescueCard(
              radius: 16,
              child: Column(
                children: [
                  _InfoRow(label: 'Full name', value: fullName),
                  const _RowDivider(),
                  _InfoRow(label: 'Email', value: email),
                  const _RowDivider(),
                  _InfoRow(
                    label: 'Email verification',
                    value: emailVerified ? 'Verified' : 'Not verified',
                    valueColor: emailVerified
                        ? RescueColors.primary
                        : const Color(0xFFB3261E),
                  ),
                  const _RowDivider(),
                  _InfoRow(
                    label: 'Account type',
                    // The server's role, shown as given. There are two, and
                    // neither is derived on the client.
                    value: role.isPartner ? 'Partner' : 'Consumer',
                  ),
                  const _RowDivider(),
                  _InfoRow(
                    label: 'Member since',
                    value: memberSince == null
                        ? 'Not provided'
                        : _dateLabel(memberSince!),
                    muted: memberSince == null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'This is everything FoodLoop stores about your account.',
              style: rescueFont(
                12.5,
                400,
                color: RescueColors.muted,
                height: 1.45,
              ),
            ),
            if (onEdit != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: onEdit,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: RescueColors.primary,
                    side: const BorderSide(color: RescueColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Edit profile',
                    style: rescueFont(15, 600, color: RescueColors.primary),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.muted = false,
  });

  final String label;
  final String value;
  final Color? valueColor;

  /// Softens a value that is absent rather than present, so "Not provided"
  /// does not read like a real answer.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: rescueFont(13, 500, color: RescueColors.muted),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: rescueFont(
                13.5,
                muted ? 400 : 600,
                color: valueColor ?? (muted ? RescueColors.muted : RescueColors.ink),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, color: Color(0xFFEDF0EE));
}
