import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../models/trade_models.dart';
import 'trading_service.dart';

class TradingController extends ChangeNotifier {
  TradingController(this._service);

  final TradingService _service;
  String? userId;
  double balance = 10000;
  double sessionDemoCredit = 0;
  double stake = 10;
  int expirySeconds = 60;
  bool submitting = false;
  DemoStatistics statistics = const DemoStatistics();
  List<DemoTrade> history = [];
  List<TradeSignal> signals = [];
  DemoTrade? lastResult;
  TradeSignal signal = TradeSignal.waiting('BTC/USD-OTC');
  String? error;
  Timer? _poll;

  List<DemoTrade> get activeTrades =>
      history.where((trade) => trade.isOpen).toList();

  DemoTrade? get activeTrade =>
      activeTrades.isEmpty ? null : activeTrades.first;

  set activeTrade(DemoTrade? trade) {
    if (trade == null) {
      history = history.where((item) => !item.isOpen).toList();
      return;
    }
    _upsert(trade);
  }

  List<DemoTrade> activeTradesFor(String asset) =>
      activeTrades.where((trade) => trade.asset == asset).toList();

  List<TradeSignal> signalsFor(String asset) =>
      signals.where((item) => item.asset == asset && item.isDirectional).toList();

  List<TradeSignal> activeSignalsFor(String asset) =>
      signalsFor(asset).where((item) => item.isOpen).toList();

  double get demoDisplayBalance => balance + sessionDemoCredit;

  bool canOpenTrade(String asset) =>
      !submitting &&
      activeTradesFor(asset).length < AppConstants.maxActiveSignalsPerAsset;

  void addDemoFunds(double amount) {
    if (amount <= 0) return;
    sessionDemoCredit += amount;
    notifyListeners();
  }

  void restoreDemoFunds() {
    final needed = 10000 - demoDisplayBalance;
    if (needed > 0) sessionDemoCredit += needed;
    notifyListeners();
  }

  Future<void> bindUser(String? identity) async {
    userId = identity;
    _poll?.cancel();
    if (userId == null) return;
    try {
      await _service.ensureAccount();
    } catch (_) {}
    await refresh();
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => refresh());
  }

  Future<void> refresh({String? asset}) async {
    final id = userId;
    if (id == null) return;
    try {
      balance = await _service.getBalance(id);
      statistics = await _service.getStatistics(id);
      history = await _service.getTrades(id);
      if (asset != null) {
        await loadSignal(asset);
      }
      if (activeTrade == null && history.isNotEmpty && history.first.result != null) {
        lastResult = history.first;
      }
      error = null;
      notifyListeners();
    } catch (_) {
      error = 'Trading account unreachable';
      notifyListeners();
    }
  }

  Future<void> loadSignal(String asset) async {
    try {
      final listed = await _service.listSignals(asset);
      if (listed.isNotEmpty) {
        _mergeSignals(listed);
      }
      signal = await _service.latestSignal(asset);
      if (signal.isDirectional && signal.signalId.isNotEmpty) {
        _upsertSignal(signal);
      }
    } catch (_) {
      signal = TradeSignal.waiting(asset);
    }
    notifyListeners();
  }

  void setExpiry(int seconds) {
    expirySeconds = seconds;
    notifyListeners();
  }

  void setStake(double value) {
    stake = value.clamp(AppConstants.minStake, AppConstants.maxStake).toDouble();
    notifyListeners();
  }

  void bumpStake(double delta) {
    setStake(stake + delta);
  }

  Future<void> openTrade({
    required String asset,
    required String direction,
  }) async {
    final id = userId;
    if (id == null) {
      error = 'Sign in to place a trade';
      notifyListeners();
      return;
    }
    if (submitting) return;
    if (stake < AppConstants.minStake || stake > AppConstants.maxStake) {
      error = 'Amount must be \$1.00 to \$10,000.00';
      notifyListeners();
      return;
    }
    if (activeTradesFor(asset).length >= AppConstants.maxActiveSignalsPerAsset) {
      error = 'Maximum 10 active trades for this asset';
      notifyListeners();
      return;
    }
    submitting = true;
    error = null;
    notifyListeners();
    try {
      final opened = await _service.openTrade(
        userId: id,
        asset: asset,
        direction: direction,
        stake: stake,
        expirySeconds: expirySeconds,
      );
      _upsert(opened);
      lastResult = null;
      error = null;
      await refresh(asset: asset);
    } catch (exc) {
      error = exc.toString().replaceFirst('Exception: ', '');
    } finally {
      submitting = false;
      notifyListeners();
    }
  }

  void applyEvent(Map<String, dynamic> event) {
    final type = event['type'];
    if ((type == 'signal_created' || type == 'signal_closed') && event['signal'] is Map) {
      final parsed = TradeSignal.fromJson(
        Map<String, dynamic>.from(event['signal'] as Map),
      );
      if (parsed.isDirectional) {
        _upsertSignal(parsed);
        final open = activeSignalsFor(parsed.asset);
        if (open.isNotEmpty) {
          open.sort((a, b) => (b.generatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(a.generatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
          signal = open.first;
        } else {
          signal = parsed;
        }
        notifyListeners();
      }
    }
    if (type == 'trade_opened' || type == 'trade_result' || type == 'trade_expired') {
      final trade = event['trade'];
      if (trade is Map) {
        final parsed = DemoTrade.fromJson(Map<String, dynamic>.from(trade));
        _upsert(parsed);
        if (!parsed.isOpen) {
          lastResult = parsed;
          unawaited(refresh());
        }
      }
      notifyListeners();
    }
    if (type == 'balance_updated' && event['balance'] is num) {
      if (event['user_id'] == null || event['user_id'] == userId) {
        balance = (event['balance'] as num).toDouble();
        notifyListeners();
      }
    }
  }

  void _upsert(DemoTrade trade) {
    history = [
      trade,
      ...history.where((item) => item.tradeId != trade.tradeId),
    ];
  }

  void _upsertSignal(TradeSignal next) {
    signals = [
      next,
      ...signals.where((item) => item.signalId != next.signalId),
    ];
  }

  void _mergeSignals(List<TradeSignal> incoming) {
    final byId = {for (final item in signals) item.signalId: item};
    for (final item in incoming) {
      if (item.signalId.isEmpty) continue;
      byId[item.signalId] = item;
    }
    signals = byId.values.toList();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }
}
