import 'package:flutter/material.dart';

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
    return ViewportFrame(
      height: mediaSize.height,
      inset: 0,
      rememberedHeight: mediaSize.height,
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
  FocusNode? _focused;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_onFocus);
  }

  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  void _onFocus() {
    final next = FocusManager.instance.primaryFocus;
    if (next == _focused) return;
    _focused = next;
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
    FocusManager.instance.removeListener(_onFocus);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(viewInsets: EdgeInsets.zero),
      child: widget.child,
    );
  }
}
