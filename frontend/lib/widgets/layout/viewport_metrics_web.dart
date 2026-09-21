import 'dart:js_interop';

import 'package:web/web.dart' as web;

void Function()? listenViewport(void Function() onChange) {
  void notify() => onChange();
  final handler = (web.Event _) {
    pinHost();
    notify();
  }.toJS;
  web.window.addEventListener('resize', handler);
  web.window.addEventListener('orientationchange', handler);
  web.window.addEventListener('pageshow', handler);
  web.document.addEventListener('focusin', handler);
  web.document.addEventListener('focusout', handler);
  final viewport = web.window.visualViewport;
  viewport?.addEventListener('resize', handler);
  viewport?.addEventListener('scroll', handler);
  pinHost();
  return () {
    web.window.removeEventListener('resize', handler);
    web.window.removeEventListener('orientationchange', handler);
    web.window.removeEventListener('pageshow', handler);
    web.document.removeEventListener('focusin', handler);
    web.document.removeEventListener('focusout', handler);
    viewport?.removeEventListener('resize', handler);
    viewport?.removeEventListener('scroll', handler);
  };
}

void pinHost() {
  final html = web.document.documentElement;
  final body = web.document.body;
  if (html != null && html.isA<web.HTMLElement>()) {
    _pinFill((html as web.HTMLElement).style);
  }
  if (body != null) {
    _pinFill(body.style);
    body.style.position = 'fixed';
    body.style.setProperty('inset', '0');
    body.style.overflow = 'hidden';
  }
  if (keyboardOverlap() > 80) return;
  for (final selector in ['flutter-view', 'flt-glass-pane']) {
    final el = web.document.querySelector(selector);
    if (el != null && el.isA<web.HTMLElement>()) {
      _pinFill((el as web.HTMLElement).style);
    }
  }
}

double? windowInnerHeight() {
  final height = web.window.innerHeight.toDouble();
  return height > 0 ? height : null;
}

double? layoutHeight() {
  final client = web.document.documentElement?.clientHeight.toDouble();
  final inner = windowInnerHeight();
  final visual = web.window.visualViewport?.height;
  var best = 0.0;
  for (final value in [client, inner, visual]) {
    if (value != null && value > best) best = value;
  }
  return best > 0 ? best : null;
}

double keyboardOverlap() {
  final viewport = web.window.visualViewport;
  if (viewport == null) return 0;
  final overlap =
      web.window.innerHeight.toDouble() - viewport.height - viewport.offsetTop;
  return overlap > 0 ? overlap : 0;
}

bool visualKeyboardOpen() => keyboardOverlap() > 80;

void _pinFill(web.CSSStyleDeclaration style) {
  style.width = '100%';
  style.height = '100%';
  style.setProperty('min-height', '100%');
  style.setProperty('min-height', '100lvh');
}
