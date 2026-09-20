import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradepulse_frontend/core/routes/app_router.dart';
import 'package:tradepulse_frontend/core/routes/app_routes.dart';
import 'package:tradepulse_frontend/core/services/app_scope.dart';
import 'package:tradepulse_frontend/core/services/auth_controller.dart';
import 'package:tradepulse_frontend/core/services/auth_service.dart';
import 'package:tradepulse_frontend/core/services/local_auth_service.dart';
import 'package:tradepulse_frontend/core/services/market_controller.dart';
import 'package:tradepulse_frontend/core/services/offline_market_data_service.dart';
import 'package:tradepulse_frontend/core/services/settings_controller.dart';
import 'package:tradepulse_frontend/core/services/trading_controller.dart';
import 'package:tradepulse_frontend/core/services/trading_service.dart';
import 'package:tradepulse_frontend/core/theme/app_theme.dart';
import 'package:tradepulse_frontend/core/utils/password_reset_link.dart';
import 'package:tradepulse_frontend/core/utils/validators.dart';

class _ResetAuth extends LocalAuthService {
  int resetRequests = 0;

  @override
  Future<void> resetPassword({required String email}) async {
    resetRequests += 1;
    if (email.trim().toLowerCase() == 'missing@example.com') {
      throw const AuthException('No account found for that email');
    }
    await super.resetPassword(email: email);
  }
}

Widget _app(AuthController auth, {String? initialRoute, Object? arguments}) {
  final market = MarketController(OfflineMarketDataService());
  final trading = TradingController(TradingService());
  return MaterialApp(
    theme: AppTheme.dark(),
    initialRoute: initialRoute ?? AppRoutes.forgotPassword,
    onGenerateRoute: (settings) {
      final resolved = settings.name == (initialRoute ?? AppRoutes.forgotPassword) &&
              settings.arguments == null &&
              arguments != null
          ? RouteSettings(name: settings.name, arguments: arguments)
          : settings;
      return AppRouter.onGenerateRoute(resolved, auth);
    },
    builder: (context, child) {
      return AuthScope(
        auth: auth,
        child: SettingsScope(
          settings: SettingsController(),
          child: MarketScope(
            market: market,
            child: TradingScope(
              trading: trading,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      );
    },
  );
}

Future<AuthController> _readyAuth() async {
  final service = _ResetAuth();
  await service.signup(
    fullName: 'Ada Trader',
    email: 'ada@example.com',
    password: 'OldPass1',
  );
  await service.logout();
  return AuthController(service);
}

Future<void> _act(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);

void main() {
  test('email validator rejects invalid addresses', () {
    expect(Validators.email(''), isNotNull);
    expect(Validators.email('not-an-email'), isNotNull);
    expect(Validators.email('ada@example.com'), isNull);
  });

  test('password reset link parses query and hash action codes', () {
    expect(
      PasswordResetLink.isReset(
        Uri.parse(
          'https://app.example/?mode=resetPassword&oobCode=abc123',
        ),
      ),
      isTrue,
    );
    expect(
      PasswordResetLink.oobCodeFrom(
        Uri.parse('https://app.example/#/reset-password?mode=resetPassword&oobCode=xyz'),
      ),
      'xyz',
    );
    expect(
      PasswordResetLink.oobCodeFrom(Uri.parse('https://app.example/login')),
      isNull,
    );
  });

  testWidgets('forgot password screen asks for email', (tester) async {
    await tester.pumpWidget(_app(AuthController(_ResetAuth())));
    await tester.pump();
    expect(find.text('Forgot Password'), findsOneWidget);
    expect(find.text('Send Reset Email'), findsOneWidget);
    expect(_field('Email'), findsOneWidget);
    expect(find.text('Verification code'), findsNothing);
  });

  testWidgets('email validation blocks empty submit', (tester) async {
    await tester.pumpWidget(_app(AuthController(_ResetAuth())));
    await tester.pump();
    await tester.tap(find.text('Send Reset Email'));
    await tester.pump();
    expect(find.text('Email is required'), findsOneWidget);
  });

  testWidgets('invalid email format is rejected', (tester) async {
    await tester.pumpWidget(_app(AuthController(_ResetAuth())));
    await tester.pump();
    await tester.enterText(_field('Email'), 'not-an-email');
    await tester.tap(find.text('Send Reset Email'));
    await tester.pump();
    expect(find.text('Enter a valid email'), findsOneWidget);
  });

  testWidgets('unknown email is rejected', (tester) async {
    await tester.pumpWidget(_app(AuthController(_ResetAuth())));
    await tester.pump();
    await tester.enterText(_field('Email'), 'missing@example.com');
    await tester.tap(find.text('Send Reset Email'));
    await _act(tester);
    expect(find.text('No account found for that email'), findsOneWidget);
  });

  testWidgets('valid email requests a firebase reset email', (tester) async {
    late _ResetAuth service;
    final auth = (await tester.runAsync(() async {
      service = _ResetAuth();
      await service.signup(
        fullName: 'Ada Trader',
        email: 'ada@example.com',
        password: 'OldPass1',
      );
      await service.logout();
      return AuthController(service);
    }))!;
    await tester.pumpWidget(_app(auth));
    await tester.pump();
    await tester.enterText(_field('Email'), 'ada@example.com');
    await tester.tap(find.text('Send Reset Email'));
    await _act(tester);
    expect(
      find.text('Password reset email sent. Please check your inbox.'),
      findsOneWidget,
    );
    expect(find.text('Verification code'), findsNothing);
    expect(service.resetRequests, 1);
  });

  testWidgets('invalid reset link is rejected', (tester) async {
    final auth = (await tester.runAsync(_readyAuth))!;
    await tester.pumpWidget(
      _app(auth, initialRoute: AppRoutes.resetPassword, arguments: 'invalid'),
    );
    await _act(tester);
    expect(
      find.text('This reset link is invalid or has already been used.'),
      findsOneWidget,
    );
    expect(find.text('Save New Password'), findsNothing);
  });

  testWidgets('expired reset link is rejected', (tester) async {
    final auth = (await tester.runAsync(_readyAuth))!;
    await tester.pumpWidget(
      _app(auth, initialRoute: AppRoutes.resetPassword, arguments: 'expired'),
    );
    await _act(tester);
    expect(
      find.text('This reset link has expired. Request a new email.'),
      findsOneWidget,
    );
    expect(find.text('Save New Password'), findsNothing);
  });

  testWidgets('used reset link is rejected', (tester) async {
    final auth = (await tester.runAsync(_readyAuth))!;
    await tester.runAsync(() async {
      await auth.confirmPasswordReset(
        oobCode: 'action-ada@example.com',
        newPassword: 'NewPass99',
      );
    });
    await tester.pumpWidget(
      _app(
        auth,
        initialRoute: AppRoutes.resetPassword,
        arguments: 'action-ada@example.com',
      ),
    );
    await _act(tester);
    expect(
      find.text('This reset link is invalid or has already been used.'),
      findsOneWidget,
    );
  });

  testWidgets('password mismatch is rejected', (tester) async {
    final auth = (await tester.runAsync(_readyAuth))!;
    await tester.pumpWidget(
      _app(
        auth,
        initialRoute: AppRoutes.resetPassword,
        arguments: 'action-ada@example.com',
      ),
    );
    await _act(tester);
    await tester.enterText(_field('New Password'), 'NewPass99');
    await tester.enterText(_field('Confirm Password'), 'OtherPass99');
    await tester.tap(find.text('Save New Password'));
    await tester.pump();
    expect(find.text('Passwords do not match'), findsOneWidget);
  });

  testWidgets('successful reset allows login with the new password', (tester) async {
    final auth = (await tester.runAsync(_readyAuth))!;
    await tester.pumpWidget(
      _app(
        auth,
        initialRoute: AppRoutes.resetPassword,
        arguments: 'action-ada@example.com',
      ),
    );
    await _act(tester);
    await tester.enterText(_field('New Password'), 'NewPass99');
    await tester.enterText(_field('Confirm Password'), 'NewPass99');
    await tester.tap(find.text('Save New Password'));
    await _act(tester);
    expect(find.text('Password Reset Successful'), findsOneWidget);
    expect(
      find.text('Your password has been updated successfully.'),
      findsOneWidget,
    );
    expect(find.text('Login'), findsOneWidget);
    await tester.runAsync(() async {
      await auth.login(email: 'ada@example.com', password: 'NewPass99');
      expect(auth.isAuthenticated, isTrue);
      try {
        await auth.login(email: 'ada@example.com', password: 'OldPass1');
        fail('old password should no longer work');
      } on AuthException {
        // expected
      }
    });
  });
}
