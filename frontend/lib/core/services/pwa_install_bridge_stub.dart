import 'pwa_install_bridge.dart';

PwaInstallBridge createBridge() => StubPwaInstallBridge();

class StubPwaInstallBridge implements PwaInstallBridge {
  bool standalone = false;
  bool nativePrompt = false;
  bool iosBrowser = false;
  bool dismissed = false;
  int promptCalls = 0;
  PwaPromptOutcome nextOutcome = PwaPromptOutcome.unavailable;

  @override
  bool get isStandalone => standalone;

  @override
  bool get canNativePrompt => nativePrompt && !standalone;

  @override
  bool get isIosBrowser => iosBrowser && !standalone;

  @override
  bool get sessionDismissed => dismissed;

  @override
  void attach(void Function() onChange) {}

  @override
  void detach() {}

  @override
  void dismissForSession() {
    dismissed = true;
  }

  @override
  Future<PwaPromptOutcome> promptNativeInstall() async {
    promptCalls += 1;
    if (!canNativePrompt) return PwaPromptOutcome.unavailable;
    return nextOutcome;
  }
}
