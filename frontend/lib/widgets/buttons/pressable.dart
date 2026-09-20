import 'package:flutter/material.dart';

class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onPressed,
    this.enabled = true,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final bool enabled;
  final BorderRadius? borderRadius;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  var _pressed = false;
  var _hovered = false;

  bool get _active => widget.enabled && widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: _active ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: _active ? (_) => setState(() => _pressed = true) : null,
        onTapUp: _active ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: () => setState(() => _pressed = false),
        onTap: _active ? widget.onPressed : null,
        child: AnimatedScale(
          scale: !_active
              ? 1
              : _pressed
                  ? 0.97
                  : _hovered
                      ? 1.015
                      : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}
