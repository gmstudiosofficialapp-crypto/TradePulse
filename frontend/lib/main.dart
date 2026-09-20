import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'core/constants/app_constants.dart';
import 'core/routes/app_router.dart';
import 'core/routes/app_routes.dart';
import 'core/services/app_scope.dart';
import 'core/services/auth_controller.dart';
import 'core/services/auth_service.dart';
import 'core/services/firebase_auth_service.dart';
import 'core/services/local_auth_service.dart';
import 'core/services/live_wallet_controller.dart';
import 'core/services/market_controller.dart';
import 'core/services/market_data_service.dart';
import 'core/services/offline_market_data_service.dart';
import 'core/services/pwa_install_controller.dart';
import 'core/services/settings_controller.dart';
import 'core/services/trading_controller.dart';
import 'core/services/trading_service.dart';
import 'core/services/websocket_market_data_service.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/password_reset_link.dart';
import 'widgets/layout/viewport_sync.dart';
import 'widgets/pwa/pwa_install_banner.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final auth = FirebaseAuthService();
  await auth.restoreSession();
  runApp(
    TradePulseApp(
      authService: auth,
      marketService: WebSocketMarketDataService(),
    ),
  );
}

class TradePulseApp extends StatefulWidget {
  const TradePulseApp({
    super.key,
    this.authService,
    this.marketService,
    this.pwaInstall,
  });

  final AuthService? authService;
  final MarketDataService? marketService;
  final PwaInstallController? pwaInstall;

  @override
  State<TradePulseApp> createState() => _TradePulseAppState();
}

class _TradePulseAppState extends State<TradePulseApp> {
  late final AuthService _authService;
  late final AuthController _auth;
  late final SettingsController _settings;
  late final MarketController _market;
  late final TradingController _trading;
  late final LiveWalletController _wallet;
  late final PwaInstallController _pwa;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? LocalAuthService();
    _auth = AuthController(_authService);
    _settings = SettingsController();
    _market = MarketController(
      widget.marketService ?? OfflineMarketDataService(),
    );
    _trading = TradingController(
      TradingService(tokenProvider: _authService.idToken),
    );
    _wallet = LiveWalletController();
    _pwa = widget.pwaInstall ?? PwaInstallController();
    _pwa.attach();
    _pwa.addListener(_rebuild);
    unawaited(_wallet.restore());
    _settings.addListener(_rebuild);
    _auth.addListener(_onAuth);
    _market.events.listen(_trading.applyEvent);
    if (_auth.isAuthenticated) {
      _onAuth();
    }
    unawaited(_market.start());
  }

  void _onAuth() {
    final user = _auth.user;
    final id = user == null
        ? null
        : (user.uid.isNotEmpty ? user.uid : user.email.toLowerCase());
    unawaited(_trading.bindUser(id));
    if (id != null) {
      unawaited(_market.identify(id));
    }
    _rebuild();
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _settings.removeListener(_rebuild);
    _auth.removeListener(_onAuth);
    _auth.dispose();
    _settings.dispose();
    _market.dispose();
    _trading.dispose();
    _pwa.removeListener(_rebuild);
    _wallet.dispose();
    if (widget.pwaInstall == null) {
      _pwa.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _settings.themeMode,
      initialRoute: PasswordResetLink.isReset(Uri.base)
          ? AppRoutes.resetPassword
          : AppRoutes.splash,
      onGenerateRoute: (settings) {
        final resolved = settings.name == AppRoutes.resetPassword &&
                settings.arguments == null
            ? RouteSettings(
                name: settings.name,
                arguments: PasswordResetLink.oobCodeFrom(Uri.base),
              )
            : settings;
        return AppRouter.onGenerateRoute(resolved, _auth);
      },
      builder: (context, child) {
        return ViewportSync(
          child: AuthScope(
            auth: _auth,
            child: SettingsScope(
              settings: _settings,
              child: MarketScope(
                market: _market,
                child: TradingScope(
                  trading: _trading,
                  child: LiveWalletScope(
                    wallet: _wallet,
                    child: PwaInstallScope(
                      install: _pwa,
                      child: Stack(
                        children: [
                          child ?? const SizedBox.shrink(),
                          const PwaInstallBanner(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
