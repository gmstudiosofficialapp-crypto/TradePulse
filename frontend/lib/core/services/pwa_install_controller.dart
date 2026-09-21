import 'package:flutter/foundation.dart';

import 'pwa_install_bridge.dart';

enum PwaInstallSurface { hidden, native, ios, android }

class PwaInstallController extends ChangeNotifier {
  PwaInstallController({PwaInstallBridge? bridge})
      : _bridge = bridge ?? PwaInstallBridge.create();

  final PwaInstallBridge _bridge;
  bool _iosGuideOpen = false;
  bool _attached = false;

  PwaInstallBridge get bridge => _bridge;

  bool get iosGuideOpen => _iosGuideOpen;

  PwaInstallSurface get surface {
    if (_bridge.isStandalone || _bridge.sessionDismissed) {
      return PwaInstallSurface.hidden;
    }
    if (_bridge.canNativePrompt) return PwaInstallSurface.native;
    if (_bridge.isIosBrowser) return PwaInstallSurface.ios;
    if (_bridge.isAndroidBrowser) return PwaInstallSurface.android;
    return PwaInstallSurface.hidden;
  }

  bool get shouldShow => surface != PwaInstallSurface.hidden;

  void attach() {
    if (_attached) return;
    _attached = true;
    _bridge.attach(notifyListeners);
  }

  void dismiss() {
    _iosGuideOpen = false;
    _bridge.dismissForSession();
    notifyListeners();
  }

  void openIosGuide() {
    if (surface != PwaInstallSurface.ios &&
        surface != PwaInstallSurface.android) {
      return;
    }
    _iosGuideOpen = true;
    notifyListeners();
  }

  void closeIosGuide() {
    _iosGuideOpen = false;
    notifyListeners();
  }

  Future<PwaPromptOutcome> installNow() {
    if (surface != PwaInstallSurface.native) {
      return Future.value(PwaPromptOutcome.unavailable);
    }
    return _bridge.promptNativeInstall();
  }

  @override
  void dispose() {
    _bridge.detach();
    super.dispose();
  }
}
