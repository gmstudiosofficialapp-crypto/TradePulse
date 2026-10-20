import 'package:flutter/material.dart';

import '../../screens/auth/forgot_password_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/reset_password_screen.dart';
import '../../screens/auth/signup_screen.dart';
import '../../screens/history/history_screen.dart';
import '../../screens/leaderboard/leaderboard_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/markets/markets_screen.dart';
import '../../screens/profile/change_password_screen.dart';
import '../../screens/profile/edit_profile_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/splash_screen.dart';
import '../../screens/trade/trade_screen.dart';
import '../../models/deposit_models.dart';
import '../../screens/wallet/deposit_details_screen.dart';
import '../../screens/wallet/deposit_history_screen.dart';
import '../../screens/wallet/live_deposit_confirm_screen.dart';
import '../../screens/wallet/live_deposit_screen.dart';
import '../../screens/wallet/live_transfers_screen.dart';
import '../../screens/admin/admin_login_screen.dart';
import '../../screens/admin/admin_panel_screen.dart';
import '../../screens/wallet/live_withdraw_screen.dart';
import '../../screens/wallet/withdrawal_details_screen.dart';
import '../../screens/wallet/withdrawal_history_screen.dart';
import '../../models/live_wallet_models.dart';
import '../../models/withdraw_models.dart';
import '../../widgets/navigation/app_shell.dart';
import '../services/auth_controller.dart';
import 'app_routes.dart';

class AppRouter {
  static Route<dynamic> onGenerateRoute(
    RouteSettings settings,
    AuthController auth,
  ) {
    var name = settings.name ?? AppRoutes.splash;
    final public = AppRoutes.public.contains(name);

    if (!public && !auth.isAuthenticated) {
      name = AppRoutes.login;
    }

    final page = _pageFor(name, settings.arguments);
    return PageRouteBuilder<void>(
      settings: RouteSettings(name: name, arguments: settings.arguments),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 240),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (animation.status == AnimationStatus.completed) {
          return child;
        }
        final fade = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: fade,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(fade),
            child: child,
          ),
        );
      },
    );
  }

  static Widget _pageFor(String name, Object? arguments) {
    final tradeAsset = arguments is String ? arguments : null;
    final content = switch (name) {
      AppRoutes.splash => const SplashScreen(),
      AppRoutes.login => const LoginScreen(),
      AppRoutes.signup => const SignupScreen(),
      AppRoutes.forgotPassword => const ForgotPasswordScreen(),
      AppRoutes.resetPassword => ResetPasswordScreen(
          oobCode: arguments is String ? arguments : null,
        ),
      AppRoutes.home => const HomeScreen(),
      AppRoutes.markets => const MarketsScreen(),
      AppRoutes.trade => TradeScreen(initialAsset: tradeAsset),
      AppRoutes.history => const HistoryScreen(),
      AppRoutes.leaderboard => const LeaderboardScreen(),
      AppRoutes.profile => const ProfileScreen(),
      AppRoutes.settings => const SettingsScreen(),
      AppRoutes.editProfile => const EditProfileScreen(),
      AppRoutes.changePassword => const ChangePasswordScreen(),
      AppRoutes.liveDeposit => const LiveDepositScreen(),
      AppRoutes.liveDepositConfirm => arguments is LiveDepositDraft
          ? LiveDepositConfirmScreen(draft: arguments)
          : const LiveDepositScreen(),
      AppRoutes.liveWithdraw => const LiveWithdrawScreen(),
      AppRoutes.liveTransfers => const LiveTransfersScreen(),
      AppRoutes.depositHistory => const DepositHistoryScreen(),
      AppRoutes.depositDetails => DepositDetailsScreen(
          requestId: arguments is DepositRequest
              ? arguments.requestId
              : arguments is String
                  ? arguments
                  : '',
          initial: arguments is DepositRequest ? arguments : null,
        ),
      AppRoutes.withdrawalHistory => const WithdrawalHistoryScreen(),
      AppRoutes.withdrawalDetails => WithdrawalDetailsScreen(
          requestId: _withdrawalRequestId(arguments),
          initial: _withdrawalRequest(arguments),
        ),
      AppRoutes.adminLogin => const AdminLoginScreen(),
      AppRoutes.adminPanel => const AdminPanelScreen(),
      _ => const LoginScreen(),
    };

    if (AppRoutes.shell.contains(name)) {
      return AppShell(currentRoute: name, child: content);
    }
    return content;
  }

  static String _withdrawalRequestId(Object? arguments) {
    if (arguments is String) return arguments;
    if (arguments is WithdrawalRequest) return arguments.requestId;
    return '';
  }

  static WithdrawalRequest? _withdrawalRequest(Object? arguments) {
    return arguments is WithdrawalRequest ? arguments : null;
  }
}
