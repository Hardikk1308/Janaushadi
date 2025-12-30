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
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDEaO7wnCofjmF8z-ts7t_RgO7kB8nQxQE',
    appId: '1:405088781146:web:8f4cc511b8b0e0b0b0b0b0',
    messagingSenderId: '405088781146',
    projectId: 'jan-aushadi-8f4cc',
    authDomain: 'jan-aushadi-8f4cc.firebaseapp.com',
    databaseURL: 'https://jan-aushadi-8f4cc.firebaseio.com',
    storageBucket: 'jan-aushadi-8f4cc.appspot.com',
    measurementId: 'G-XXXXXXXXXX',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDEaO7wnCofjmF8z-ts7t_RgO7kB8nQxQE',
    appId: '1:405088781146:android:8f4cc511b8b0e0b0b0b0b0',
    messagingSenderId: '405088781146',
    projectId: 'jan-aushadi-8f4cc',
    databaseURL: 'https://jan-aushadi-8f4cc.firebaseio.com',
    storageBucket: 'jan-aushadi-8f4cc.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDEaO7wnCofjmF8z-ts7t_RgO7kB8nQxQE',
    appId: '1:405088781146:ios:8f4cc511b8b0e0b0b0b0b0',
    messagingSenderId: '405088781146',
    projectId: 'jan-aushadi-8f4cc',
    databaseURL: 'https://jan-aushadi-8f4cc.firebaseio.com',
    storageBucket: 'jan-aushadi-8f4cc.appspot.com',
    iosBundleId: 'com.example.janAushadi',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDEaO7wnCofjmF8z-ts7t_RgO7kB8nQxQE',
    appId: '1:405088781146:macos:8f4cc511b8b0e0b0b0b0b0',
    messagingSenderId: '405088781146',
    projectId: 'jan-aushadi-8f4cc',
    databaseURL: 'https://jan-aushadi-8f4cc.firebaseio.com',
    storageBucket: 'jan-aushadi-8f4cc.appspot.com',
    iosBundleId: 'com.example.janAushadi',
  );
}
