import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradepulse_frontend/widgets/layout/viewport_sync.dart';

void main() {
  test('keyboard never rewrites the browser height or adds insets', () {
    final closed = ViewportFrame.resolve(
      mediaSize: const Size(390, 844),
      viewInsetBottom: 320,
      overlap: 0,
      focused: false,
      browserHeight: null,
      rememberedHeight: 844,
      lastWidth: 390,
    );
    expect(closed.height, 844);
    expect(closed.inset, 0);

    final open = ViewportFrame.resolve(
      mediaSize: const Size(390, 844),
      viewInsetBottom: 320,
      overlap: 324,
      focused: true,
      browserHeight: 844,
      rememberedHeight: 844,
      lastWidth: 390,
    );
    expect(open.height, 844);
    expect(open.inset, 0);
  });

  test('engine size is used as-is like a normal website', () {
    final frame = ViewportFrame.resolve(
      mediaSize: const Size(390, 524),
      viewInsetBottom: 0,
      overlap: 0,
      focused: false,
      browserHeight: 844,
      rememberedHeight: 844,
      lastWidth: 390,
    );
    expect(frame.height, 524);
    expect(frame.inset, 0);
  });
}
