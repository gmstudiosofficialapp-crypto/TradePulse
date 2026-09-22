import '../../models/market_models.dart';
import '../../models/trade_models.dart';

class ChartEntryMarker {
  const ChartEntryMarker({
    required this.tradeId,
    required this.asset,
    required this.entryTime,
    required this.entryPrice,
    required this.direction,
    required this.stake,
    required this.expirySeconds,
    this.result,
  });

  final String tradeId;
  final String asset;
  final DateTime entryTime;
  final double entryPrice;
  final String direction;
  final double stake;
  final int expirySeconds;
  final String? result;

  factory ChartEntryMarker.fromTrade(DemoTrade trade) {
    return ChartEntryMarker(
      tradeId: trade.tradeId,
      asset: trade.asset,
      entryTime: trade.entryTime.toUtc(),
      entryPrice: trade.entryPrice,
      direction: trade.direction,
      stake: trade.stake,
      expirySeconds: trade.durationSeconds,
      result: trade.result,
    );
  }

  static List<ChartEntryMarker> uniqueForAsset(
    String asset,
    Iterable<DemoTrade> trades,
  ) {
    final byId = <String, ChartEntryMarker>{};
    for (final trade in trades) {
      if (trade.asset != asset || !trade.isOpen) continue;
      byId[trade.tradeId] = ChartEntryMarker.fromTrade(trade);
    }
    return byId.values.toList();
  }
}

bool candleContainsEntry(MarketCandle candle, DateTime entryTime) {
  final time = entryTime.toUtc();
  final open = candle.openTime.toUtc();
  final close = candle.closeTime.toUtc();
  final windowEnd = candle.closed
      ? close
      : (close.isBefore(open.add(const Duration(minutes: 1)))
          ? open.add(const Duration(minutes: 1))
          : close);
  return !time.isBefore(open) && time.isBefore(windowEnd);
}

int? indexOfEntry(List<MarketCandle> candles, DateTime entryTime) {
  for (var index = 0; index < candles.length; index++) {
    if (candleContainsEntry(candles[index], entryTime)) return index;
  }
  return null;
}

MarketCandle? candleForEntry(List<MarketCandle> candles, DateTime entryTime) {
  for (final candle in candles) {
    if (candleContainsEntry(candle, entryTime)) return candle;
  }
  return null;
}

class ChartSignalSpan {
  const ChartSignalSpan({
    required this.signalId,
    required this.asset,
    required this.direction,
    required this.entryTime,
    required this.entryPrice,
    required this.status,
    this.closeTime,
    this.closePrice,
    this.result,
  });

  final String signalId;
  final String asset;
  final String direction;
  final DateTime entryTime;
  final double entryPrice;
  final String status;
  final DateTime? closeTime;
  final double? closePrice;
  final String? result;

  bool get isClosed => status == 'CLOSED' || result != null;

  factory ChartSignalSpan.fromSignal(TradeSignal signal) {
    return ChartSignalSpan(
      signalId: signal.signalId,
      asset: signal.asset,
      direction: signal.direction,
      entryTime: (signal.generatedAt ?? DateTime.now()).toUtc(),
      entryPrice: signal.entryPrice,
      status: signal.status,
      closeTime: signal.isOpen ? null : signal.expiryTime?.toUtc(),
      closePrice: signal.closePrice,
      result: signal.result,
    );
  }

  static List<ChartSignalSpan> uniqueForAsset(
    String asset,
    Iterable<TradeSignal> signals,
  ) {
    final byId = <String, ChartSignalSpan>{};
    for (final signal in signals) {
      if (signal.asset != asset ||
          !signal.isDirectional ||
          signal.signalId.isEmpty ||
          !signal.isOpen) {
        continue;
      }
      byId[signal.signalId] = ChartSignalSpan.fromSignal(signal);
    }
    return byId.values.toList();
  }
}
