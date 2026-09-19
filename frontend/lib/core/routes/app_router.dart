import 'package:flutter/material.dart';

import '../../screens/auth/forgot_password_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/signup_screen.dart';
import '../../screens/history/history_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/markets/markets_screen.dart';
import '../../screens/profile/change_password_screen.dart';
import '../../screens/profile/edit_profile_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/splash_screen.dart';
import '../../screens/trade/trade_screen.dart';
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
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
      AppRoutes.home => const HomeScreen(),
      AppRoutes.markets => const MarketsScreen(),
      AppRoutes.trade => TradeScreen(initialAsset: tradeAsset),
      AppRoutes.history => const HistoryScreen(),
      AppRoutes.profile => const ProfileScreen(),
      AppRoutes.settings => const SettingsScreen(),
      AppRoutes.editProfile => const EditProfileScreen(),
      AppRoutes.changePassword => const ChangePasswordScreen(),
      _ => const LoginScreen(),
    };

    if (AppRoutes.shell.contains(name)) {
      return AppShell(currentRoute: name, child: content);
    }
    return content;
  }
}
