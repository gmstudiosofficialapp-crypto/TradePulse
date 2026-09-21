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
    final focused = FocusManager.instance.primaryFocus?.hasFocus ?? false;
    final overlap = metrics.keyboardOverlap();
    final browserH = metrics.layoutHeight() ?? metrics.windowInnerHeight();
    final restored =
        browserH != null && browserH > media.size.height + 40;
    final visualOpen = overlap > 80;
    final flutterOpen = media.viewInsets.bottom > 80 && focused;
    final keyboardOpen = !restored && (visualOpen || flutterOpen);
    final height = restored
        ? browserH
        : keyboardOpen
            ? media.size.height
            : math.max(media.size.height, browserH ?? media.size.height);
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
