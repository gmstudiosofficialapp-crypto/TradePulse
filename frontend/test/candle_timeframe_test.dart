import 'package:flutter_test/flutter_test.dart';
import 'package:tradepulse_frontend/core/chart/candle_timeframe.dart';
import 'package:tradepulse_frontend/models/market_models.dart';

void main() {
  test('splits a closed minute into 5 second candles', () {
    final minute = MarketCandle(
      asset: 'BTC/USD-OTC',
      open: 100,
      high: 110,
      low: 90,
      close: 108,
      volume: 8,
      openTime: DateTime.utc(2026, 10, 28, 12),
      closeTime: DateTime.utc(2026, 10, 28, 12, 1),
      closed: true,
    );
    final rows = CandleTimeframe.splitMinute(minute, 5);
    expect(rows, hasLength(12));
    expect(rows.first.open, 100);
    expect(rows.last.close, 108);
    expect(rows.first.closed, isTrue);
    expect(rows.last.closed, isTrue);
  });

  test('keeps 1m candles when timeframe is 60 seconds', () {
    final minute = MarketCandle(
      asset: 'BTC/USD-OTC',
      open: 100,
      high: 110,
      low: 90,
      close: 108,
      volume: 8,
      openTime: DateTime.utc(2026, 10, 28, 12),
      closeTime: DateTime.utc(2026, 10, 28, 12, 1),
      closed: true,
    );
    final rows = CandleTimeframe.fromMinutes([minute], seconds: 60);
    expect(rows, hasLength(1));
    expect(rows.single.close, 108);
  });
}
