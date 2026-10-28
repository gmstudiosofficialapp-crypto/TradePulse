import 'package:flutter_test/flutter_test.dart';
import 'package:tradepulse_frontend/core/services/trading_controller.dart';
import 'package:tradepulse_frontend/core/services/trading_service.dart';
import 'package:tradepulse_frontend/models/trade_models.dart';

class _SkewedTrading extends TradingService {
  DemoTrade? server;

  @override
  Future<void> ensureAccount() async {}

  @override
  Future<double> getBalance(String userId) async => 10000;

  @override
  Future<double> getLiveBalance(String userId) async => 0;

  @override
  Future<DemoStatistics> getStatistics(String userId) async =>
      const DemoStatistics(currentBalance: 10000);

  @override
  Future<DemoStatistics> getLiveStatistics(String userId) async =>
      const DemoStatistics();

  @override
  Future<List<DemoTrade>> getTrades(String userId) async =>
      server == null ? [] : [server!];

  @override
  Future<List<DemoTrade>> getLiveTrades(String userId) async => [];

  @override
  Future<DemoTrade> openTrade({
    required String userId,
    required String asset,
    required String direction,
    required double stake,
    int expirySeconds = 60,
    bool live = false,
  }) async {
    final serverNow = DateTime.now().toUtc().add(const Duration(seconds: 23));
    server = DemoTrade(
      tradeId: 'server-1',
      asset: asset,
      direction: direction,
      stake: stake,
      entryPrice: 100,
      entryTime: serverNow,
      expiryTime: serverNow.add(Duration(seconds: expirySeconds)),
      status: 'OPEN',
      expirySeconds: expirySeconds,
    );
    return server!;
  }
}

void main() {
  test('countdown stays on the device clock after the server trade arrives', () async {
    final trading = TradingController(_SkewedTrading())..userId = 'user-1';
    trading.expirySeconds = 60;
    await trading.openTrade(asset: 'BTC/USD-OTC', direction: 'BUY');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final trade = trading.activeTrades.single;
    final remain = trade.expiryTime.difference(DateTime.now().toUtc()).inSeconds;
    expect(trade.tradeId, 'server-1');
    expect(remain, inInclusiveRange(55, 60));
  });
}
