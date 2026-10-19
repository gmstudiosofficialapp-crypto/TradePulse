import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradepulse_frontend/core/services/app_scope.dart';
import 'package:tradepulse_frontend/core/services/auth_controller.dart';
import 'package:tradepulse_frontend/core/services/local_auth_service.dart';
import 'package:tradepulse_frontend/core/services/settings_controller.dart';
import 'package:tradepulse_frontend/core/theme/app_theme.dart';
import 'package:tradepulse_frontend/models/user_profile.dart';
import 'package:tradepulse_frontend/screens/profile/profile_screen.dart';

void main() {
  test('server profile merge keeps filled fields and ignores blanks', () {
    final current = UserProfile(
      uid: 'u1',
      fullName: 'Local Name',
      email: 'ada@example.com',
      memberSince: DateTime.utc(2026, 1, 1),
      username: 'keep-me',
    );
    final merged = UserProfile.fromServer({
      'uid': 'u1',
      'displayName': 'Ada Trader',
      'email': 'ada@example.com',
      'username': '',
      'phone': '01712345678',
      'country': 'Bangladesh',
    }, current: current);
    expect(merged.fullName, 'Ada Trader');
    expect(merged.username, 'keep-me');
    expect(merged.phone, '01712345678');
    expect(merged.country, 'Bangladesh');
  });

  testWidgets('profile badge follows the selected app mode', (tester) async {
    final settings = SettingsController();
    final auth = AuthController(LocalAuthService());
    await tester.runAsync(() async {
      await auth.signup(
        fullName: 'Ada Trader',
        email: 'ada@example.com',
        password: 'DemoPass1',
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: AuthScope(
          auth: auth,
          child: SettingsScope(
            settings: settings,
            child: const ProfileScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('profile-mode-badge')), findsOneWidget);
    expect(find.text('DEMO'), findsWidgets);
    expect(find.text('LIVE'), findsNothing);
    settings.setTradingUiMode(TradingUiMode.live);
    await tester.pump();
    expect(find.text('LIVE'), findsWidgets);
    settings.setTradingUiMode(TradingUiMode.demo);
    await tester.pump();
    expect(find.text('DEMO'), findsWidgets);
  });
}
