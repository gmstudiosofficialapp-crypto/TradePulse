import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradepulse_frontend/core/services/app_scope.dart';
import 'package:tradepulse_frontend/core/services/auth_controller.dart';
import 'package:tradepulse_frontend/core/services/local_auth_service.dart';
import 'package:tradepulse_frontend/core/services/settings_controller.dart';
import 'package:tradepulse_frontend/core/services/signup_bonus_notice.dart';
import 'package:tradepulse_frontend/core/theme/app_theme.dart';
import 'package:tradepulse_frontend/screens/home/home_screen.dart';
import 'package:tradepulse_frontend/widgets/feedback/signup_bonus_dialog.dart';

Widget _homeApp() {
  return MaterialApp(
    theme: AppTheme.dark(),
    home: AuthScope(
      auth: AuthController(LocalAuthService()),
      child: SettingsScope(
        settings: SettingsController(),
        child: const HomeScreen(),
      ),
    ),
  );
}

void main() {
  setUp(SignupBonusNotice.instance.resetForTest);
  tearDown(SignupBonusNotice.instance.resetForTest);

  test('frontend shows bonus only after server just_granted confirmation', () {
    applySignupBonusPayload('{"signup_bonus_just_granted":false}');
    expect(SignupBonusNotice.instance.isPending, isFalse);
    applySignupBonusPayload('not-json');
    expect(SignupBonusNotice.instance.isPending, isFalse);
    applySignupBonusPayload('{"signup_bonus_just_granted":true}');
    expect(SignupBonusNotice.instance.isPending, isTrue);
    expect(SignupBonusNotice.instance.take(), isTrue);
    expect(SignupBonusNotice.instance.take(), isFalse);
    applySignupBonusPayload('{"signup_bonus_just_granted":true}');
    expect(SignupBonusNotice.instance.take(), isFalse);
  });

  test('refresh and re-login do not replay a consumed server bonus', () {
    applySignupBonusPayload(
      '{"signup_bonus_just_granted":true,"signup_bonus_granted":true}',
    );
    expect(SignupBonusNotice.instance.take(), isTrue);
    applySignupBonusPayload(
      '{"signup_bonus_just_granted":false,"signup_bonus_granted":true}',
    );
    expect(SignupBonusNotice.instance.take(), isFalse);
    SignupBonusNotice.instance.clearSession();
    applySignupBonusPayload(
      '{"signup_bonus_just_granted":false,"signup_bonus_granted":true}',
    );
    expect(SignupBonusNotice.instance.take(), isFalse);
  });

  testWidgets('home shows the one-time bonus dialog from server notice',
      (tester) async {
    SignupBonusNotice.instance.offerFromServer(justGranted: true);
    await tester.pumpWidget(_homeApp());
    await tester.pump();
    await tester.pump();
    expect(find.byType(SignupBonusDialog), findsOneWidget);
    expect(find.text('Signup Bonus Received!'), findsOneWidget);
    expect(find.text(r'$10'), findsOneWidget);
    await tester.tap(find.text('Start Trading'));
    await tester.pumpAndSettle();
    expect(find.byType(SignupBonusDialog), findsNothing);

    await tester.pumpWidget(_homeApp());
    await tester.pump();
    await tester.pump();
    expect(find.byType(SignupBonusDialog), findsNothing);
  });

  testWidgets('home does not invent a bonus without server confirmation',
      (tester) async {
    await tester.pumpWidget(_homeApp());
    await tester.pump();
    await tester.pump();
    expect(find.byType(SignupBonusDialog), findsNothing);
    expect(find.text('Signup Bonus Received!'), findsNothing);
  });
}
