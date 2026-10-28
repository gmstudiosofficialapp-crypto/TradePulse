import 'dart:async';
import 'dart:math' as math;

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
  StreamSubscription<Map<String, dynamic>>? _eventSub;
  Timer? _poll;

  Stream<Map<String, dynamic>> get events => _service.eventStream;

  Future<void> start() async {
    await _service.connect();
    _candleSub = _service.candleStream.listen(_onCandle);
    _eventSub = _service.eventStream.listen(_onEvent);
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
        final existing = quotes[quote.asset];
        if (existing != null && !quote.timestamp.isAfter(existing.timestamp)) {
          continue;
        }
        quotes[quote.asset] = quote;
        final trail = priceTrail.putIfAbsent(quote.asset, () => []);
        if (trail.isEmpty || trail.last != quote.price) {
          trail.add(quote.price);
          if (trail.length > 24) {
            trail.removeRange(0, trail.length - 24);
          }
        }
        if (quote.asset == focusedAsset) {
          _applyLivePrice(quote.asset, quote.price, quote.timestamp);
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
    final quote = quotes[asset];
    if (quote != null) {
      _applyLivePrice(asset, quote.price, quote.timestamp);
    }
    notifyListeners();
  }

  void _onEvent(Map<String, dynamic> event) {
    final type = event['type'];
    if (type != 'market_tick' && type != 'tick') return;
    final data = event['data'];
    if (data is! Map) return;
    final asset = data['asset'] as String? ?? event['asset'] as String?;
    final price = (data['price'] as num?)?.toDouble();
    if (asset == null || price == null || asset != focusedAsset) return;
    final stamp = DateTime.tryParse('${data['timestamp'] ?? ''}')?.toUtc();
    _applyLivePrice(asset, price, stamp);
    notifyListeners();
  }

  void _onCandle(MarketCandle candle) {
    if (candle.asset != focusedAsset) return;
    _upsertCandle(candle);
    notifyListeners();
  }

  void _upsertCandle(MarketCandle candle) {
    final key = candle.minuteKey;
    final index = candles.indexWhere((item) => item.minuteKey == key);
    if (index >= 0) {
      final current = candles[index];
      if (current.closed && !candle.closed) return;
      final next = [...candles];
      next[index] = candle;
      candles = next;
    } else {
      candles = [...candles, candle]..sort((a, b) => a.openTime.compareTo(b.openTime));
    }
    if (candles.length > 360) {
      candles = candles.sublist(candles.length - 360);
    }
  }

  void _applyLivePrice(String asset, double price, DateTime? timestamp) {
    if (asset != focusedAsset || candles.isEmpty) return;
    final last = candles.last;
    if (!last.closed &&
        timestamp != null &&
        timestamp.isBefore(last.closeTime.toUtc())) {
      return;
    }
    final stamp = timestamp ?? DateTime.now().toUtc();
    final bucket = DateTime.utc(
      stamp.year,
      stamp.month,
      stamp.day,
      stamp.hour,
      stamp.minute,
    );
    if (last.closed) {
      if (bucket.millisecondsSinceEpoch ~/ 60000 == last.minuteKey) return;
      _upsertCandle(
        MarketCandle(
          asset: asset,
          open: price,
          high: price,
          low: price,
          close: price,
          volume: 1,
          openTime: bucket,
          closeTime: stamp,
          closed: false,
        ),
      );
      return;
    }
    if (bucket.millisecondsSinceEpoch ~/ 60000 != last.minuteKey) {
      _upsertCandle(
        MarketCandle(
          asset: asset,
          open: price,
          high: price,
          low: price,
          close: price,
          volume: 1,
          openTime: bucket,
          closeTime: stamp,
          closed: false,
        ),
      );
      return;
    }
    candles = [
      ...candles.sublist(0, candles.length - 1),
      last.copyWith(
        close: price,
        high: math.max(last.high, price),
        low: math.min(last.low, price),
        closeTime: stamp,
      ),
    ];
  }

  @override
  void dispose() {
    _poll?.cancel();
    unawaited(_candleSub?.cancel());
    unawaited(_connSub?.cancel());
    unawaited(_eventSub?.cancel());
    unawaited(_service.disconnect());
    super.dispose();
  }
}
