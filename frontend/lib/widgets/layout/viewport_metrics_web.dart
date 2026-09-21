import 'dart:js_interop';

import 'package:web/web.dart' as web;

const _probeId = 'tp-lvh-probe';

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
    body.style.bottom = 'auto';
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

double? layoutHeight() {
  final client = web.document.documentElement?.clientHeight.toDouble();
  final inner = windowInnerHeight();
  final visual = web.window.visualViewport;
  final visualExtent = visual == null
      ? null
      : visual.height + visual.offsetTop;
  final lvh = largeViewportHeight();
  var best = 0.0;
  for (final value in [client, inner, visualExtent, lvh]) {
    if (value != null && value > best) best = value;
  }
  return best > 0 ? best : null;
}

double keyboardOverlap() {
  final viewport = web.window.visualViewport;
  if (viewport == null) return 0;
  final inner = web.window.innerHeight.toDouble();
  final innerOverlap = inner - viewport.height - viewport.offsetTop;
  if (innerOverlap > 80) return innerOverlap;
  final lvh = largeViewportHeight();
  if (lvh == null) return 0;
  final largeOverlap = lvh - viewport.height - viewport.offsetTop;
  if (largeOverlap <= 80) return 0;
  final active = web.document.activeElement;
  if (active == null) return 0;
  final tag = active.tagName.toLowerCase();
  final typing = tag == 'input' || tag == 'textarea' || tag == 'select';
  return typing ? largeOverlap : 0;
}

bool visualKeyboardOpen() => keyboardOverlap() > 80;

void _pinBox(web.HTMLElement element, String px) {
  final style = element.style;
  style.width = '100%';
  style.height = px;
  style.setProperty('min-height', px);
  style.setProperty('max-height', px);
}
