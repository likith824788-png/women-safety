// File generated with real Firebase project credentials
// Project: model-47163

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
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBYZ2o7_hj30NcTlR0eFnfiDLHR_jIeRVk',
    authDomain: 'model-47163.firebaseapp.com',
    projectId: 'model-47163',
    storageBucket: 'model-47163.firebasestorage.app',
    messagingSenderId: '533541214015',
    appId: '1:533541214015:web:50eac6145eed6824a0258a',
    measurementId: 'G-HCLN7CK103',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBYZ2o7_hj30NcTlR0eFnfiDLHR_jIeRVk',
    appId: '1:533541214015:web:50eac6145eed6824a0258a',
    messagingSenderId: '533541214015',
    projectId: 'model-47163',
    storageBucket: 'model-47163.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBYZ2o7_hj30NcTlR0eFnfiDLHR_jIeRVk',
    appId: '1:533541214015:web:50eac6145eed6824a0258a',
    messagingSenderId: '533541214015',
    projectId: 'model-47163',
    storageBucket: 'model-47163.firebasestorage.app',
  );
}
