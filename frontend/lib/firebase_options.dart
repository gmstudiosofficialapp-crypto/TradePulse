import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return web;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are only configured for the wallet-operator web app.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAywbKoNU-Lxr51AYgmEDjEYc4Q_d3YHSM',
    appId: '1:33087758064:web:df2b4d760020c0440a2c35',
    messagingSenderId: '33087758064',
    projectId: 'wallet-operator',
    authDomain: 'wallet-operator.firebaseapp.com',
    storageBucket: 'wallet-operator.appspot.com',
  );
}
