import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBXjolvKWrsVAIDbxB5YdKPihWjWX1VE9U',
    appId: '1:717699093807:web:7d4fac96899d2406bc3dda',
    messagingSenderId: '717699093807',
    projectId: 'my-bingo-mk',
    authDomain: 'my-bingo-mk.firebaseapp.com',
    storageBucket: 'my-bingo-mk.firebasestorage.app',
    measurementId: 'G-55GWKC8E3V',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyASD65L8CWTV_YiB44Dgt-ajRLLDn8wtY8',
    appId: '1:717699093807:android:1a523688814d9cabbc3dda',
    messagingSenderId: '717699093807',
    projectId: 'my-bingo-mk',
    storageBucket: 'my-bingo-mk.firebasestorage.app',
  );
}
