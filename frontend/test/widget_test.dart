import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradepulse_frontend/core/constants/app_constants.dart';
import 'package:tradepulse_frontend/core/services/auth_controller.dart';
import 'package:tradepulse_frontend/core/services/app_scope.dart';
import 'package:tradepulse_frontend/core/services/local_auth_service.dart';
import 'package:tradepulse_frontend/core/services/settings_controller.dart';
import 'package:tradepulse_frontend/core/utils/validators.dart';
import 'package:tradepulse_frontend/main.dart';
import 'package:tradepulse_frontend/widgets/navigation/app_shell.dart';
import 'package:tradepulse_frontend/widgets/navigation/bottom_nav.dart';
import 'package:tradepulse_frontend/widgets/navigation/side_nav.dart';

void main() {
  test('api and websocket urls are configured', () {
    expect(AppConstants.apiBase, isNotEmpty);
    expect(AppConstants.marketWsUrl, contains('/ws/market'));
    expect(
      AppConstants.marketWsUrl.startsWith('ws://') ||
          AppConstants.marketWsUrl.startsWith('wss://'),
      isTrue,
    );
  });

  test('email validator', () {
    expect(Validators.email(null), isNotNull);
    expect(Validators.email('bad'), isNotNull);
    expect(Validators.email('trader@example.com'), isNull);
  });

  test('strong password validator', () {
    expect(Validators.strongPassword('short'), isNotNull);
    expect(Validators.strongPassword('longenough'), isNotNull);
    expect(Validators.strongPassword('DemoPass1'), isNull);
  });

  test('local auth signup and login', () async {
    final auth = LocalAuthService();
    await auth.signup(
      fullName: 'Ada Trader',
      email: 'ada@example.com',
      password: 'DemoPass1',
    );
    expect(auth.isAuthenticated(), isTrue);
    await auth.logout();
    expect(auth.isAuthenticated(), isFalse);
    await auth.login(email: 'ada@example.com', password: 'DemoPass1');
    expect(auth.currentUser()?.fullName, 'Ada Trader');
  });

  testWidgets('splash transitions to login', (tester) async {
    await tester.pumpWidget(const TradePulseApp());
    expect(find.text('TradePulse'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('login shows validation errors', (tester) async {
    await tester.pumpWidget(const TradePulseApp());
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Login'));
    await tester.pump();
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('compact shell uses bottom navigation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          return MediaQuery(
            data: const MediaQueryData(size: Size(390, 844)),
            child: child!,
          );
        },
        home: AuthScope(
          auth: AuthController(LocalAuthService()),
          child: SettingsScope(
            settings: SettingsController(),
            child: const AppShell(
              currentRoute: '/home',
              child: SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(AppBottomNav), findsOneWidget);
    expect(find.byType(SideNav), findsNothing);
  });

  testWidgets('wide shell uses side navigation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          return MediaQuery(
            data: const MediaQueryData(size: Size(1280, 800)),
            child: child!,
          );
        },
        home: AuthScope(
          auth: AuthController(LocalAuthService()),
          child: SettingsScope(
            settings: SettingsController(),
            child: const AppShell(
              currentRoute: '/home',
              child: SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(SideNav), findsOneWidget);
    expect(find.byType(AppBottomNav), findsNothing);
  });
}
