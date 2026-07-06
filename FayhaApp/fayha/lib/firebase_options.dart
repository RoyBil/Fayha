import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDs8Y0fInERMKmU_5aNybw4sHlUK8EgGl0',
    appId: '1:542210824427:android:c041c99a83dfc98780c6ae',
    messagingSenderId: '542210824427',
    projectId: 'fayha-choir-723b0',
    storageBucket: 'fayha-choir-723b0.firebasestorage.app',
  );

  // iOS options — update appId after adding iOS app in Firebase console.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDs8Y0fInERMKmU_5aNybw4sHlUK8EgGl0',
    appId: '1:542210824427:ios:c041c99a83dfc98780c6ae',
    messagingSenderId: '542210824427',
    projectId: 'fayha-choir-723b0',
    storageBucket: 'fayha-choir-723b0.firebasestorage.app',
    iosBundleId: 'com.fayha.fayha',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDs8Y0fInERMKmU_5aNybw4sHlUK8EgGl0',
    appId: '1:542210824427:web:c041c99a83dfc98780c6ae',
    messagingSenderId: '542210824427',
    projectId: 'fayha-choir-723b0',
    storageBucket: 'fayha-choir-723b0.firebasestorage.app',
  );
}
