import 'package:flutter_test/flutter_test.dart';
import 'package:tradepulse_frontend/models/market_models.dart';

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
}
