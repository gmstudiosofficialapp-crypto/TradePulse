import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/market_models.dart';
import 'market_data_service.dart';

class MarketController extends ChangeNotifier {
  MarketController(this._service);

  final MarketDataService _service;
  final Map<String, MarketQuote> quotes = {};
  final Map<String, List<double>> priceTrail = {};
  List<MarketCandle> candles = [];
  MarketStatus status = const MarketStatus(
    state: EngineState.offline,
    simulated: true,
  );
  String focusedAsset = 'BTC/USD-OTC';
  StreamSubscription<MarketCandle>? _candleSub;
  StreamSubscription<EngineState>? _connSub;
  Timer? _poll;

  Stream<Map<String, dynamic>> get events => _service.eventStream;

  Future<void> start() async {
    await _service.connect();
    _candleSub = _service.candleStream.listen(_onCandle);
    _connSub = _service.connectionState.listen((state) {
      status = MarketStatus(state: state, simulated: true);
      notifyListeners();
    });
    await refresh();
    await focusAsset(focusedAsset);
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => refresh());
  }

  Future<void> identify(String userId) => _service.identify(userId);

  Future<void> refresh() async {
    try {
      status = await _service.getStatus();
      final latest = await _service.getQuotes();
      for (final quote in latest) {
        quotes[quote.asset] = quote;
        final trail = priceTrail.putIfAbsent(quote.asset, () => []);
        if (trail.isEmpty || trail.last != quote.price) {
          trail.add(quote.price);
          if (trail.length > 24) {
            trail.removeRange(0, trail.length - 24);
          }
        }
      }
      notifyListeners();
    } catch (_) {
      status = const MarketStatus(
        state: EngineState.offline,
        simulated: true,
        message: 'Market engine unreachable',
      );
      notifyListeners();
    }
  }

  Future<void> focusAsset(String asset) async {
    if (focusedAsset != asset) {
      await _service.unsubscribeAsset(focusedAsset);
    }
    focusedAsset = asset;
    candles = await _service.getHistoricalCandles(asset);
    await _service.subscribeAsset(asset);
    notifyListeners();
  }

  void _onCandle(MarketCandle candle) {
    if (candle.asset != focusedAsset) return;
    final index = candles.indexWhere(
      (item) => item.openTime == candle.openTime,
    );
    if (index >= 0) {
      candles[index] = candle;
    } else {
      candles = [...candles, candle];
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _poll?.cancel();
    unawaited(_candleSub?.cancel());
    unawaited(_connSub?.cancel());
    unawaited(_service.disconnect());
    super.dispose();
  }
}
