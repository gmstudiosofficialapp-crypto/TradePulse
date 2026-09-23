import 'package:flutter_test/flutter_test.dart';
import 'package:tradepulse_frontend/core/services/trading_controller.dart';
import 'package:tradepulse_frontend/core/services/trading_service.dart';
import 'package:tradepulse_frontend/models/trade_models.dart';

class _NoRemoteTrading extends TradingService {
  @override
  Future<void> ensureAccount() async {}

  @override
  Future<double> getBalance(String userId) async => 10000;

  @override
  Future<DemoStatistics> getStatistics(String userId) async =>
      const DemoStatistics();

  @override
  Future<List<DemoTrade>> getTrades(String userId) async => [];
}

void main() {
  test('applyEvent ignores another user trade and balance', () {
    final trading = TradingController(_NoRemoteTrading())..userId = 'user-a';
    trading.applyEvent({
      'type': 'trade_opened',
      'user_id': 'user-b',
      'trade': {
        'trade_id': 'leak-1',
        'user_id': 'user-b',
        'asset': 'BTC/USD-OTC',
        'direction': 'BUY',
        'stake': 10,
        'entry_price': 100,
        'entry_time': DateTime.utc(2026, 1, 1).toIso8601String(),
        'expiry_time': DateTime.utc(2026, 1, 1, 0, 1).toIso8601String(),
        'status': 'OPEN',
      },
    });
    expect(trading.history, isEmpty);
    expect(trading.activeTrades, isEmpty);

    trading.applyEvent({
      'type': 'balance_updated',
      'user_id': 'user-b',
      'balance': 1,
    });
    expect(trading.balance, 10000);

    trading.applyEvent({
      'type': 'trade_opened',
      'user_id': 'user-a',
      'trade': {
        'trade_id': 'own-1',
        'user_id': 'user-a',
        'asset': 'BTC/USD-OTC',
        'direction': 'BUY',
        'stake': 10,
        'entry_price': 100,
        'entry_time': DateTime.utc(2026, 1, 1).toIso8601String(),
        'expiry_time': DateTime.utc(2026, 1, 1, 0, 1).toIso8601String(),
        'status': 'OPEN',
      },
    });
    expect(trading.history.single.tradeId, 'own-1');

    trading.applyEvent({
      'type': 'balance_updated',
      'user_id': 'user-a',
      'balance': 9990,
    });
    expect(trading.balance, 9990);
  });
}
