import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradepulse_frontend/core/routes/app_router.dart';
import 'package:tradepulse_frontend/core/services/app_scope.dart';
import 'package:tradepulse_frontend/core/services/auth_controller.dart';
import 'package:tradepulse_frontend/core/services/live_wallet_controller.dart';
import 'package:tradepulse_frontend/core/services/live_wallet_store.dart';
import 'package:tradepulse_frontend/core/services/local_auth_service.dart';
import 'package:tradepulse_frontend/core/services/market_controller.dart';
import 'package:tradepulse_frontend/core/services/offline_market_data_service.dart';
import 'package:tradepulse_frontend/core/services/settings_controller.dart';
import 'package:tradepulse_frontend/core/services/trading_controller.dart';
import 'package:tradepulse_frontend/core/services/trading_service.dart';
import 'package:tradepulse_frontend/core/theme/app_theme.dart';
import 'package:tradepulse_frontend/core/utils/app_utils.dart';
import 'package:tradepulse_frontend/core/utils/validators.dart';
import 'package:tradepulse_frontend/models/live_wallet_models.dart';
import 'package:tradepulse_frontend/screens/home/home_screen.dart';
import 'package:tradepulse_frontend/screens/wallet/live_deposit_confirm_screen.dart';
import 'package:tradepulse_frontend/screens/wallet/live_deposit_screen.dart';
import 'package:tradepulse_frontend/screens/wallet/live_withdraw_screen.dart';
import 'package:tradepulse_frontend/core/services/pwa_install_bridge_stub.dart';
import 'package:tradepulse_frontend/core/services/pwa_install_controller.dart';
import 'package:tradepulse_frontend/widgets/layout/viewport_sync.dart';
import 'package:tradepulse_frontend/widgets/cards/demo_balance_card.dart';

class _SilentTrading extends TradingService {
  @override
  Future<void> ensureAccount() async {}
}

Widget _app({
  required AuthController auth,
  required Widget home,
  LiveWalletController? wallet,
  TradingController? trading,
  PwaInstallController? pwa,
}) {
  final market = MarketController(OfflineMarketDataService());
  return MaterialApp(
    theme: AppTheme.dark(),
    home: home is Scaffold || home is HomeScreen || home is LiveDepositScreen || home is LiveWithdrawScreen
        ? home
        : Scaffold(body: home),
    onGenerateRoute: (settings) => AppRouter.onGenerateRoute(settings, auth),
    builder: (context, child) {
      return AuthScope(
        auth: auth,
        child: SettingsScope(
          settings: SettingsController(),
          child: MarketScope(
            market: market,
            child: TradingScope(
              trading: trading ??
                  (TradingController(_SilentTrading())..balance = 10000),
              child: LiveWalletScope(
                wallet: wallet ?? LiveWalletController(),
                child: PwaInstallScope(
                  install: pwa ?? PwaInstallController(),
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

Future<AuthController> _auth(WidgetTester tester) async {
  return (await tester.runAsync(() async {
    final service = LocalAuthService();
    await service.signup(
      fullName: 'Ada Trader',
      email: 'ada@example.com',
      password: 'DemoPass1',
    );
    return AuthController(service);
  }))!;
}

Future<void> _tallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(400, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  setUp(LiveWalletStore.reset);

  test('money formatting keeps selected deposit amounts readable', () {
    expect(AppUtils.formatMoney(50), r'$50.00');
    expect(AppUtils.formatMoney(2500), r'$2,500.00');
    expect(AppUtils.formatMoney(5000), r'$5,000.00');
  });

  testWidgets('stale keyboard insets do not shrink the viewport', (tester) async {
    late MediaQueryData seen;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          viewInsets: EdgeInsets.only(bottom: 320),
        ),
        child: ViewportSync(
          child: Builder(
            builder: (context) {
              seen = MediaQuery.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    expect(seen.viewInsets.bottom, 0);
    expect(seen.size.height, 844);
  });

  testWidgets('focused field keeps full height and keyboard insets', (tester) async {
    late MediaQueryData seen;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          viewInsets: EdgeInsets.only(bottom: 320),
        ),
        child: ViewportSync(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                seen = MediaQuery.of(context);
                return const Scaffold(body: TextField(autofocus: true));
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(seen.size.height, 844);
    expect(seen.viewInsets.bottom, greaterThan(80));
  });

  testWidgets('shrunk engine height restores after keyboard', (tester) async {
    late MediaQueryData seen;
    Future<void> pumpSize(Size size) {
      return tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size),
          child: ViewportSync(
            child: Builder(
              builder: (context) {
                seen = MediaQuery.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
    }

    await pumpSize(const Size(390, 844));
    expect(seen.size.height, 844);
    await pumpSize(const Size(390, 524));
    expect(seen.size.height, 844);
    expect(seen.viewInsets.bottom, 0);
  });

  test('live deposit amount bounds', () {
    expect(Validators.liveDepositAmount('49.99'), isNotNull);
    expect(Validators.liveDepositAmount('50'), isNull);
    expect(Validators.liveDepositAmount('100'), isNull);
    expect(Validators.liveDepositAmount('5000'), isNull);
    expect(Validators.liveDepositAmount('5000.01'), isNotNull);
  });

  test('placeholder addresses match selected assets', () {
    expect(
      LivePaymentAsset.btc.placeholderAddress,
      '1CUXN4MrQ9qyZBtqU6Pg4U7iZiy6Y3ztMt',
    );
    expect(
      LivePaymentAsset.usdtTrc20.placeholderAddress,
      'THfnsscby3ZW3LPGbTyGLyLkFsFdRwV5Xq',
    );
    expect(
      LivePaymentAsset.eth.placeholderAddress,
      '0x27e711D1B6E4866EBf7904B3B631f6D05518E1B6',
    );
    expect(LivePaymentAsset.values, hasLength(3));
  });

  test('live deposit persists across controller reload and keeps submittedAt clock', () async {
    final submitted = DateTime.utc(2026, 9, 21, 12);
    final first = LiveWalletController(clock: () => submitted);
    final record = await first.submitDeposit(
      asset: LivePaymentAsset.usdtTrc20,
      amount: 250,
      txid: 'abcxyz7iZiy6Y3zt',
    );
    expect(LiveWalletController.liveBalance, 0);

    final stored = await LiveWalletStore.load();
    expect(stored, hasLength(1));
    expect(stored.single['id'], record.id);
    expect(stored.single['type'], 'deposit');
    expect(stored.single['asset'], LivePaymentAsset.usdtTrc20.id);
    expect(stored.single['network'], 'TRON (TRC20)');
    expect(stored.single['amount'], 250);
    expect(stored.single['txid'], 'abcxyz7iZiy6Y3zt');
    expect(stored.single['submittedAt'], submitted.toUtc().toIso8601String());

    final afterSeven = LiveWalletController(
      clock: () => submitted.add(const Duration(minutes: 7)),
    );
    await afterSeven.restore();
    expect(afterSeven.transfers, hasLength(1));
    final restored = afterSeven.transfers.single;
    expect(restored.id, record.id);
    expect(restored.amount, 250);
    expect(restored.asset, LivePaymentAsset.usdtTrc20);
    expect(restored.txid, 'abcxyz7iZiy6Y3zt');
    expect(restored.submittedAt, submitted.toUtc());
    expect(afterSeven.statusOf(restored), LiveTransferStatus.pending);
    expect(LiveWalletController.liveBalance, 0);

    final afterSixteen = LiveWalletController(
      clock: () => submitted.add(const Duration(minutes: 16)),
    );
    await afterSixteen.restore();
    expect(afterSixteen.transfers, hasLength(1));
    expect(afterSixteen.transfers.single.submittedAt, submitted.toUtc());
    expect(
      afterSixteen.statusOf(afterSixteen.transfers.single),
      LiveTransferStatus.failed,
    );
    expect(LiveWalletController.liveBalance, 0);
  });

  test('pending deposit becomes failed after 15 minutes without crediting live', () async {
    final now = DateTime.utc(2026, 9, 21, 0, 56);
    final wallet = LiveWalletController(clock: () => now);
    final record = await wallet.submitDeposit(
      asset: LivePaymentAsset.btc,
      amount: 100,
      txid: 'abcxyz7iZiy6Y3zt',
    );
    expect(LiveWalletController.liveBalance, 0);
    expect(wallet.statusOf(record), LiveTransferStatus.pending);
    expect(AppUtils.maskTxid(record.txid), '••••••7iZiy6Y3zt');
    wallet.setClock(() => now.add(const Duration(minutes: 15)));
    expect(wallet.statusOf(record), LiveTransferStatus.failed);
    expect(LiveWalletController.liveBalance, 0);
  });

  testWidgets('home shows demo balance, live zero, and cash buttons', (tester) async {
    await _tallSurface(tester);
    final auth = await _auth(tester);
    final trading = TradingController(_SilentTrading())..balance = 12500;
    await tester.pumpWidget(
      _app(auth: auth, trading: trading, home: const HomeScreen()),
    );
    await tester.pump();
    expect(find.text('Demo Balance'), findsOneWidget);
    expect(find.text(r'$12,500.00'), findsOneWidget);
    expect(find.text('OTC Trading Platform'), findsOneWidget);
    expect(find.text('Fast • Simple • Trading'), findsOneWidget);
    expect(find.text('Manage Funds'), findsOneWidget);
    expect(find.text('Live Balance'), findsOneWidget);
    expect(find.text(r'$0.00'), findsWidgets);
    expect(find.text('LEADERBOARD'), findsOneWidget);
    expect(find.text('Deposit'), findsOneWidget);
    expect(find.text('Withdraw'), findsOneWidget);
    expect(find.text('Install TradePulse'), findsNothing);
  });

  testWidgets('home footer shows Android install option', (tester) async {
    await _tallSurface(tester);
    final auth = await _auth(tester);
    final pwa = PwaInstallController(
      bridge: StubPwaInstallBridge()..nativePrompt = true,
    );
    await tester.pumpWidget(
      _app(auth: auth, home: const HomeScreen(), pwa: pwa),
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Install Now'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Install TradePulse'), findsOneWidget);
    expect(find.text('Install Now'), findsOneWidget);
  });

  testWidgets('home footer shows Android install without native prompt',
      (tester) async {
    await _tallSurface(tester);
    final auth = await _auth(tester);
    final pwa = PwaInstallController(
      bridge: StubPwaInstallBridge()..androidBrowser = true,
    );
    await tester.pumpWidget(
      _app(auth: auth, home: const HomeScreen(), pwa: pwa),
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Add to Home Screen'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Install TradePulse'), findsOneWidget);
    expect(find.text('Add to Home Screen'), findsOneWidget);
  });

  testWidgets('home footer shows iPhone Add to Home Screen', (tester) async {
    await _tallSurface(tester);
    final auth = await _auth(tester);
    final pwa = PwaInstallController(
      bridge: StubPwaInstallBridge()..iosBrowser = true,
    );
    await tester.pumpWidget(
      _app(auth: auth, home: const HomeScreen(), pwa: pwa),
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Add to Home Screen'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Add TradePulse to your Home Screen for faster access.'),
      findsOneWidget,
    );
  });

  testWidgets('deposit and withdraw buttons open live screens', (tester) async {
    await _tallSurface(tester);
    final auth = await _auth(tester);
    await tester.pumpWidget(_app(auth: auth, home: const HomeScreen()));
    await tester.pump();
    await tester.ensureVisible(find.text('Deposit'));
    await tester.tap(find.text('Deposit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Payment method'), findsOneWidget);
    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.text('Withdraw'));
    await tester.tap(find.text('Withdraw'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Insufficient Balance'), findsOneWidget);
    expect(
      find.text('You do not have sufficient Live Balance to make a withdrawal.'),
      findsOneWidget,
    );
  });

  testWidgets('three payment assets and selected confirmation addresses', (tester) async {
    final auth = await _auth(tester);
    await tester.pumpWidget(_app(auth: auth, home: const LiveDepositScreen()));
    await tester.pump();
    expect(find.text('Bitcoin (BTC)'), findsOneWidget);
    expect(find.text('USDT — TRON (TRC20)'), findsOneWidget);
    expect(find.text('ETH — ERC20'), findsOneWidget);
    expect(find.text('USDC — ERC20'), findsNothing);

    Future<void> confirm(LivePaymentAsset asset, String address) async {
      await tester.tap(find.text(asset.title).first);
      await tester.pump();
      await tester.dragUntilVisible(
        find.widgetWithText(TextFormField, 'Custom amount'),
        find.byType(ListView).first,
        const Offset(0, -120),
      );
      await tester.enterText(find.widgetWithText(TextFormField, 'Custom amount'), '100');
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Continue').last);
      await tester.tap(find.widgetWithText(FilledButton, 'Continue').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Payment Method'), findsOneWidget);
      expect(find.text('Deposit Amount'), findsOneWidget);
      expect(find.text(asset.title), findsWidgets);
      expect(find.text(address), findsOneWidget);
      expect(find.text(r'$100.00'), findsOneWidget);
      await tester.pageBack();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    await confirm(LivePaymentAsset.btc, '1CUXN4MrQ9qyZBtqU6Pg4U7iZiy6Y3ztMt');
    await confirm(
      LivePaymentAsset.usdtTrc20,
      'THfnsscby3ZW3LPGbTyGLyLkFsFdRwV5Xq',
    );
    await confirm(
      LivePaymentAsset.eth,
      '0x27e711D1B6E4866EBf7904B3B631f6D05518E1B6',
    );
  });

  testWidgets('deposit amount validation and pending history', (tester) async {
    final auth = await _auth(tester);
    final wallet = LiveWalletController();
    await tester.pumpWidget(
      _app(auth: auth, wallet: wallet, home: const LiveDepositScreen()),
    );
    await tester.pump();
    await tester.dragUntilVisible(
      find.widgetWithText(TextFormField, 'Custom amount'),
      find.byType(ListView).first,
      const Offset(0, -120),
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Custom amount'), '49.99');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Continue'));
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pump();
    expect(find.text('Minimum deposit is \$50.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Custom amount'), '5000.01');
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pump();
    expect(find.text('Maximum deposit is \$5,000.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Custom amount'), '100');
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Transaction ID / TXID'),
      'abcxyz7iZiy6Y3zt',
    );
    await tester.tap(find.text('Submit Deposit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Deposit — Bitcoin'), findsOneWidget);
    expect(find.textContaining('TXID:'), findsOneWidget);
    expect(find.text('🟡 Pending'), findsOneWidget);
    expect(LiveWalletController.liveBalance, 0);
    expect(wallet.transfers, hasLength(1));
  });

  testWidgets('confirm deposit shows the selected draft amount', (tester) async {
    await _tallSurface(tester);
    final auth = await _auth(tester);
    await tester.pumpWidget(
      _app(
        auth: auth,
        home: const LiveDepositConfirmScreen(
          draft: LiveDepositDraft(
            asset: LivePaymentAsset.btc,
            amount: 2500,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Confirm Deposit'), findsOneWidget);
    expect(find.text('Payment Method'), findsOneWidget);
    expect(find.text('Bitcoin (BTC)'), findsOneWidget);
    expect(find.text('Deposit Amount'), findsOneWidget);
    expect(find.text(r'$2,500.00'), findsOneWidget);
    expect(find.text('Bitcoin Network'), findsOneWidget);
    expect(find.text('1CUXN4MrQ9qyZBtqU6Pg4U7iZiy6Y3ztMt'), findsOneWidget);
    expect(find.text('Payment Notice'), findsOneWidget);
    expect(LiveWalletController.liveBalance, 0);
  });

  testWidgets('withdraw stays blocked at zero live balance', (tester) async {
    final auth = await _auth(tester);
    await tester.pumpWidget(_app(auth: auth, home: const LiveWithdrawScreen()));
    await tester.pump();
    expect(find.text(r'$0.00'), findsWidgets);
    expect(find.text('Insufficient Balance'), findsOneWidget);
    expect(find.text('Withdrawal Information'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Submit Withdrawal'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Submit Withdrawal'), findsOneWidget);
    expect(find.text('Payment Method'), findsOneWidget);
  });

  testWidgets('demo balance card is unchanged in value', (tester) async {
    await tester.pumpWidget(
      _app(
        auth: AuthController(LocalAuthService()),
        home: const DemoBalanceCard(),
      ),
    );
    await tester.pump();
    expect(find.text(r'$10,000.00'), findsOneWidget);
    expect(find.text('DEMO'), findsOneWidget);
  });
}
