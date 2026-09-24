import 'package:flutter/material.dart';

import 'viewport_metrics.dart' as metrics;

class ViewportFrame {
  const ViewportFrame({
    required this.height,
    required this.inset,
    required this.rememberedHeight,
  });

  final double height;
  final double inset;
  final double rememberedHeight;

  static ViewportFrame resolve({
    required Size mediaSize,
    required double viewInsetBottom,
    required double overlap,
    required bool focused,
    required double? browserHeight,
    required double rememberedHeight,
    required double? lastWidth,
  }) {
    final height = mediaSize.height;
    final layout = browserHeight ?? height;
    var inset = 0.0;
    if (overlap > 1) {
      final visible = layout - overlap;
      final alreadyShrunk = (height - visible).abs() < 8;
      inset = alreadyShrunk ? 0 : overlap;
    } else if (focused && viewInsetBottom > 1) {
      inset = viewInsetBottom;
    }
    return ViewportFrame(
      height: height,
      inset: inset,
      rememberedHeight: height,
    );
  }
}

class ViewportSync extends StatefulWidget {
  const ViewportSync({super.key, required this.child});

  final Widget child;

  @override
  State<ViewportSync> createState() => _ViewportSyncState();
}

class _ViewportSyncState extends State<ViewportSync>
    with WidgetsBindingObserver {
  FocusNode? _focused;
  void Function()? _unlisten;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_onFocus);
    metrics.enableOverlayKeyboard();
    _unlisten = metrics.listenViewport(_onBrowserViewport);
  }

  void _onBrowserViewport() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  void _onFocus() {
    final next = FocusManager.instance.primaryFocus;
    if (next == _focused) return;
    _focused = next;
    if (mounted) setState(() {});
    if (next?.hasFocus ?? false) {
      _ensureFocusedVisible();
    }
  }

  void _ensureFocusedVisible() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ctx.mounted) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.2,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _unlisten?.call();
    FocusManager.instance.removeListener(_onFocus);
    WidgetsBinding.instance.removeObserver(this);
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
      browserHeight: metrics.layoutHeight(),
      rememberedHeight: media.size.height,
      lastWidth: media.size.width,
    );
    return MediaQuery(
      data: media.copyWith(
        viewInsets: EdgeInsets.only(bottom: frame.inset),
      ),
      child: widget.child,
    );
  }
}
