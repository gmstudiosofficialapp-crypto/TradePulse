import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'pwa_install_bridge.dart';

const _dismissKey = 'tradepulse.pwa.bannerDismissed';

PwaInstallBridge createBridge() => WebPwaInstallBridge();

@JS('__tpTakeInstallPrompt')
external JSAny? _takeInstallPrompt();

extension type _BeforeInstallPromptEvent._(web.Event _) implements web.Event {
  external JSPromise<JSAny?> prompt();
}

@JS('navigator.standalone')
external JSBoolean? get _iosStandalone;

class WebPwaInstallBridge implements PwaInstallBridge {
  _BeforeInstallPromptEvent? _deferred;
  bool _appInstalled = false;
  JSFunction? _onBeforeInstall;
  JSFunction? _onAppInstalled;
  JSFunction? _onEarlyReady;
  void Function()? _listener;

  @override
  bool get isStandalone {
    if (_appInstalled) return true;
    if (web.window.matchMedia('(display-mode: standalone)').matches) {
      return true;
    }
    final ios = _iosStandalone;
    return ios != null && ios.toDart;
  }

  @override
  bool get canNativePrompt => _deferred != null && !isStandalone;

  @override
  bool get isIosBrowser => _detectIos() && !isStandalone;

  @override
  bool get isAndroidBrowser {
    if (isStandalone || isIosBrowser) return false;
    return web.window.navigator.userAgent.contains('Android');
  }

  @override
  bool get sessionDismissed =>
      web.window.sessionStorage.getItem(_dismissKey) == '1';

  @override
  void attach(void Function() onChange) {
    _listener = onChange;
    _onBeforeInstall ??= ((web.Event event) {
      event.preventDefault();
      _deferred = _BeforeInstallPromptEvent._(event);
      _listener?.call();
    }).toJS;
    _onAppInstalled ??= ((web.Event _) {
      _deferred = null;
      _appInstalled = true;
      _listener?.call();
    }).toJS;
    _onEarlyReady ??= ((web.Event _) {
      _adoptEarlyPrompt();
    }).toJS;
    web.window.addEventListener('beforeinstallprompt', _onBeforeInstall!);
    web.window.addEventListener('appinstalled', _onAppInstalled!);
    web.window.addEventListener('tp-install-ready', _onEarlyReady!);
    _adoptEarlyPrompt();
  }

  @override
  void detach() {
    if (_onBeforeInstall != null) {
      web.window.removeEventListener('beforeinstallprompt', _onBeforeInstall!);
    }
    if (_onAppInstalled != null) {
      web.window.removeEventListener('appinstalled', _onAppInstalled!);
    }
    if (_onEarlyReady != null) {
      web.window.removeEventListener('tp-install-ready', _onEarlyReady!);
    }
    _listener = null;
  }

  @override
  void dismissForSession() {
    web.window.sessionStorage.setItem(_dismissKey, '1');
  }

  @override
  Future<PwaPromptOutcome> promptNativeInstall() async {
    final event = _deferred;
    if (event == null) return PwaPromptOutcome.unavailable;
    try {
      await event.prompt().toDart;
      _deferred = null;
      _listener?.call();
      return PwaPromptOutcome.shown;
    } catch (_) {
      return PwaPromptOutcome.unavailable;
    }
  }

  void _adoptEarlyPrompt() {
    if (_deferred != null) return;
    try {
      final raw = _takeInstallPrompt();
      if (raw == null) return;
      _deferred = _BeforeInstallPromptEvent._(raw as web.Event);
      _listener?.call();
    } catch (_) {}
  }

  bool _detectIos() {
    final ua = web.window.navigator.userAgent;
    if (ua.contains('iPhone') || ua.contains('iPad') || ua.contains('iPod')) {
      return true;
    }
    return web.window.navigator.platform == 'MacIntel' &&
        web.window.navigator.maxTouchPoints > 1;
  }
}
