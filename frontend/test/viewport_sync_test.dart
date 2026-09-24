import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradepulse_frontend/widgets/layout/viewport_sync.dart';

void main() {
  test('closed keyboard drops stale engine insets and keeps full height', () {
    final closed = ViewportFrame.resolve(
      mediaSize: const Size(390, 844),
      viewInsetBottom: 320,
      overlap: 0,
      focused: false,
      browserHeight: 844,
      rememberedHeight: 844,
      lastWidth: 390,
    );
    expect(closed.height, 844);
    expect(closed.inset, 0);
  });

  test('overlay overlap lifts content without shrinking the engine height', () {
    final open = ViewportFrame.resolve(
      mediaSize: const Size(390, 844),
      viewInsetBottom: 0,
      overlap: 324,
      focused: true,
      browserHeight: 844,
      rememberedHeight: 844,
      lastWidth: 390,
    );
    expect(open.height, 844);
    expect(open.inset, 324);
  });

  test('already-shrunk engine does not get a second keyboard inset', () {
    final frame = ViewportFrame.resolve(
      mediaSize: const Size(390, 524),
      viewInsetBottom: 0,
      overlap: 320,
      focused: true,
      browserHeight: 844,
      rememberedHeight: 844,
      lastWidth: 390,
    );
    expect(frame.height, 524);
    expect(frame.inset, 0);
  });

  test('focused field can use the engine inset when the browser reports none', () {
    final frame = ViewportFrame.resolve(
      mediaSize: const Size(390, 844),
      viewInsetBottom: 280,
      overlap: 0,
      focused: true,
      browserHeight: 844,
      rememberedHeight: 844,
      lastWidth: 390,
    );
    expect(frame.height, 844);
    expect(frame.inset, 280);
  });
}
