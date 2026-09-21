import 'dart:js_interop';

import 'package:web/web.dart' as web;

@JS('__tpLayoutHeight')
external JSNumber? _jsLayoutHeight();

@JS('__tpKeyboardOverlap')
external JSNumber? _jsKeyboardOverlap();

@JS('__tpSyncViewport')
external void _jsSyncViewport();

void Function()? listenViewport(void Function() onChange) {
  void notify() => onChange();
  final handler = (web.Event _) {
    pinHost();
    notify();
  }.toJS;
  web.window.addEventListener('resize', handler);
  web.window.addEventListener('orientationchange', handler);
  web.window.addEventListener('pageshow', handler);
  web.document.addEventListener('focusout', handler);
  final viewport = web.window.visualViewport;
  viewport?.addEventListener('resize', handler);
  pinHost();
  return () {
    web.window.removeEventListener('resize', handler);
    web.window.removeEventListener('orientationchange', handler);
    web.window.removeEventListener('pageshow', handler);
    web.document.removeEventListener('focusout', handler);
    viewport?.removeEventListener('resize', handler);
  };
}

void pinHost() {
  try {
    _jsSyncViewport();
  } catch (_) {}
  for (final selector in ['flutter-view', 'flt-glass-pane']) {
    final el = web.document.querySelector(selector);
    if (el == null || !el.isA<web.HTMLElement>()) continue;
    final style = (el as web.HTMLElement).style;
    style.removeProperty('max-height');
    style.width = '100%';
    style.height = '100%';
    style.setProperty('min-height', '100%');
  }
}

double? windowInnerHeight() {
  final height = web.window.innerHeight.toDouble();
  return height > 0 ? height : null;
}

double? largeViewportHeight() => layoutHeight();

double? screenAvailHeight() => layoutHeight();

double? layoutHeight() {
  try {
    final value = _jsLayoutHeight()?.toDartDouble;
    if (value != null && value > 0) return value;
  } catch (_) {}
  return windowInnerHeight();
}

double keyboardOverlap() {
  try {
    final value = _jsKeyboardOverlap()?.toDartDouble;
    if (value != null && value > 0) return value;
  } catch (_) {}
  final viewport = web.window.visualViewport;
  if (viewport == null) return 0;
  final overlay =
      web.window.innerHeight.toDouble() - viewport.height - viewport.offsetTop;
  return overlay > 0 ? overlay : 0;
}

bool visualKeyboardOpen() => keyboardOverlap() > 80;
