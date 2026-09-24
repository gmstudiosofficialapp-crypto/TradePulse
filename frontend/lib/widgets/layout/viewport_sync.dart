import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'viewport_metrics_stub.dart'
    if (dart.library.html) 'viewport_metrics_web.dart' as metrics;

class ViewportFrame {
  const ViewportFrame({
    required this.height,
    required this.inset,
    required this.rememberedHeight,
  });

  final double height;
  final double inset;
  final double rememberedHeight;

  static const keyboardThreshold = 80.0;
  static const orientationWidthDelta = 80.0;

  static ViewportFrame resolve({
    required Size mediaSize,
    required double viewInsetBottom,
    required double overlap,
    required bool focused,
    required double? browserHeight,
    required double rememberedHeight,
    required double? lastWidth,
  }) {
    var full = rememberedHeight;
    if (lastWidth != null &&
        (mediaSize.width - lastWidth).abs() > orientationWidthDelta) {
      full = 0;
    }
    final browserOpen = overlap > keyboardThreshold;
    final hasBrowser = browserHeight != null;
    final flutterOpen =
        !hasBrowser && viewInsetBottom > keyboardThreshold && focused;
    final keyboardOpen = browserOpen || flutterOpen;
    if (!browserOpen) {
      full = math.max(full, mediaSize.height);
      if (browserHeight != null) {
        full = math.max(full, browserHeight);
      }
    }
    final height = math.max(
      math.max(mediaSize.height, full),
      browserHeight ?? 0,
    );
    final inset = keyboardOpen ? math.max(viewInsetBottom, overlap) : 0.0;
    return ViewportFrame(
      height: height,
      inset: inset,
      rememberedHeight: full,
    );
  }
}

class ViewportSync extends StatefulWidget {
  const ViewportSync({super.key, required this.child});

  final Widget child;

  @override
  State<ViewportSync> createState() => _ViewportSyncState();
}

class _ViewportSyncState extends State<ViewportSync> with WidgetsBindingObserver {
  void Function()? _stop;
  Timer? _debounce;
  double _fullHeight = 0;
  double? _lastWidth;
  double _lastHeight = -1;
  double _lastInset = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_applySync);
    metrics.pinHost();
    _stop = metrics.listenViewport(_scheduleSync);
  }

  void _scheduleSync() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 50), _applySync);
  }

  void _applySync() {
    if (!mounted) return;
    final overlap = metrics.keyboardOverlap();
    if (overlap <= ViewportFrame.keyboardThreshold) {
      metrics.pinHost();
      metrics.releaseKeyboard();
    }
    final media = MediaQuery.maybeOf(context);
    if (media == null) {
      setState(() {});
      return;
    }
    final focused = FocusManager.instance.primaryFocus?.hasFocus ?? false;
    final frame = ViewportFrame.resolve(
      mediaSize: media.size,
      viewInsetBottom: media.viewInsets.bottom,
      overlap: overlap,
      focused: focused,
      browserHeight: metrics.layoutHeight() ?? metrics.windowInnerHeight(),
      rememberedHeight: _fullHeight,
      lastWidth: _lastWidth,
    );
    if ((frame.height - _lastHeight).abs() < 0.5 &&
        (frame.inset - _lastInset).abs() < 0.5) {
      _fullHeight = frame.rememberedHeight;
      _lastWidth = media.size.width;
      return;
    }
    setState(() {});
  }

  @override
  void didChangeMetrics() => _applySync();

  @override
  void dispose() {
    _debounce?.cancel();
    FocusManager.instance.removeListener(_applySync);
    WidgetsBinding.instance.removeObserver(this);
    _stop?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final focused = FocusManager.instance.primaryFocus?.hasFocus ?? false;
    final frame = ViewportFrame.resolve(
      mediaSize: media.size,
      viewInsetBottom: media.viewInsets.bottom,
      overlap: metrics.keyboardOverlap(),
      focused: focused,
      browserHeight: metrics.layoutHeight() ?? metrics.windowInnerHeight(),
      rememberedHeight: _fullHeight,
      lastWidth: _lastWidth,
    );
    _fullHeight = frame.rememberedHeight;
    _lastWidth = media.size.width;
    _lastHeight = frame.height;
    _lastInset = frame.inset;

    return MediaQuery(
      data: media.copyWith(
        size: Size(media.size.width, frame.height),
        viewInsets: EdgeInsets.only(bottom: frame.inset),
      ),
      child: widget.child,
    );
  }
}
