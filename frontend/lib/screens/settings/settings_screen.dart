import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/app_scope.dart';
import '../../widgets/cards/premium_card.dart';
import '../../widgets/layout/atmosphere_background.dart';
import '../../widgets/layout/responsive_body.dart';
import '../../widgets/layout/section_header.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
    final settings = AppScope.settings(context);

    return AtmosphereBackground(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Settings')),
      body: AnimatedBuilder(
        animation: settings,
        builder: (context, child) {
          return ResponsiveBody(
            maxWidth: 640,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                SectionHeader(title: AppStrings.of(context).appearance),
                const SizedBox(height: 12),
                PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.of(context).theme,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 12),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SegmentedButton<ThemeMode>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.dark,
                              label: Text('Dark'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.light,
                              label: Text('Light'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.system,
                              label: Text('System'),
                            ),
                          ],
                          selected: {settings.themeMode},
                          onSelectionChanged: (selected) {
                            settings.setThemeMode(selected.first);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const SectionHeader(title: 'Preferences'),
                const SizedBox(height: 12),
                PremiumCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Notifications'),
                        value: settings.notificationsEnabled,
                        onChanged: settings.setNotifications,
                      ),
                      SwitchListTile(
                        title: const Text('Sound'),
                        value: settings.soundEnabled,
                        onChanged: settings.setSound,
                      ),
                      ListTile(
                        title: Text(AppStrings.of(context).language),
                        subtitle: Text(settings.language),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: SegmentedButton<String>(
                          showSelectedIcon: false,
                          segments: [
                            ButtonSegment(
                              value: 'English',
                              label: Text(AppStrings.of(context).english),
                            ),
                            ButtonSegment(
                              value: 'বাংলা',
                              label: Text(AppStrings.of(context).bengali),
                            ),
                          ],
                          selected: {settings.language},
                          onSelectionChanged: (selected) {
                            settings.setLanguage(selected.first);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const SectionHeader(title: 'Security'),
                const SizedBox(height: 12),
                PremiumCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('Change password'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).pushNamed(
                            AppRoutes.changePassword,
                          );
                        },
                      ),
                      ListTile(
                        title: const Text('Logout'),
                        trailing: const Icon(Icons.logout),
                        onTap: () => _logout(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const SectionHeader(title: 'About'),
                const SizedBox(height: 12),
                PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppConstants.appName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      const Text('Version ${AppConstants.version}'),
                      const SizedBox(height: 4),
                      const Text(AppConstants.tagline),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
    );
  }
}
