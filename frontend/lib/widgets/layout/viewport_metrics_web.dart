import 'dart:js_interop';

import 'package:web/web.dart' as web;

@JS('navigator.virtualKeyboard')
external _VirtualKeyboard? get _virtualKeyboard;

extension type _VirtualKeyboard._(JSObject _) implements JSObject {
  external set overlaysContent(bool value);
  external web.DOMRect get boundingRect;
  external void addEventListener(String type, JSFunction listener);
  external void removeEventListener(String type, JSFunction listener);
}

void enableOverlayKeyboard() {
  final keyboard = _virtualKeyboard;
  if (keyboard == null) return;
  try {
    keyboard.overlaysContent = true;
  } catch (_) {}
}

void Function()? listenViewport(void Function() onChange) {
  final handler = ((web.Event _) => onChange()).toJS;
  web.window.addEventListener('resize', handler);
  final viewport = web.window.visualViewport;
  viewport?.addEventListener('resize', handler);
  viewport?.addEventListener('scroll', handler);
  final keyboard = _virtualKeyboard;
  keyboard?.addEventListener('geometrychange', handler);
  return () {
    web.window.removeEventListener('resize', handler);
    viewport?.removeEventListener('resize', handler);
    viewport?.removeEventListener('scroll', handler);
    keyboard?.removeEventListener('geometrychange', handler);
  };
}

double? layoutHeight() {
  final height = web.window.innerHeight.toDouble();
  return height > 0 ? height : null;
}

double keyboardOverlap() {
  final keyboard = _virtualKeyboard;
  if (keyboard != null) {
    final height = keyboard.boundingRect.height;
    if (height > 1) return height;
  }
  final viewport = web.window.visualViewport;
  if (viewport == null) return 0;
  final overlap =
      web.window.innerHeight - viewport.height - viewport.offsetTop;
  return overlap > 1 ? overlap : 0;
}
