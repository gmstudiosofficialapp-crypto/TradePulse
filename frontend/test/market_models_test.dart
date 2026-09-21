import 'package:flutter_test/flutter_test.dart';
import 'package:tradepulse_frontend/core/services/market_controller.dart';
import 'package:tradepulse_frontend/core/services/offline_market_data_service.dart';
import 'package:tradepulse_frontend/models/market_models.dart';

class _QuoteFeed extends OfflineMarketDataService {
  List<MarketQuote> next = [];

  @override
  Future<List<MarketQuote>> getQuotes() async => next;

  @override
  Future<MarketStatus> getStatus() async {
    return const MarketStatus(
      state: EngineState.liveSimulation,
      simulated: true,
    );
  }
}

void main() {
  test('parses valid candle json', () {
    final candle = MarketCandle.fromJson({
      'asset': 'BTC/USD-OTC',
      'open': 1,
      'high': 2,
      'low': 0.5,
      'close': 1.5,
      'volume': 4,
      'open_time': '2026-09-18T12:00:00+00:00',
      'close_time': '2026-09-18T12:01:00+00:00',
      'closed': true,
    });
    expect(candle.high, 2);
    expect(candle.asset, 'BTC/USD-OTC');
  });

  test('invalid market json throws', () {
    expect(
      () => MarketCandle.fromJson({'open': 'bad'}),
      throwsA(isA<Object>()),
    );
  });

  test('stale http quotes do not replace a newer tick', () async {
    final feed = _QuoteFeed();
    final newer = DateTime.utc(2026, 9, 21, 12, 0, 2);
    final older = DateTime.utc(2026, 9, 21, 12, 0, 1);
    feed.next = [
      MarketQuote(
        asset: 'BTC/USD-OTC',
        price: 100,
        changePct: 0.1,
        timestamp: newer,
      ),
    ];
    final market = MarketController(feed);
    await market.start();
    expect(market.quotes['BTC/USD-OTC']?.price, 100);
    feed.next = [
      MarketQuote(
        asset: 'BTC/USD-OTC',
        price: 90,
        changePct: -0.1,
        timestamp: older,
      ),
    ];
    await market.refresh();
    expect(market.quotes['BTC/USD-OTC']?.price, 100);
    market.dispose();
  });
}
