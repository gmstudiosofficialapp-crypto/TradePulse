import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../models/market_models.dart';
import '../chart/candle_timeframe.dart';
import 'market_data_service.dart';

class MarketController extends ChangeNotifier {
  MarketController(this._service);

  final MarketDataService _service;
  final Map<String, MarketQuote> quotes = {};
  final Map<String, List<double>> priceTrail = {};
  List<MarketCandle> _minutes = [];
  List<MarketCandle> candles = [];
  int chartTimeframe = 60;
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

  void setChartTimeframe(int seconds) {
    if (!CandleTimeframe.options.contains(seconds) || chartTimeframe == seconds) {
      return;
    }
    chartTimeframe = seconds;
    _rebuildDisplay();
    notifyListeners();
  }

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
    _minutes = await _service.getHistoricalCandles(asset);
    _rebuildDisplay();
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
    _upsertMinute(candle);
    _rebuildDisplay();
    notifyListeners();
  }

  void _upsertMinute(MarketCandle candle) {
    final key = candle.minuteKey;
    final index = _minutes.indexWhere((item) => item.minuteKey == key);
    if (index >= 0) {
      final current = _minutes[index];
      if (current.closed && !candle.closed) return;
      final next = [..._minutes];
      next[index] = candle;
      _minutes = next;
    } else {
      _minutes = [..._minutes, candle]
        ..sort((a, b) => a.openTime.compareTo(b.openTime));
    }
    if (_minutes.length > 360) {
      _minutes = _minutes.sublist(_minutes.length - 360);
    }
  }

  void _rebuildDisplay({MarketCandle? liveOverride}) {
    final closed = _minutes.where((item) => item.closed).toList();
    final expanded = CandleTimeframe.fromMinutes(
      closed,
      seconds: chartTimeframe,
    );
    final liveMinute = _minutes.isEmpty ? null : _minutes.last;
    if (liveMinute != null && !liveMinute.closed) {
      final stamp = liveMinute.closeTime.toUtc();
      final start = CandleTimeframe.bucketStart(stamp, chartTimeframe);
      expanded.add(
        liveOverride ??
            MarketCandle(
              asset: liveMinute.asset,
              open: liveMinute.close,
              high: liveMinute.close,
              low: liveMinute.close,
              close: liveMinute.close,
              volume: 1,
              openTime: start,
              closeTime: start.add(Duration(seconds: chartTimeframe)),
              closed: false,
            ),
      );
    }
    candles = expanded;
  }

  void _applyLivePrice(String asset, double price, DateTime? timestamp) {
    if (asset != focusedAsset) return;
    final stamp = timestamp ?? DateTime.now().toUtc();
    final minuteBucket = DateTime.utc(
      stamp.year,
      stamp.month,
      stamp.day,
      stamp.hour,
      stamp.minute,
    );
    if (_minutes.isEmpty) {
      _upsertMinute(
        MarketCandle(
          asset: asset,
          open: price,
          high: price,
          low: price,
          close: price,
          volume: 1,
          openTime: minuteBucket,
          closeTime: stamp,
          closed: false,
        ),
      );
    } else {
      final last = _minutes.last;
      if (last.closed) {
        if (minuteBucket.millisecondsSinceEpoch ~/ 60000 != last.minuteKey) {
          _upsertMinute(
            MarketCandle(
              asset: asset,
              open: price,
              high: price,
              low: price,
              close: price,
              volume: 1,
              openTime: minuteBucket,
              closeTime: stamp,
              closed: false,
            ),
          );
        }
      } else if (minuteBucket.millisecondsSinceEpoch ~/ 60000 != last.minuteKey) {
        _upsertMinute(
          last.copyWith(closed: true, closeTime: minuteBucket),
        );
        _upsertMinute(
          MarketCandle(
            asset: asset,
            open: price,
            high: price,
            low: price,
            close: price,
            volume: 1,
            openTime: minuteBucket,
            closeTime: stamp,
            closed: false,
          ),
        );
      } else {
        _minutes = [
          ..._minutes.sublist(0, _minutes.length - 1),
          last.copyWith(
            close: price,
            high: math.max(last.high, price),
            low: math.min(last.low, price),
            closeTime: stamp,
          ),
        ];
      }
    }

    final start = CandleTimeframe.bucketStart(stamp, chartTimeframe);
    MarketCandle? liveBar;
    if (candles.isNotEmpty) {
      final lastBar = candles.last;
      if (!lastBar.closed && lastBar.openTime.toUtc() == start) {
        liveBar = lastBar.copyWith(
          close: price,
          high: math.max(lastBar.high, price),
          low: math.min(lastBar.low, price),
          closeTime: stamp,
        );
      }
    }
    liveBar ??= MarketCandle(
      asset: asset,
      open: price,
      high: price,
      low: price,
      close: price,
      volume: 1,
      openTime: start,
      closeTime: stamp,
      closed: false,
    );
    _rebuildDisplay(liveOverride: liveBar);
    if (candles.isNotEmpty && candles.last.openTime.toUtc() == start) {
      candles = [...candles.sublist(0, candles.length - 1), liveBar];
    } else {
      candles = [...candles, liveBar];
      if (candles.length > 240) {
        candles = candles.sublist(candles.length - 240);
      }
    }
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
