import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradepulse_frontend/widgets/layout/viewport_sync.dart';

void main() {
  test('stale Flutter insets are cleared when the keyboard is closed', () {
    final frame = ViewportFrame.resolve(
      mediaSize: const Size(390, 844),
      viewInsetBottom: 320,
      overlap: 0,
      focused: false,
      browserHeight: null,
      rememberedHeight: 844,
      lastWidth: 390,
    );
    expect(frame.height, 844);
    expect(frame.inset, 0);
  });

  test('focused field keeps full height without lifting the shell', () {
    final frame = ViewportFrame.resolve(
      mediaSize: const Size(390, 844),
      viewInsetBottom: 320,
      overlap: 0,
      focused: true,
      browserHeight: null,
      rememberedHeight: 844,
      lastWidth: 390,
    );
    expect(frame.height, 844);
    expect(frame.inset, 0);
  });

  test('browser visualViewport overlap does not shrink height or add insets', () {
    final frame = ViewportFrame.resolve(
      mediaSize: const Size(390, 520),
      viewInsetBottom: 0,
      overlap: 324,
      focused: true,
      browserHeight: 844,
      rememberedHeight: 844,
      lastWidth: 390,
    );
    expect(frame.height, 844);
    expect(frame.inset, 0);
  });

  test('shrunk engine height restores after keyboard close', () {
    final frame = ViewportFrame.resolve(
      mediaSize: const Size(390, 524),
      viewInsetBottom: 0,
      overlap: 0,
      focused: false,
      browserHeight: 844,
      rememberedHeight: 844,
      lastWidth: 390,
    );
    expect(frame.height, 844);
    expect(frame.inset, 0);
  });

  test('orientation width change resets remembered height', () {
    final frame = ViewportFrame.resolve(
      mediaSize: const Size(844, 390),
      viewInsetBottom: 0,
      overlap: 0,
      focused: false,
      browserHeight: 390,
      rememberedHeight: 844,
      lastWidth: 390,
    );
    expect(frame.height, 390);
    expect(frame.inset, 0);
  });
}
