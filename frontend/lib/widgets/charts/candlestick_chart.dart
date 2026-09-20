import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/app_utils.dart';
import '../../models/chart_entry.dart';
import '../../models/market_models.dart';

class CandlestickChart extends StatefulWidget {
  const CandlestickChart({
    super.key,
    required this.candles,
    this.entries = const [],
    this.spans = const [],
    this.highlightId,
    this.height,
    this.immersive = false,
    this.overlayInsets = EdgeInsets.zero,
    this.livePrice,
  });

  final List<MarketCandle> candles;
  final List<ChartEntryMarker> entries;
  final List<ChartSignalSpan> spans;
  final String? highlightId;
  final double? height;
  final bool immersive;
  final EdgeInsets overlayInsets;
  final double? livePrice;

  @override
  State<CandlestickChart> createState() => _CandlestickChartState();
}

class _CandlestickChartState extends State<CandlestickChart>
    with SingleTickerProviderStateMixin {
  static const _minZoom = 0.55;
  static const _maxZoom = 6.0;

  double _zoom = 1;
  double _gestureZoom = 1;
  double _rightOffset = 0;
  var _following = true;
  late final Ticker _ticker;
  double _shownClose = 0;
  double _shownHigh = 0;
  double _shownLow = 0;
  DateTime? _liveOpen;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _snapLive();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void didUpdateWidget(covariant CandlestickChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final last = widget.candles.isEmpty ? null : widget.candles.last;
    if (last == null) return;
    if (_liveOpen != last.openTime) {
      _snapLive();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _snapLive() {
    if (widget.candles.isEmpty) return;
    final last = widget.candles.last;
    _liveOpen = last.openTime;
    _shownClose = last.close;
    _shownHigh = last.high;
    _shownLow = last.low;
  }

  void _tick(Duration elapsed) {
    if (!mounted || widget.candles.isEmpty) return;
    final last = widget.candles.last;
    if (_liveOpen != last.openTime) {
      _snapLive();
    }
    final dt = elapsed <= _lastElapsed
        ? 1 / 60
        : (elapsed - _lastElapsed).inMicroseconds / 1000000;
    _lastElapsed = elapsed;
    final targetClose = widget.livePrice ?? last.close;
    if (last.closed) {
      if (_shownClose != last.close ||
          _shownHigh != last.high ||
          _shownLow != last.low) {
        setState(() {
          _shownClose = last.close;
          _shownHigh = last.high;
          _shownLow = last.low;
        });
      }
      return;
    }
    final alpha = (1 - math.exp(-dt / 0.055)).clamp(0.0, 1.0);
    final nextClose = _shownClose + (targetClose - _shownClose) * alpha;
    final nextHigh = math.max(math.max(last.high, last.open), nextClose);
    final nextLow = math.min(math.min(last.low, last.open), nextClose);
    if ((nextClose - _shownClose).abs() < 0.0000001 &&
        (nextHigh - _shownHigh).abs() < 0.0000001 &&
        (nextLow - _shownLow).abs() < 0.0000001) {
      return;
    }
    setState(() {
      _shownClose = nextClose;
      _shownHigh = nextHigh;
      _shownLow = nextLow;
    });
  }

  void _zoomBy(double factor) {
    setState(() {
      _zoom = (_zoom * factor).clamp(_minZoom, _maxZoom);
      if (_following) _rightOffset = 0;
      _rightOffset = _rightOffset.clamp(0, _maxOffset);
    });
  }

  void _reset() {
    setState(() {
      _zoom = 1;
      _rightOffset = 0;
      _following = true;
    });
  }

  int _visibleCountFor(double width) {
    if (widget.candles.isEmpty) return 0;
    final slot = (18.0 * _zoom).clamp(8.0, 44.0);
    final count = (width / slot).floor();
    return count.clamp(8, math.max(8, widget.candles.length));
  }

  double get _maxOffset {
    final extra = widget.candles.length - 8;
    return extra < 0 ? 0 : extra.toDouble();
  }

  List<MarketCandle> _visible(double width) {
    if (widget.candles.isEmpty) return const [];
    final count = math.min(_visibleCountFor(width), widget.candles.length);
    final offset = _following ? 0.0 : _rightOffset;
    final end = widget.candles.length - offset.round();
    final safeEnd = end.clamp(count, widget.candles.length);
    final start = (safeEnd - count).clamp(0, widget.candles.length);
    final slice = widget.candles.sublist(start, safeEnd);
    if (slice.isEmpty) return slice;
    final last = slice.last;
    if (last.closed || last != widget.candles.last) return slice;
    return [
      ...slice.sublist(0, slice.length - 1),
      last.copyWith(close: _shownClose, high: _shownHigh, low: _shownLow),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.immersive ? 0 : 14),
      child: ColoredBox(
        color: colors.chart,
        child: widget.height == null
            ? _chartBody(colors)
            : SizedBox(
                height: widget.height,
                width: double.infinity,
                child: _chartBody(colors),
              ),
      ),
    );
  }

  Widget _chartBody(TradePulseColors colors) {
    if (widget.candles.isEmpty) {
      return Center(
        child: Text(
          'Waiting for candles…',
          style: TextStyle(color: colors.mutedText),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              _zoomBy(event.scrollDelta.dy > 0 ? 1 / 1.12 : 1.12);
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: _reset,
            onScaleStart: (_) => _gestureZoom = _zoom,
            onScaleUpdate: (details) {
              if (details.pointerCount >= 2) {
                setState(() {
                  _zoom = (_gestureZoom * details.scale).clamp(_minZoom, _maxZoom);
                });
                return;
              }
              final slot = (18.0 * _zoom).clamp(8.0, 44.0);
              final delta = -details.focalPointDelta.dx / slot;
              if (delta.abs() < 0.02) return;
              setState(() {
                _rightOffset = (_rightOffset + delta).clamp(0, _maxOffset);
                _following = _rightOffset < 0.35;
                if (_following) _rightOffset = 0;
              });
            },
            child: CustomPaint(
              painter: _CandlePainter(
                candles: _visible(width),
                entries: {
                  for (final entry in widget.entries) entry.tradeId: entry,
                }.values.toList(),
                spans: {
                  for (final span in widget.spans) span.signalId: span,
                }.values.toList(),
                highlightId: widget.highlightId,
                now: DateTime.now().toUtc(),
                grid: colors.chartGrid,
                up: colors.success,
                down: colors.danger,
                text: colors.mutedText,
                priceLine: colors.accent,
                insets: widget.overlayInsets,
                following: _following,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        );
      },
    );
  }
}

class _CandlePainter extends CustomPainter {
  _CandlePainter({
    required this.candles,
    required this.entries,
    required this.spans,
    required this.highlightId,
    required this.now,
    required this.grid,
    required this.up,
    required this.down,
    required this.text,
    required this.priceLine,
    required this.insets,
    required this.following,
  });

  final List<MarketCandle> candles;
  final List<ChartEntryMarker> entries;
  final List<ChartSignalSpan> spans;
  final String? highlightId;
  final DateTime now;
  final Color grid;
  final Color up;
  final Color down;
  final Color text;
  final Color priceLine;
  final EdgeInsets insets;
  final bool following;

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;
    const right = 58.0;
    const bottom = 22.0;
    const left = 10.0;
    final top = 8.0 + insets.top;
    final plot = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom - insets.bottom,
    );
    if (plot.height < 40 || plot.width < 40) return;

    var maxP = candles.first.high;
    var minP = candles.first.low;
    for (final candle in candles) {
      if (candle.high > maxP) maxP = candle.high;
      if (candle.low < minP) minP = candle.low;
    }
    final live = candles.last.close;
    if (live > maxP) maxP = live;
    if (live < minP) minP = live;
    for (final entry in entries) {
      if (entry.entryPrice <= 0) continue;
      if (entry.entryPrice > maxP) maxP = entry.entryPrice;
      if (entry.entryPrice < minP) minP = entry.entryPrice;
    }
    final rawSpan = (maxP - minP).abs();
    final minSpan = math.max(live.abs() * 0.0012, 0.00001);
    final pad = rawSpan < minSpan
        ? (minSpan - rawSpan) / 2 + minSpan * 0.18
        : rawSpan * 0.10;
    maxP += pad;
    minP -= pad;
    if (following) {
      var spanNow = maxP - minP;
      if (spanNow > 0) {
        final pos = (live - minP) / spanNow;
        const lo = 0.34;
        const hi = 0.66;
        if (pos < lo) {
          minP = (live - lo * maxP) / (1 - lo);
        } else if (pos > hi) {
          maxP = (live - minP * (1 - hi)) / hi;
        }
      }
    }
    final span = (maxP - minP).abs().clamp(minSpan, double.infinity);
    if (maxP <= minP) {
      maxP = live + span / 2;
      minP = live - span / 2;
    }
    final last = candles.last.close;

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    final labelStyle = TextStyle(color: text, fontSize: 10);
    for (var i = 0; i <= 4; i++) {
      final y = plot.top + plot.height * i / 4;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      final price = maxP - span * i / 4;
      _label(canvas, AppUtils.formatPrice(price), Offset(plot.right + 6, y - 6), labelStyle);
    }

    double yFor(double price) {
      return plot.bottom - ((price - minP) / span) * plot.height;
    }

    final candleWidth = plot.width / candles.length;
    final bodyHalf = (candleWidth * 0.28).clamp(2.4, 11.0);
    final wickWidth = (candleWidth * 0.07).clamp(1.0, 2.0);

    canvas.save();
    canvas.clipRect(plot);
    for (var i = 0; i < candles.length; i++) {
      final candle = candles[i];
      final color = candle.close >= candle.open ? up : down;
      final x = plot.left + i * candleWidth + candleWidth / 2;
      final yHigh = yFor(candle.high);
      final yLow = yFor(candle.low);
      final yOpen = yFor(candle.open);
      final yClose = yFor(candle.close);
      final bodyTop = math.min(yOpen, yClose);
      final bodyBottom = math.max(yOpen, yClose);
      final minBody = math.max(1.6, bodyHalf * 0.45);
      final height = math.max(minBody, bodyBottom - bodyTop);
      final bodyCenterY = (yOpen + yClose) / 2;
      final wickSpan = (yLow - yHigh).abs();
      if (wickSpan > 0.4) {
        final wick = Paint()
          ..color = color
          ..strokeWidth = wickWidth
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(x, yHigh), Offset(x, yLow), wick);
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, bodyCenterY),
            width: bodyHalf * 2,
            height: height,
          ),
          const Radius.circular(1.5),
        ),
        Paint()..color = color,
      );
    }
    canvas.restore();

    double? xAt(DateTime time) {
      final stamp = time.toUtc();
      if (stamp.isBefore(candles.first.openTime.toUtc())) return plot.left;
      if (!stamp.isBefore(candles.last.closeTime.toUtc()) && candles.last.closed) {
        return plot.left + (candles.length - 0.5) * candleWidth;
      }
      for (var i = 0; i < candles.length; i++) {
        final candle = candles[i];
        final open = candle.openTime.toUtc();
        final close = candle.closed
            ? candle.closeTime.toUtc()
            : candle.closeTime.toUtc().isAfter(open.add(const Duration(minutes: 1)))
                ? candle.closeTime.toUtc()
                : open.add(const Duration(minutes: 1));
        if (stamp.isBefore(open)) {
          return plot.left + i * candleWidth;
        }
        if (!stamp.isBefore(open) && stamp.isBefore(close)) {
          final spanMs = close.difference(open).inMilliseconds;
          final frac = spanMs <= 0
              ? 0.5
              : stamp.difference(open).inMilliseconds / spanMs;
          return plot.left + i * candleWidth + frac.clamp(0, 1) * candleWidth;
        }
      }
      return plot.left + (candles.length - 0.5) * candleWidth;
    }

    for (var index = 0; index < spans.length; index++) {
      final item = spans[index];
      final start = xAt(item.entryTime);
      if (start == null) continue;
      final buy = item.direction == 'BUY';
      final color = (buy ? up : down).withValues(alpha: 0.7);
      final y = yFor(item.entryPrice);
      final mark = Paint()
        ..color = color
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(start - 5, y), Offset(start + 5, y), mark);
      _tinyFlag(canvas, Offset(start + 6, y), item.direction, color, buy);
    }

    for (final entry in entries) {
      final x = xAt(entry.entryTime);
      if (x == null) continue;
      final y = yFor(entry.entryPrice);
      final buy = entry.direction == 'BUY';
      final color = buy ? up : down;
      final hot = highlightId == entry.tradeId;
      final dash = Paint()
        ..color = color.withValues(alpha: hot ? 0.75 : 0.45)
        ..strokeWidth = hot ? 1.3 : 1.0;
      var dashX = x;
      while (dashX < plot.right) {
        canvas.drawLine(Offset(dashX, y), Offset(dashX + 5, y), dash);
        dashX += 9;
      }
      _tinyFlag(
        canvas,
        Offset(x + 4, y),
        buy ? 'B' : 'S',
        color,
        buy,
      );
    }

    final lastY = yFor(last).clamp(plot.top + 8, plot.bottom - 8);
    final dash = Paint()
      ..color = priceLine.withValues(alpha: 0.75)
      ..strokeWidth = 1;
    var x = plot.left;
    while (x < plot.right) {
      canvas.drawLine(Offset(x, lastY), Offset(x + 4, lastY), dash);
      x += 8;
    }
    _priceTag(canvas, Offset(plot.right + 4, lastY), AppUtils.formatPrice(last), priceLine);

    final step = (candles.length / 4).ceil().clamp(1, candles.length);
    for (var i = 0; i < candles.length; i += step) {
      final candle = candles[i];
      final xPos = plot.left + i * candleWidth;
      final stamp =
          '${candle.openTime.hour.toString().padLeft(2, '0')}:${candle.openTime.minute.toString().padLeft(2, '0')}';
      _label(canvas, stamp, Offset(xPos, plot.bottom + 4), labelStyle);
    }
  }

  void _tinyFlag(
    Canvas canvas,
    Offset point,
    String direction,
    Color color,
    bool buy,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: direction,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = painter.width + 8;
    const h = 12.0;
    final top = buy ? point.dy - h - 4 : point.dy + 4;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(point.dx, top, w, h),
      const Radius.circular(3),
    );
    canvas.drawRRect(rect, Paint()..color = color.withValues(alpha: 0.92));
    painter.paint(canvas, Offset(point.dx + 4, top + 1));
  }

  void _priceTag(Canvas canvas, Offset offset, String value, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(offset.dx, offset.dy - 8, painter.width + 8, 16),
      const Radius.circular(3),
    );
    canvas.drawRRect(rect, Paint()..color = color);
    painter.paint(canvas, Offset(offset.dx + 4, offset.dy - 7));
  }

  void _label(Canvas canvas, String value, Offset offset, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _CandlePainter oldDelegate) {
    return oldDelegate.candles.length != candles.length ||
        oldDelegate.following != following ||
        oldDelegate.highlightId != highlightId ||
        oldDelegate.entries.length != entries.length ||
        (candles.isNotEmpty &&
            oldDelegate.candles.isNotEmpty &&
            (oldDelegate.candles.last.close != candles.last.close ||
                oldDelegate.candles.last.high != candles.last.high ||
                oldDelegate.candles.last.low != candles.last.low));
  }
}
