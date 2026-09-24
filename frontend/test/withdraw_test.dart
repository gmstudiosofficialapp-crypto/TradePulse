import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradepulse_frontend/core/services/app_scope.dart';
import 'package:tradepulse_frontend/core/services/auth_controller.dart';
import 'package:tradepulse_frontend/core/services/live_wallet_controller.dart';
import 'package:tradepulse_frontend/core/services/local_auth_service.dart';
import 'package:tradepulse_frontend/core/services/market_controller.dart';
import 'package:tradepulse_frontend/core/services/offline_market_data_service.dart';
import 'package:tradepulse_frontend/core/services/pwa_install_controller.dart';
import 'package:tradepulse_frontend/core/services/settings_controller.dart';
import 'package:tradepulse_frontend/core/services/trading_controller.dart';
import 'package:tradepulse_frontend/core/services/trading_service.dart';
import 'package:tradepulse_frontend/core/theme/app_theme.dart';
import 'package:tradepulse_frontend/core/utils/validators.dart';
import 'package:tradepulse_frontend/models/live_wallet_models.dart';
import 'package:tradepulse_frontend/screens/wallet/live_withdraw_screen.dart';

class _SilentTrading extends TradingService {
  @override
  Future<void> ensureAccount() async {}

  @override
  Future<Map<String, dynamic>> previewWithdrawal({
    required double amount,
    required String method,
    required String address,
  }) async {
    return {
      'reason': 'deposit_required',
      'request_created': false,
      'balance_deducted': false,
    };
  }
}

Widget _app({required Widget home, double liveBalance = 0}) {
  return MaterialApp(
    theme: AppTheme.dark(),
    home: home,
    builder: (context, child) {
      return AuthScope(
        auth: AuthController(LocalAuthService()),
        child: SettingsScope(
          settings: SettingsController(),
          child: MarketScope(
            market: MarketController(OfflineMarketDataService()),
            child: TradingScope(
              trading: TradingController(_SilentTrading())
                ..liveBalance = liveBalance
                ..balance = 10000,
              child: LiveWalletScope(
                wallet: LiveWalletController(),
                child: PwaInstallScope(
                  install: PwaInstallController(),
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

Future<void> _submit(WidgetTester tester) async {
  await tester.ensureVisible(find.widgetWithText(FilledButton, 'Submit Withdrawal'));
  await tester.tap(find.widgetWithText(FilledButton, 'Submit Withdrawal'));
  await tester.pump();
}

void main() {
  test('withdraw validators cover amount and addresses', () {
    expect(Validators.withdrawAmount('49.99'), Validators.withdrawMinMessage);
    expect(Validators.withdrawAmount('50'), isNull);
    expect(Validators.withdrawAmount('10000'), isNull);
    expect(Validators.withdrawAmount('10000.01'), Validators.withdrawMaxMessage);
    expect(
      Validators.withdrawAddress(null, LivePaymentAsset.btc),
      Validators.withdrawAddressRequired,
    );
    expect(Validators.withdrawAddress('abc', null), Validators.withdrawMethodRequired);
    expect(Validators.withdrawAddress('abc', LivePaymentAsset.btc), Validators.withdrawBtcInvalid);
    expect(
      Validators.withdrawAddress('test', LivePaymentAsset.usdtTrc20),
      Validators.withdrawTrc20Invalid,
    );
    expect(
      Validators.withdrawAddress('0x12', LivePaymentAsset.eth),
      Validators.withdrawEthInvalid,
    );
    expect(
      Validators.withdrawAddress(
        '1CUXN4MrQ9qyZBtqU6Pg4U7iZiy6Y3ztMt',
        LivePaymentAsset.btc,
      ),
      isNull,
    );
    expect(
      Validators.withdrawAddress(
        'THfnsscby3ZW3LPGbTyGLyLkFsFdRwV5Xq',
        LivePaymentAsset.usdtTrc20,
      ),
      isNull,
    );
    expect(
      Validators.withdrawAddress(
        '0x27e711D1B6E4866EBf7904B3B631f6D05518E1B6',
        LivePaymentAsset.eth,
      ),
      isNull,
    );
  });

  testWidgets('withdraw form validates amount before deposit message', (tester) async {
    tester.view.physicalSize = const Size(1280, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_app(home: const LiveWithdrawScreen(), liveBalance: 200));
    await tester.pump();
    expect(find.text('Submit Withdrawal'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '20');
    await _submit(tester);
    expect(find.text(Validators.withdrawMinMessage), findsWidgets);
    expect(find.text(Validators.withdrawDepositRequired), findsNothing);

    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '10000.01');
    await _submit(tester);
    expect(find.text(Validators.withdrawMaxMessage), findsWidgets);
    expect(find.text(Validators.withdrawDepositRequired), findsNothing);
  });

  testWidgets('withdraw requires method and valid address', (tester) async {
    tester.view.physicalSize = const Size(1280, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_app(home: const LiveWithdrawScreen(), liveBalance: 200));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '100');
    await _submit(tester);
    expect(find.text(Validators.withdrawMethodRequired), findsOneWidget);

    await tester.tap(find.text('Bitcoin (BTC)'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextFormField, 'Payment address'), 'abc');
    await _submit(tester);
    expect(find.text(Validators.withdrawBtcInvalid), findsWidgets);
    expect(find.textContaining('not eligible for withdrawal'), findsNothing);

    await tester.tap(find.text('USDT — TRON (TRC20)'));
    await tester.pump();
    expect(find.text('Enter your USDT TRC20 wallet address'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Payment address'), 'hello');
    await _submit(tester);
    expect(find.text(Validators.withdrawTrc20Invalid), findsWidgets);

    await tester.tap(find.text('ETH — ERC20'));
    await tester.pump();
    expect(find.text('Enter your Ethereum ERC20 wallet address'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Payment address'), '0x12');
    await _submit(tester);
    expect(find.text(Validators.withdrawEthInvalid), findsWidgets);
  });

  testWidgets('insufficient live balance blocks deposit requirement message',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_app(home: const LiveWithdrawScreen()));
    await tester.pump();
    expect(find.text('Insufficient Balance'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '50');
    await tester.tap(find.text('Bitcoin (BTC)'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Payment address'),
      '1CUXN4MrQ9qyZBtqU6Pg4U7iZiy6Y3ztMt',
    );
    await _submit(tester);
    expect(find.text(Validators.withdrawInsufficient), findsOneWidget);
    expect(find.textContaining('not eligible for withdrawal'), findsNothing);
  });

  testWidgets('valid withdraw form shows deposit requirement only', (tester) async {
    tester.view.physicalSize = const Size(1280, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_app(home: const LiveWithdrawScreen(), liveBalance: 250));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '100');
    await tester.tap(find.text('Bitcoin (BTC)'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Payment address'),
      '1CUXN4MrQ9qyZBtqU6Pg4U7iZiy6Y3ztMt',
    );
    await _submit(tester);
    await tester.pump();
    expect(find.textContaining('not eligible for withdrawal'), findsOneWidget);
    expect(find.textContaining('deposit a minimum of \$50'), findsOneWidget);
    expect(find.text(Validators.withdrawInsufficient), findsNothing);
  });
}
