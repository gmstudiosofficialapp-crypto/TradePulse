class MarketQuote {
  const MarketQuote({
    required this.asset,
    required this.price,
    required this.changePct,
    required this.timestamp,
    this.simulated = true,
  });

  final String asset;
  final double price;
  final double changePct;
  final DateTime timestamp;
  final bool simulated;

  factory MarketQuote.fromJson(Map<String, dynamic> json) {
    return MarketQuote(
      asset: json['asset'] as String,
      price: (json['price'] as num).toDouble(),
      changePct: (json['change_pct'] as num?)?.toDouble() ?? 0,
      timestamp: DateTime.parse(json['timestamp'] as String).toUtc(),
      simulated: json['simulated'] as bool? ?? true,
    );
  }
}

class MarketCandle {
  const MarketCandle({
    required this.asset,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    required this.openTime,
    required this.closeTime,
    required this.closed,
  });

  final String asset;
  final double open;
  final double high;
  final double low;
  final double close;
  final int volume;
  final DateTime openTime;
  final DateTime closeTime;
  final bool closed;

  factory MarketCandle.fromJson(Map<String, dynamic> json) {
    return MarketCandle(
      asset: json['asset'] as String? ?? '',
      open: (json['open'] as num).toDouble(),
      high: (json['high'] as num).toDouble(),
      low: (json['low'] as num).toDouble(),
      close: (json['close'] as num).toDouble(),
      volume: (json['volume'] as num?)?.toInt() ?? 0,
      openTime: DateTime.parse(json['open_time'] as String).toUtc(),
      closeTime: DateTime.parse(json['close_time'] as String).toUtc(),
      closed: json['closed'] as bool? ?? false,
    );
  }
}

enum EngineState { liveSimulation, offline, reconnecting }

class MarketStatus {
  const MarketStatus({
    required this.state,
    required this.simulated,
    this.message = '',
  });

  final EngineState state;
  final bool simulated;
  final String message;

  factory MarketStatus.fromJson(Map<String, dynamic> json) {
    final raw = json['state'] as String? ?? 'MARKET_OFFLINE';
    final state = switch (raw) {
      'LIVE_SIMULATION' => EngineState.liveSimulation,
      'RECONNECTING' => EngineState.reconnecting,
      _ => EngineState.offline,
    };
    return MarketStatus(
      state: state,
      simulated: json['simulated'] as bool? ?? true,
      message: json['message'] as String? ?? '',
    );
  }
}
