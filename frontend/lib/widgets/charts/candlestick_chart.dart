import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

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
  });

  final List<MarketCandle> candles;
  final List<ChartEntryMarker> entries;
  final List<ChartSignalSpan> spans;
  final String? highlightId;
  final double? height;
  final bool immersive;
  final EdgeInsets overlayInsets;

  @override
  State<CandlestickChart> createState() => _CandlestickChartState();
}

class _CandlestickChartState extends State<CandlestickChart> {
  double _zoom = 1;
  double _pan = 0;

  void _zoomBy(double factor) {
    setState(() {
      _zoom = (_zoom * factor).clamp(1.0, 8.0);
      _pan = _pan.clamp(0, _maxPan);
    });
  }

  void _reset() {
    setState(() {
      _zoom = 1;
      _pan = 0;
    });
  }

  int get _visibleCount {
    if (widget.candles.isEmpty) return 0;
    final count = (widget.candles.length / _zoom).round();
    return count.clamp(1, widget.candles.length);
  }

  double get _maxPan {
    final extra = widget.candles.length - _visibleCount;
    return extra < 0 ? 0 : extra.toDouble();
  }

  List<MarketCandle> get _visible {
    if (widget.candles.isEmpty) return const [];
    final start = (_maxPan - _pan).round().clamp(0, widget.candles.length);
    final end = (start + _visibleCount).clamp(0, widget.candles.length);
    return widget.candles.sublist(start, end);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.immersive ? 0 : 14),
      child: ColoredBox(
        color: colors.chart,
        child: Column(
          children: [
            if (!widget.immersive)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '1M CANDLES',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      _ChartTool(
                        icon: Icons.zoom_in,
                        tooltip: 'Zoom in',
                        onTap: () => _zoomBy(1.2),
                      ),
                      _ChartTool(
                        icon: Icons.zoom_out,
                        tooltip: 'Zoom out',
                        onTap: () => _zoomBy(1 / 1.2),
                      ),
                      _ChartTool(
                        icon: Icons.fit_screen,
                        tooltip: 'Reset zoom',
                        onTap: _reset,
                      ),
                    ],
                  ),
                  if (widget.entries.isNotEmpty || widget.spans.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final entry in widget.entries)
                            Text(
                              '${entry.direction} ${AppUtils.formatPrice(entry.entryPrice)}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: entry.direction == 'BUY'
                                    ? colors.success
                                    : colors.danger,
                              ),
                            ),
                          for (final span in widget.spans)
                            Text(
                              '${span.direction} HOLD',
                              style: TextStyle(
                                fontSize: 10,
                                color: span.direction == 'BUY'
                                    ? colors.success
                                    : colors.danger,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (widget.height == null)
              Expanded(child: _immersiveBody(colors))
            else
              SizedBox(
                height: widget.height,
                width: double.infinity,
                child: _immersiveBody(colors),
              ),
          ],
        ),
      ),
    );
  }

  Widget _immersiveBody(TradePulseColors colors) {
    final body = _chartBody(colors);
    if (!widget.immersive) return body;
    return Stack(
      children: [
        Positioned.fill(child: body),
        Positioned(
          left: widget.overlayInsets.left + 8,
          bottom: widget.overlayInsets.bottom + 8,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.card.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.cardBorder.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ChartTool(
                  icon: Icons.zoom_in,
                  tooltip: 'Zoom in',
                  onTap: () => _zoomBy(1.2),
                ),
                _ChartTool(
                  icon: Icons.zoom_out,
                  tooltip: 'Zoom out',
                  onTap: () => _zoomBy(1 / 1.2),
                ),
                _ChartTool(
                  icon: Icons.fit_screen,
                  tooltip: 'Reset zoom',
                  onTap: _reset,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _chartBody(TradePulseColors colors) {
    if (widget.candles.isEmpty) {
      return Center(
        child: Text(
          'Waiting for simulated candles…',
          style: TextStyle(color: colors.mutedText),
        ),
      );
    }
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          _zoomBy(event.scrollDelta.dy > 0 ? 1.12 : 1 / 1.12);
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        onScaleUpdate: (details) {
          if (details.pointerCount >= 2 && details.scale != 1.0) {
            _zoomBy(details.scale > 1 ? 1.04 : 0.96);
          } else {
            setState(() {
              _pan = (_pan - details.focalPointDelta.dx / 8).clamp(0, _maxPan);
            });
          }
        },
        child: Stack(
          children: [
            CustomPaint(
              painter: _CandlePainter(
                candles: _visible,
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
              ),
              child: const SizedBox.expand(),
            ),
            if (!widget.immersive)
            const IgnorePointer(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(14, 0, 0, 28),
                  child: Text(
                    'DEMO  ·  SIMULATED OTC',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.6,
                      color: Color(0x55FFFFFF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartTool extends StatelessWidget {
  const _ChartTool({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, size: 18),
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

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;
    const right = 58.0;
    const bottom = 22.0;
    const left = 8.0;
    const top = 8.0;
    final plot = Rect.fromLTRB(left, top, size.width - right, size.height - bottom);

    var maxP = candles.first.high;
    var minP = candles.first.low;
    for (final candle in candles) {
      if (candle.high > maxP) maxP = candle.high;
      if (candle.low < minP) minP = candle.low;
    }
    for (final entry in entries) {
      if (candleForEntry(candles, entry.entryTime) == null) continue;
      if (entry.entryPrice > maxP) maxP = entry.entryPrice;
      if (entry.entryPrice < minP) minP = entry.entryPrice;
    }
    for (final item in spans) {
      if (item.entryPrice > maxP) maxP = item.entryPrice;
      if (item.entryPrice < minP) minP = item.entryPrice;
      final close = item.closePrice;
      if (close != null) {
        if (close > maxP) maxP = close;
        if (close < minP) minP = close;
      }
    }
    final span = (maxP - minP).abs() < 0.0000001 ? 1.0 : maxP - minP;
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
    for (var i = 0; i < candles.length; i++) {
      final candle = candles[i];
      final color = candle.close >= candle.open ? up : down;
      final x = plot.left + i * candleWidth + candleWidth / 2;
      final wick = Paint()
        ..color = color
        ..strokeWidth = 1.2;
      canvas.drawLine(Offset(x, yFor(candle.high)), Offset(x, yFor(candle.low)), wick);
      final bodyTop = yFor(candle.open > candle.close ? candle.open : candle.close);
      final bodyBottom = yFor(candle.open < candle.close ? candle.open : candle.close);
      final half = candleWidth * 0.28;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            x - half,
            bodyTop,
            x + half,
            bodyBottom + 1,
          ),
          const Radius.circular(1),
        ),
        Paint()..color = color,
      );
    }

    double? xAt(DateTime time) {
      final stamp = time.toUtc();
      if (stamp.isBefore(candles.first.openTime.toUtc())) return plot.left;
      if (!stamp.isBefore(candles.last.closeTime.toUtc())) {
        return plot.left + (candles.length - 0.5) * candleWidth;
      }
      for (var i = 0; i < candles.length; i++) {
        final candle = candles[i];
        final open = candle.openTime.toUtc();
        final close = candle.closeTime.toUtc();
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
      return null;
    }

    for (var index = 0; index < spans.length; index++) {
      final item = spans[index];
      final start = xAt(item.entryTime);
      final endTime = item.isClosed
          ? (item.closeTime ?? item.entryTime)
          : now;
      final end = xAt(endTime);
      if (start == null || end == null) continue;
      final buy = item.direction == 'BUY';
      final color = (buy ? up : down).withValues(alpha: 0.85);
      final yStart = yFor(item.entryPrice) + ((index % 5) - 2) * 1.5;
      final yEnd = yFor(item.closePrice ?? item.entryPrice) + ((index % 5) - 2) * 1.5;
      final line = Paint()
        ..color = color
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(start, yStart), Offset(end, yEnd), line);
      canvas.drawLine(Offset(start, yStart - 4), Offset(start, yStart + 4), line);
      _brokerFlag(canvas, Offset(start + 6, yStart), item.direction, color, buy);
    }

    for (final entry in entries) {
      final index = candles.indexWhere(
        (candle) => candleContainsEntry(candle, entry.entryTime),
      );
      if (index < 0) continue;
      final x = plot.left + index * candleWidth + candleWidth / 2;
      final y = yFor(entry.entryPrice);
      final buy = entry.direction == 'BUY';
      final color = buy ? up : down;
      final hot = highlightId == entry.tradeId;
      final dash = Paint()
        ..color = color.withValues(alpha: hot ? 0.7 : 0.4)
        ..strokeWidth = hot ? 1.4 : 1;
      var dashX = x;
      while (dashX < plot.right) {
        canvas.drawLine(Offset(dashX, y), Offset(dashX + 4, y), dash);
        dashX += 8;
      }
      final tick = Paint()
        ..color = color
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.square;
      canvas.drawLine(Offset(x - 8, y), Offset(x + 8, y), tick);
      _brokerFlag(canvas, Offset(x + 10, y), entry.direction, color, buy);
    }

    final lastY = yFor(last);
    final dash = Paint()
      ..color = priceLine.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    var x = plot.left;
    while (x < plot.right) {
      canvas.drawLine(Offset(x, lastY), Offset(x + 4, lastY), dash);
      x += 8;
    }
    _label(
      canvas,
      AppUtils.formatPrice(last),
      Offset(plot.right + 6, lastY - 6),
      TextStyle(color: priceLine, fontSize: 10, fontWeight: FontWeight.w700),
    );

    final step = (candles.length / 4).ceil().clamp(1, candles.length);
    for (var i = 0; i < candles.length; i += step) {
      final candle = candles[i];
      final xPos = plot.left + i * candleWidth;
      final stamp =
          '${candle.openTime.hour.toString().padLeft(2, '0')}:${candle.openTime.minute.toString().padLeft(2, '0')}';
      _label(canvas, stamp, Offset(xPos, plot.bottom + 4), labelStyle);
    }
  }

  void _brokerFlag(
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
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = painter.width + 10;
    final h = 14.0;
    final top = buy ? point.dy - h - 6 : point.dy + 6;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(point.dx, top, w, h),
      const Radius.circular(3),
    );
    canvas.drawRRect(rect, Paint()..color = color);
    painter.paint(canvas, Offset(point.dx + 5, top + 2));
    final notch = Path()
      ..moveTo(point.dx + 6, buy ? top + h : top)
      ..lineTo(point.dx + 11, point.dy)
      ..lineTo(point.dx + 16, buy ? top + h : top)
      ..close();
    canvas.drawPath(notch, Paint()..color = color);
  }

  void _label(Canvas canvas, String value, Offset offset, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _CandlePainter oldDelegate) => true;
}
