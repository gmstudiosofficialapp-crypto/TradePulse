import '../../models/market_models.dart';

class CandleTimeframe {
  const CandleTimeframe._();

  static const options = [5, 15, 30, 60];

  static DateTime bucketStart(DateTime stamp, int seconds) {
    final utc = stamp.toUtc();
    final size = seconds * 1000;
    final epoch = utc.millisecondsSinceEpoch;
    return DateTime.fromMillisecondsSinceEpoch(epoch - epoch % size, isUtc: true);
  }

  static List<MarketCandle> fromMinutes(
    List<MarketCandle> minutes, {
    required int seconds,
    int keep = 240,
  }) {
    if (seconds >= 60) {
      if (minutes.length <= keep) return List.of(minutes);
      return minutes.sublist(minutes.length - keep);
    }
    final out = <MarketCandle>[];
    for (final minute in minutes) {
      out.addAll(splitMinute(minute, seconds));
    }
    if (out.length <= keep) return out;
    return out.sublist(out.length - keep);
  }

  static List<MarketCandle> splitMinute(MarketCandle minute, int seconds) {
    final count = 60 ~/ seconds;
    if (count <= 1) return [minute];
    final bullish = minute.close >= minute.open;
    final path = bullish
        ? [minute.open, minute.low, minute.high, minute.close]
        : [minute.open, minute.high, minute.low, minute.close];
    double sample(double t) {
      final x = (t * 3).clamp(0, 3);
      final index = x.floor().clamp(0, 2);
      final frac = x - index;
      return path[index] + (path[index + 1] - path[index]) * frac;
    }

    final rows = <MarketCandle>[];
    for (var i = 0; i < count; i++) {
      final startT = i / count;
      final endT = (i + 1) / count;
      var high = sample(startT);
      var low = high;
      for (var step = 0; step <= 6; step++) {
        final price = sample(startT + (endT - startT) * (step / 6));
        if (price > high) high = price;
        if (price < low) low = price;
      }
      final open = i == 0 ? minute.open : rows.last.close;
      final close = sample(endT);
      final openTime = minute.openTime.toUtc().add(Duration(seconds: i * seconds));
      final isLast = i == count - 1;
      rows.add(
        MarketCandle(
          asset: minute.asset,
          open: open,
          high: [high, open, close].reduce((a, b) => a > b ? a : b),
          low: [low, open, close].reduce((a, b) => a < b ? a : b),
          close: isLast && minute.closed ? minute.close : close,
          volume: 1,
          openTime: openTime,
          closeTime: openTime.add(Duration(seconds: seconds)),
          closed: minute.closed || !isLast,
        ),
      );
    }
    return rows;
  }
}
