import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

const _probeId = 'tp-lvh-probe';

double _tallest = 0;
int _orientation = -1;

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
  final height = layoutHeight();
  if (height == null) return;
  final px = '${height.round()}px';
  final html = web.document.documentElement;
  if (html != null && html.isA<web.HTMLElement>()) {
    _pinBox(html as web.HTMLElement, px);
  }
  final body = web.document.body;
  if (body != null) {
    _pinBox(body, px);
    body.style.position = 'fixed';
    body.style.top = '0px';
    body.style.left = '0px';
    body.style.right = '0px';
    body.style.removeProperty('bottom');
    body.style.removeProperty('inset');
    body.style.overflow = 'hidden';
  }
  for (final selector in ['flutter-view', 'flt-glass-pane']) {
    final el = web.document.querySelector(selector);
    if (el != null && el.isA<web.HTMLElement>()) {
      _pinBox(el as web.HTMLElement, px);
    }
  }
}

double? windowInnerHeight() {
  final height = web.window.innerHeight.toDouble();
  return height > 0 ? height : null;
}

double? largeViewportHeight() {
  final body = web.document.body;
  if (body == null) return null;
  var probe = web.document.getElementById(_probeId);
  if (probe == null || !probe.isA<web.HTMLElement>()) {
    final created = web.document.createElement('div');
    if (!created.isA<web.HTMLElement>()) return null;
    final el = created as web.HTMLElement;
    el.id = _probeId;
    el.setAttribute(
      'style',
      'position:fixed;left:0;top:0;width:0;height:100lvh;visibility:hidden;pointer-events:none;z-index:-1',
    );
    body.appendChild(el);
    probe = el;
  }
  final height = (probe as web.HTMLElement).getBoundingClientRect().height;
  return height > 0 ? height : null;
}

double? screenAvailHeight() {
  if (web.window.navigator.maxTouchPoints < 1) return null;
  final avail = web.window.screen.availHeight.toDouble();
  final height = web.window.screen.height.toDouble();
  final outer = web.window.outerHeight.toDouble();
  var best = 0.0;
  for (final value in [avail, height, outer]) {
    if (value > best) best = value;
  }
  return best > 0 ? best : null;
}

double? layoutHeight() {
  _rememberClosedHeight();
  var best = 0.0;
  for (final value in [
    windowInnerHeight(),
    web.document.documentElement?.clientHeight.toDouble(),
    largeViewportHeight(),
    screenAvailHeight(),
    _tallest > 0 ? _tallest : null,
  ]) {
    if (value != null && value > best) best = value;
  }
  return best > 0 ? best : null;
}

double keyboardOverlap() {
  final viewport = web.window.visualViewport;
  if (viewport == null) return 0;
  final inner = web.window.innerHeight.toDouble();
  final overlay = inner - viewport.height - viewport.offsetTop;
  return overlay > 0 ? overlay : 0;
}

bool visualKeyboardOpen() => keyboardOverlap() > 80;

void _rememberClosedHeight() {
  final portrait = web.window.innerWidth <= web.window.innerHeight ? 0 : 1;
  if (_orientation != portrait) {
    _orientation = portrait;
    _tallest = 0;
  }
  if (keyboardOverlap() > 80) return;
  for (final value in [
    windowInnerHeight(),
    web.document.documentElement?.clientHeight.toDouble(),
    largeViewportHeight(),
    screenAvailHeight(),
  ]) {
    if (value != null) {
      _tallest = math.max(_tallest, value);
    }
  }
}

void _pinBox(web.HTMLElement element, String px) {
  final style = element.style;
  style.width = '100%';
  style.height = px;
  style.setProperty('min-height', px);
  style.removeProperty('max-height');
}
