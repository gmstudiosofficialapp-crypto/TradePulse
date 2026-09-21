import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'viewport_metrics_stub.dart'
    if (dart.library.html) 'viewport_metrics_web.dart' as metrics;

class ViewportSync extends StatefulWidget {
  const ViewportSync({super.key, required this.child});

  final Widget child;

  @override
  State<ViewportSync> createState() => _ViewportSyncState();
}

class _ViewportSyncState extends State<ViewportSync> with WidgetsBindingObserver {
  void Function()? _stop;
  double _fullHeight = 0;
  Size? _lastSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_sync);
    metrics.pinHost();
    _stop = metrics.listenViewport(_sync);
  }

  void _sync() {
    metrics.pinHost();
    if (mounted) setState(() {});
  }

  @override
  void didChangeMetrics() => _sync();

  @override
  void dispose() {
    FocusManager.instance.removeListener(_sync);
    WidgetsBinding.instance.removeObserver(this);
    _stop?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final overlap = metrics.keyboardOverlap();
    final focused = FocusManager.instance.primaryFocus?.hasFocus ?? false;
    final browserHeight = metrics.layoutHeight() ?? metrics.windowInnerHeight();
    final hasBrowser = browserHeight != null;
    if (_lastSize != null &&
        (media.size.width - _lastSize!.width).abs() > 80) {
      _fullHeight = 0;
    }
    _lastSize = media.size;
    if (overlap <= 80) {
      _fullHeight = math.max(_fullHeight, media.size.height);
      if (browserHeight != null) {
        _fullHeight = math.max(_fullHeight, browserHeight);
      }
    }
    final overlayOpen = overlap > 80;
    final flutterOpen = media.viewInsets.bottom > 80 && focused;
    final keyboardOpen = overlayOpen || (!hasBrowser && flutterOpen);
    final height = math.max(
      math.max(media.size.height, _fullHeight),
      browserHeight ?? 0,
    );
    final inset = keyboardOpen
        ? math.max(media.viewInsets.bottom, overlap)
        : 0.0;

    return MediaQuery(
      data: media.copyWith(
        size: Size(media.size.width, height),
        viewInsets: EdgeInsets.only(bottom: inset),
      ),
      child: widget.child,
    );
  }
}
