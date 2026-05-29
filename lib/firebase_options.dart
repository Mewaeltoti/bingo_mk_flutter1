// File generated manually for Firebase configuration.
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
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBD6nf3n1r3s2UTnoj-B7joz3bX-p37r1Y',
    appId: '1:690827139986:android:436f292d8364c2cdc2ff4b',
    messagingSenderId: '690827139986',
    projectId: 'bingo-be44c',
    authDomain: 'bingo-be44c.firebaseapp.com',
    storageBucket: 'bingo-be44c.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBD6nf3n1r3s2UTnoj-B7joz3bX-p37r1Y',
    appId: '1:690827139986:android:436f292d8364c2cdc2ff4b',
    messagingSenderId: '690827139986',
    projectId: 'bingo-be44c',
    storageBucket: 'bingo-be44c.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBvJDre_XABERFvFydJq0Eve1BJ1503arc',
    appId: '1:690827139986:ios:5a9b736b4fe6323cf23ea3',
    messagingSenderId: '690827139986',
    projectId: 'bingo-be44c',
    storageBucket: 'bingo-be44c.firebasestorage.app',
    iosBundleId: 'com.example.bingoMk',
  );
}
