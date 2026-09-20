import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/services/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_utils.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../widgets/buttons/secondary_button.dart';
import '../../widgets/cards/premium_card.dart';
import '../../widgets/layout/responsive_body.dart';
import '../../widgets/layout/section_header.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await AppScope.auth(context).logout();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AppScope.auth(context).user;
    final colors = context.tpColors;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Profile'),
        automaticallyImplyLeading: false,
      ),
      body: ResponsiveBody(
        maxWidth: 760,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            PremiumCard(
              emphasized: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: scheme.primary.withValues(alpha: 0.18),
                    child: Text(
                      user?.initials ?? 'TP',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? 'Trader',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        if ((user?.username ?? '').isNotEmpty)
                          Text('@${user!.username}'),
                        Text(user?.email ?? ''),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(
                              label: Text(
                                AppScope.settings(context).isLiveMode
                                    ? 'LIVE'
                                    : 'DEMO',
                              ),
                            ),
                            Chip(
                              label: Text(
                                'Member since ${user == null ? '—' : AppUtils.formatMemberSince(user.memberSince)}',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Personal information'),
            const SizedBox(height: 10),
            PremiumCard(
              child: Column(
                children: [
                  _InfoRow('Full name', user?.fullName ?? '—'),
                  _InfoRow('Username', (user?.username ?? '').isEmpty ? 'Not set' : user!.username),
                  _InfoRow('Phone', (user?.phone ?? '').isEmpty ? 'Not set' : user!.phone),
                  _InfoRow(
                    'Date of birth',
                    user?.dateOfBirth == null
                        ? 'Not set'
                        : AppUtils.formatMemberSince(user!.dateOfBirth!),
                  ),
                  _InfoRow('Gender', (user?.gender ?? '').isEmpty ? 'Not set' : user!.gender),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Address'),
            const SizedBox(height: 10),
            PremiumCard(
              child: Column(
                children: [
                  _InfoRow('Country', _orUnset(user?.country)),
                  _InfoRow('Division / State', _orUnset(user?.division)),
                  _InfoRow('District', _orUnset(user?.district)),
                  _InfoRow('Thana / Upazila', _orUnset(user?.thana)),
                  _InfoRow('City', _orUnset(user?.city)),
                  _InfoRow('Area', _orUnset(user?.area)),
                  _InfoRow('Full address', _orUnset(user?.fullAddress)),
                  _InfoRow('Postal code', _orUnset(user?.postalCode)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Account'),
            const SizedBox(height: 10),
            PremiumCard(
              child: Text(
                'Manage personal details, security, and preferences.',
                style: TextStyle(color: colors.mutedText),
              ),
            ),
            const SizedBox(height: 16),
            SecondaryButton(
              label: 'Edit Profile',
              onPressed: () {
                Navigator.of(context).pushNamed(AppRoutes.editProfile);
              },
            ),
            const SizedBox(height: 8),
            SecondaryButton(
              label: 'Change Password',
              onPressed: () {
                Navigator.of(context).pushNamed(AppRoutes.changePassword);
              },
            ),
            const SizedBox(height: 8),
            SecondaryButton(
              label: 'Settings & preferences',
              onPressed: () {
                Navigator.of(context).pushNamed(AppRoutes.settings);
              },
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Logout',
              onPressed: () => _logout(context),
            ),
          ],
        ),
      ),
    );
  }

  static String _orUnset(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Not set' : value;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
