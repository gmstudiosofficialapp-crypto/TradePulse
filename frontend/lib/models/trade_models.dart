class TradeSignal {
  const TradeSignal({
    required this.asset,
    required this.direction,
    required this.confidence,
    required this.status,
    this.entryPrice = 0,
    this.timeframe = '1m',
    this.signalId = '',
    this.generatedAt,
    this.expiryTime,
    this.closePrice,
    this.result,
    this.expirySeconds = 60,
  });

  final String asset;
  final String direction;
  final double confidence;
  final String status;
  final double entryPrice;
  final String timeframe;
  final String signalId;
  final DateTime? generatedAt;
  final DateTime? expiryTime;
  final double? closePrice;
  final String? result;
  final int expirySeconds;

  bool get isDirectional => direction == 'BUY' || direction == 'SELL';
  bool get isOpen => isDirectional && result == null && status != 'CLOSED' && status != 'WAITING';

  factory TradeSignal.waiting(String asset) => TradeSignal(
        asset: asset,
        direction: 'NO SIGNAL',
        confidence: 0,
        status: 'WAITING',
      );

  factory TradeSignal.fromJson(Map<String, dynamic> json) {
    final raw = (json['direction'] as String? ?? 'NO_SIGNAL').replaceAll('_', ' ');
    DateTime? parseTime(String? value) =>
        value == null || value.isEmpty ? null : DateTime.tryParse(value)?.toUtc();
    return TradeSignal(
      asset: json['asset'] as String? ?? '',
      direction: raw,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'WAITING',
      entryPrice: (json['entry_price'] as num?)?.toDouble() ?? 0,
      timeframe: json['timeframe'] as String? ?? '1m',
      signalId: json['signal_id'] as String? ?? '',
      generatedAt: parseTime(json['generated_at'] as String?),
      expiryTime: parseTime(json['expiry_time'] as String?),
      closePrice: (json['close_price'] as num?)?.toDouble() ??
          (json['expiry_price'] as num?)?.toDouble(),
      result: json['result'] as String?,
      expirySeconds: (json['expiry_seconds'] as num?)?.toInt() ?? 60,
    );
  }
}

class DemoTrade {
  const DemoTrade({
    required this.tradeId,
    required this.asset,
    required this.direction,
    required this.stake,
    required this.entryPrice,
    required this.entryTime,
    required this.expiryTime,
    required this.status,
    this.expiryPrice,
    this.result,
    this.profitLoss = 0,
    this.payoutRate = 0.85,
    this.expirySeconds = 60,
    this.accountType = 'DEMO',
  });

  final String tradeId;
  final String asset;
  final String direction;
  final double stake;
  final double entryPrice;
  final DateTime entryTime;
  final DateTime expiryTime;
  final String status;
  final double? expiryPrice;
  final String? result;
  final double profitLoss;
  final double payoutRate;
  final int expirySeconds;
  final String accountType;

  bool get isOpen => result == null && status == 'OPEN';

  int get durationSeconds {
    if (expirySeconds > 0) return expirySeconds;
    return expiryTime.difference(entryTime).inSeconds.abs();
  }

  factory DemoTrade.fromJson(Map<String, dynamic> json) {
    return DemoTrade(
      tradeId: json['trade_id'] as String,
      asset: json['asset'] as String,
      direction: json['direction'] as String,
      stake: (json['stake'] as num).toDouble(),
      entryPrice: (json['entry_price'] as num).toDouble(),
      entryTime: DateTime.parse(json['entry_time'] as String).toUtc(),
      expiryTime: DateTime.parse(json['expiry_time'] as String).toUtc(),
      status: json['status'] as String? ?? 'OPEN',
      expiryPrice: (json['expiry_price'] as num?)?.toDouble(),
      result: json['result'] as String?,
      profitLoss: (json['profit_loss'] as num?)?.toDouble() ?? 0,
      payoutRate: (json['payout_rate'] as num?)?.toDouble() ?? 0.85,
      expirySeconds: (json['expiry_seconds'] as num?)?.toInt() ??
          DateTime.parse(json['expiry_time'] as String)
              .toUtc()
              .difference(DateTime.parse(json['entry_time'] as String).toUtc())
              .inSeconds
              .abs(),
      accountType: json['account_type'] as String? ?? 'DEMO',
    );
  }
}

class DemoStatistics {
  const DemoStatistics({
    this.totalTrades = 0,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.winRate = 0,
    this.totalProfitLoss = 0,
    this.currentBalance = 10000,
    this.bestStreak = 0,
    this.currentStreak = 0,
  });

  final int totalTrades;
  final int wins;
  final int losses;
  final int draws;
  final double winRate;
  final double totalProfitLoss;
  final double currentBalance;
  final int bestStreak;
  final int currentStreak;

  factory DemoStatistics.fromJson(Map<String, dynamic> json) {
    return DemoStatistics(
      totalTrades: json['total_trades'] as int? ?? 0,
      wins: json['wins'] as int? ?? 0,
      losses: json['losses'] as int? ?? 0,
      draws: json['draws'] as int? ?? 0,
      winRate: (json['win_rate'] as num?)?.toDouble() ?? 0,
      totalProfitLoss: (json['total_profit_loss'] as num?)?.toDouble() ?? 0,
      currentBalance: (json['current_balance'] as num?)?.toDouble() ?? 10000,
      bestStreak: json['best_streak'] as int? ?? 0,
      currentStreak: json['current_streak'] as int? ?? 0,
    );
  }
}
