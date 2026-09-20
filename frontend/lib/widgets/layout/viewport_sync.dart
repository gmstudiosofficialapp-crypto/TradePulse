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
    _stop = metrics.listenViewport(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final focused = FocusManager.instance.primaryFocus?.hasFocus ?? false;
    final keyboardOpen = metrics.visualKeyboardOpen() ||
        (media.viewInsets.bottom > 80 && focused);
    final inner = metrics.windowInnerHeight();
    final height = keyboardOpen
        ? media.size.height
        : math.max(media.size.height, inner ?? media.size.height);
    return MediaQuery(
      data: media.copyWith(
        size: Size(media.size.width, height),
        viewInsets: keyboardOpen ? media.viewInsets : EdgeInsets.zero,
      ),
      child: widget.child,
    );
  }
}
