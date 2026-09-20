import 'dart:js_interop';

import 'package:web/web.dart' as web;

void Function()? listenViewport(void Function() onChange) {
  final handler = (web.Event _) {
    onChange();
  }.toJS;
  web.window.addEventListener('resize', handler);
  final viewport = web.window.visualViewport;
  viewport?.addEventListener('resize', handler);
  viewport?.addEventListener('scroll', handler);
  return () {
    web.window.removeEventListener('resize', handler);
    viewport?.removeEventListener('resize', handler);
    viewport?.removeEventListener('scroll', handler);
  };
}

double? windowInnerHeight() {
  final height = web.window.innerHeight.toDouble();
  return height > 0 ? height : null;
}

bool visualKeyboardOpen() {
  final viewport = web.window.visualViewport;
  if (viewport == null) return false;
  return (web.window.innerHeight - viewport.height) > 120;
}
