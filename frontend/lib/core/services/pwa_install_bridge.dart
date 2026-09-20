import 'pwa_install_bridge_stub.dart'
    if (dart.library.html) 'pwa_install_bridge_web.dart' as impl;

enum PwaPromptOutcome { unavailable, shown, dismissed, accepted }

abstract class PwaInstallBridge {
  bool get isStandalone;
  bool get canNativePrompt;
  bool get isIosBrowser;
  bool get sessionDismissed;

  void attach(void Function() onChange);
  void detach();
  void dismissForSession();
  Future<PwaPromptOutcome> promptNativeInstall();

  static PwaInstallBridge create() => impl.createBridge();
}
