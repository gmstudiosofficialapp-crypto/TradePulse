import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradepulse_frontend/core/routes/app_routes.dart';
import 'package:tradepulse_frontend/core/services/app_scope.dart';
import 'package:tradepulse_frontend/core/services/auth_controller.dart';
import 'package:tradepulse_frontend/core/services/local_auth_service.dart';
import 'package:tradepulse_frontend/core/services/market_controller.dart';
import 'package:tradepulse_frontend/core/services/offline_market_data_service.dart';
import 'package:tradepulse_frontend/core/services/settings_controller.dart';
import 'package:tradepulse_frontend/core/services/trading_controller.dart';
import 'package:tradepulse_frontend/core/services/trading_service.dart';
import 'package:tradepulse_frontend/core/theme/app_theme.dart';
import 'package:tradepulse_frontend/models/market_models.dart';
import 'package:tradepulse_frontend/models/trade_models.dart';
import 'package:tradepulse_frontend/screens/history/history_screen.dart';
import 'package:tradepulse_frontend/screens/markets/markets_screen.dart';
import 'package:tradepulse_frontend/screens/trade/trade_screen.dart';
import 'package:tradepulse_frontend/widgets/cards/demo_balance_card.dart';
import 'package:tradepulse_frontend/widgets/charts/candlestick_chart.dart';

class _SlowTrading extends _FakeTrading {
  @override
  Future<DemoTrade> openTrade({
    required String userId,
    required String asset,
    required String direction,
    required double stake,
    int expirySeconds = 60,
    bool live = false,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 280));
    return super.openTrade(
      userId: userId,
      asset: asset,
      direction: direction,
      stake: stake,
      expirySeconds: expirySeconds,
      live: live,
    );
  }
}

class _FakeTrading extends TradingService {
  String? lastAsset;
  int? lastExpiry;
  int _opens = 0;
  double _balance = 10000;
  final List<DemoTrade> opened = [];

  @override
  Future<void> ensureAccount() async {}

  @override
  Future<double> getBalance(String userId) async => _balance;

  @override
  Future<double> creditDemo(double amount) async {
    _balance += amount;
    return _balance;
  }

  @override
  Future<DemoStatistics> getStatistics(String userId) async =>
      DemoStatistics(currentBalance: _balance);

  @override
  Future<List<DemoTrade>> getTrades(String userId) async => List.of(opened);

  @override
  Future<List<TradeSignal>> listSignals(String asset) async => [];

  @override
  Future<TradeSignal> latestSignal(String asset) async => TradeSignal(
        asset: asset,
        direction: 'BUY',
        confidence: 0.91,
        status: 'ACTIVE',
      );

  @override
  Future<DemoTrade> openTrade({
    required String userId,
    required String asset,
    required String direction,
    required double stake,
    int expirySeconds = 60,
    bool live = false,
  }) async {
    lastAsset = asset;
    lastExpiry = expirySeconds;
    _opens += 1;
    _balance -= stake;
    final trade = DemoTrade(
      tradeId: 'opened-$_opens',
      asset: asset,
      direction: direction,
      stake: stake,
      entryPrice: 100,
      entryTime: DateTime.now().toUtc(),
      expiryTime: DateTime.now().toUtc().add(Duration(seconds: expirySeconds)),
      status: 'OPEN',
      expirySeconds: expirySeconds,
    );
    opened.add(trade);
    return trade;
  }
}

Widget _harness({
  required Widget child,
  TradingController? trading,
  MarketController? market,
  SettingsController? settings,
  Size size = const Size(1280, 1600),
}) {
  final providedMarket = market != null;
  final marketCtrl = market ?? MarketController(OfflineMarketDataService());
  marketCtrl.quotes['BTC/USD-OTC'] = MarketQuote(
    asset: 'BTC/USD-OTC',
    price: 67000,
    changePct: 0.4,
    timestamp: DateTime.now().toUtc(),
  );
  marketCtrl.quotes['EUR/USD-OTC'] = MarketQuote(
    asset: 'EUR/USD-OTC',
    price: 1.08,
    changePct: -0.1,
    timestamp: DateTime.now().toUtc(),
  );
  marketCtrl.quotes['GOLD/USD-OTC'] = MarketQuote(
    asset: 'GOLD/USD-OTC',
    price: 2400,
    changePct: 0.2,
    timestamp: DateTime.now().toUtc(),
  );
  if (!providedMarket) {
    marketCtrl.status = const MarketStatus(
      state: EngineState.liveSimulation,
      simulated: true,
    );
  }
  final ledger = trading ?? TradingController(_FakeTrading());
  ledger.signal = const TradeSignal(
    asset: 'BTC/USD-OTC',
    direction: 'BUY',
    confidence: 0.91,
    status: 'ACTIVE',
  );
  ledger.balance = 10000;
  return MaterialApp(
    theme: AppTheme.dark(),
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: AuthScope(
        auth: AuthController(LocalAuthService()),
        child: SettingsScope(
          settings: settings ?? SettingsController(),
          child: MarketScope(
            market: marketCtrl,
            child: TradingScope(
              trading: ledger,
              child: Scaffold(body: child),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('signal display', (tester) async {
    await tester.pumpWidget(_harness(child: const TradeScreen()));
    await tester.pump();
    expect(find.textContaining('BUY'), findsWidgets);
    expect(find.textContaining('BUY 91%'), findsNothing);
    expect(find.textContaining('Confidence:'), findsNothing);
    expect(find.textContaining('SELL 91%'), findsNothing);
  });

  testWidgets('BUY and SELL controls', (tester) async {
    await tester.pumpWidget(_harness(child: const TradeScreen()));
    await tester.pump();
    expect(find.text('BUY', skipOffstage: false), findsWidgets);
    expect(find.text('SELL', skipOffstage: false), findsWidgets);
    expect(find.text('CALL'), findsNothing);
    expect(find.text('PUT'), findsNothing);
  });

  testWidgets('demo balance display', (tester) async {
    await tester.pumpWidget(_harness(child: const DemoBalanceCard()));
    await tester.pump();
    expect(find.text(r'$10,000.00'), findsOneWidget);
    expect(find.textContaining('DEMO'), findsWidgets);
  });

  testWidgets('active trade state', (tester) async {
    final trading = TradingController(_FakeTrading());
    trading.activeTrade = DemoTrade(
      tradeId: 't1',
      asset: 'BTC/USD-OTC',
      direction: 'BUY',
      stake: 10,
      entryPrice: 67000,
      entryTime: DateTime.now().toUtc(),
      expiryTime: DateTime.now().toUtc().add(const Duration(seconds: 40)),
      status: 'OPEN',
      expirySeconds: 40,
    );
    await tester.pumpWidget(_harness(child: const TradeScreen(), trading: trading));
    await tester.pump();
    expect(find.textContaining('Active 1', skipOffstage: false), findsOneWidget);
    await tester.tap(find.textContaining('Active 1'));
    await tester.pump();
    expect(find.textContaining('BUY', skipOffstage: false), findsWidgets);
  });

  testWidgets('result state', (tester) async {
    final trading = TradingController(_FakeTrading());
    trading.lastResult = DemoTrade(
      tradeId: 't2',
      asset: 'BTC/USD-OTC',
      direction: 'SELL',
      stake: 10,
      entryPrice: 67000,
      entryTime: DateTime.now().toUtc(),
      expiryTime: DateTime.now().toUtc(),
      status: 'CLOSED',
      expiryPrice: 66900,
      result: 'WIN',
      profitLoss: 8.5,
    );
    await tester.pumpWidget(_harness(child: const TradeScreen(), trading: trading));
    await tester.pump();
    expect(find.textContaining('P/L'), findsNothing);
    expect(find.textContaining('BTC/USD-OTC   P/L'), findsNothing);
  });

  testWidgets('history rendering', (tester) async {
    final trading = TradingController(_FakeTrading());
    trading.history = [
      DemoTrade(
        tradeId: 't3',
        asset: 'ETH/USD-OTC',
        direction: 'BUY',
        stake: 25,
        entryPrice: 3200,
        entryTime: DateTime.now().toUtc(),
        expiryTime: DateTime.now().toUtc(),
        status: 'CLOSED',
        expiryPrice: 3210,
        result: 'WIN',
        profitLoss: 21.25,
        expirySeconds: 30,
      ),
    ];
    trading.statistics = const DemoStatistics(
      totalTrades: 1,
      wins: 1,
      currentBalance: 10021.25,
      winRate: 100,
    );
    await tester.pumpWidget(_harness(child: const HistoryScreen(), trading: trading));
    await tester.pump();
    expect(find.textContaining('ETH/USD-OTC'), findsOneWidget);
    expect(find.textContaining('WIN'), findsWidgets);
    expect(find.text('ALL'), findsOneWidget);
    expect(find.text('Your completed trades will appear here.'), findsNothing);
  });

  testWidgets('history filters', (tester) async {
    final trading = TradingController(_FakeTrading());
    trading.history = [
      DemoTrade(
        tradeId: 'w',
        asset: 'BTC/USD-OTC',
        direction: 'BUY',
        stake: 10,
        entryPrice: 1,
        entryTime: DateTime.now().toUtc(),
        expiryTime: DateTime.now().toUtc(),
        status: 'CLOSED',
        result: 'WIN',
        profitLoss: 8.5,
      ),
      DemoTrade(
        tradeId: 'l',
        asset: 'EUR/USD-OTC',
        direction: 'SELL',
        stake: 10,
        entryPrice: 1,
        entryTime: DateTime.now().toUtc(),
        expiryTime: DateTime.now().toUtc(),
        status: 'CLOSED',
        result: 'LOSS',
        profitLoss: -10,
      ),
    ];
    await tester.pumpWidget(_harness(child: const HistoryScreen(), trading: trading));
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, 'LOSS'));
    await tester.pump();
    expect(find.textContaining('EUR/USD-OTC'), findsWidgets);
    expect(find.textContaining('BTC/USD-OTC'), findsNothing);
  });

  testWidgets('responsive trade layout', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      _harness(child: const TradeScreen(), size: const Size(390, 844)),
    );
    await tester.pump();
    expect(find.text('BUY', skipOffstage: false), findsWidgets);
    tester.view.physicalSize = const Size(1280, 800);
    await tester.pumpWidget(_harness(child: const TradeScreen()));
    await tester.pump();
    expect(find.text('SELL', skipOffstage: false), findsWidgets);
  });

  testWidgets('websocket reconnect state', (tester) async {
    final market = MarketController(OfflineMarketDataService());
    market.status = const MarketStatus(
      state: EngineState.reconnecting,
      simulated: true,
    );
    await tester.pumpWidget(
      _harness(child: const TradeScreen(), market: market),
    );
    await tester.pump();
    expect(find.text('RECONNECTING'), findsOneWidget);
  });

  testWidgets('trade opens requested asset', (tester) async {
    final market = MarketController(OfflineMarketDataService());
    market.status = const MarketStatus(
      state: EngineState.liveSimulation,
      simulated: true,
    );
    await tester.pumpWidget(
      _harness(
        child: const TradeScreen(initialAsset: 'GOLD/USD-OTC'),
        market: market,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(market.focusedAsset, 'GOLD/USD-OTC');
    expect(find.text('GOLD/USD-OTC'), findsWidgets);
  });

  testWidgets('expiry chips are present', (tester) async {
    await tester.pumpWidget(_harness(child: const TradeScreen()));
    await tester.pump();
    expect(find.text('5s'), findsOneWidget);
    expect(find.text('15s'), findsOneWidget);
    expect(find.text('30s'), findsOneWidget);
    expect(find.text('1m'), findsOneWidget);
    expect(find.text('5m'), findsOneWidget);
    expect(find.text('15m'), findsOneWidget);
  });

  testWidgets('chart interaction does not place trades', (tester) async {
    final service = _FakeTrading();
    final trading = TradingController(service)..userId = 'ada@example.com';
    await tester.pumpWidget(_harness(child: const TradeScreen(), trading: trading));
    await tester.pump();
    await tester.tap(find.byType(CandlestickChart));
    await tester.pump();
    expect(service.lastAsset, isNull);
    expect(trading.activeTrade, isNull);
  });

  testWidgets('entry marker appears before the server open returns', (tester) async {
    final service = _SlowTrading();
    final trading = TradingController(service)..userId = 'ada@example.com';
    final opened = trading.openTrade(
      asset: 'BTC/USD-OTC',
      direction: 'BUY',
      entryPrice: 67245,
    );
    await tester.pump();
    expect(trading.activeTrades, hasLength(1));
    expect(trading.activeTrades.single.tradeId, startsWith('pending-'));
    expect(trading.activeTrades.single.entryPrice, 67245);
    await tester.pump(const Duration(milliseconds: 350));
    await opened;
    expect(trading.activeTrades, hasLength(1));
    expect(trading.activeTrades.single.tradeId, 'opened-1');
    expect(service.opened, hasLength(1));
  });

  testWidgets('multiple independent demo trades can stay open', (tester) async {
    final service = _FakeTrading();
    final trading = TradingController(service)..userId = 'ada@example.com';
    await trading.openTrade(asset: 'BTC/USD-OTC', direction: 'BUY');
    await trading.openTrade(asset: 'BTC/USD-OTC', direction: 'SELL');
    expect(trading.activeTrades, hasLength(2));
    expect(trading.activeTrades.map((item) => item.direction).toSet(), {'BUY', 'SELL'});
    expect(trading.canOpenTrade('BTC/USD-OTC'), isTrue);
  });

  testWidgets('eleventh trade is rejected with a clear message', (tester) async {
    final service = _FakeTrading();
    final trading = TradingController(service)..userId = 'ada@example.com';
    for (var i = 0; i < 10; i++) {
      await trading.openTrade(asset: 'BTC/USD-OTC', direction: 'BUY');
    }
    await trading.openTrade(asset: 'BTC/USD-OTC', direction: 'SELL');
    expect(trading.activeTrades, hasLength(10));
    expect(trading.error, 'Maximum 10 active trades reached.');
    expect(service.opened, hasLength(10));
  });

  testWidgets('trade amount bounds are validated', (tester) async {
    final trading = TradingController(_FakeTrading())..userId = 'ada@example.com';
    trading.setStake(0.5);
    await trading.openTrade(asset: 'BTC/USD-OTC', direction: 'BUY');
    expect(trading.error, r'Minimum trade amount is $1.');
    expect(trading.activeTrades, isEmpty);
    trading.setStake(10001);
    await trading.openTrade(asset: 'BTC/USD-OTC', direction: 'BUY');
    expect(trading.error, r'Maximum trade amount is $10,000.');
    trading.setStake(1);
    await trading.openTrade(asset: 'BTC/USD-OTC', direction: 'BUY');
    expect(trading.activeTrades, hasLength(1));
    trading.setStake(10);
    await trading.openTrade(asset: 'BTC/USD-OTC', direction: 'SELL');
    expect(trading.activeTrades, hasLength(2));
    trading.setStake(10000);
    await trading.openTrade(asset: 'BTC/USD-OTC', direction: 'BUY');
    expect(trading.error, 'Insufficient demo balance');
  });

  testWidgets('demo deposit is immediately spendable', (tester) async {
    final service = _FakeTrading();
    final trading = TradingController(service)..userId = 'ada@example.com';
    await trading.addDemoFunds(5000);
    expect(trading.demoDisplayBalance, 15000);
    trading.setStake(10000);
    await trading.openTrade(asset: 'BTC/USD-OTC', direction: 'BUY');
    expect(trading.activeTrades, hasLength(1));
    expect(trading.demoDisplayBalance, 5000);
  });

  testWidgets('markets card navigates with asset argument', (tester) async {
    String? opened;
    final market = MarketController(OfflineMarketDataService());
    market.status = const MarketStatus(
      state: EngineState.liveSimulation,
      simulated: true,
    );
    final trading = TradingController(_FakeTrading());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.trade) {
            opened = settings.arguments as String?;
            return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('opened-trade')),
            );
          }
          return MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('other')),
          );
        },
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1280, 1600)),
          child: AuthScope(
            auth: AuthController(LocalAuthService()),
            child: SettingsScope(
              settings: SettingsController(),
              child: MarketScope(
                market: market,
                child: TradingScope(
                  trading: trading,
                  child: const MarketsScreen(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('EUR/USD-OTC').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(opened, 'EUR/USD-OTC');
    expect(market.focusedAsset, 'EUR/USD-OTC');
  });

  testWidgets('live mode buy does not open a trade', (tester) async {
    final service = _FakeTrading();
    final trading = TradingController(service)..userId = 'ada@example.com';
    final settings = SettingsController()..setTradingUiMode(TradingUiMode.live);
    await tester.pumpWidget(
      _harness(child: const TradeScreen(), trading: trading, settings: settings),
    );
    await tester.pump();
    await tester.tap(find.text('BUY').first);
    await tester.pump();
    expect(find.text('Insufficient Balance'), findsOneWidget);
    expect(service.lastAsset, isNull);
    expect(trading.activeTrades, isEmpty);
  });
}
