import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

// ignore_for_file: lines_longer_than_80_chars
// Replace the values below with your own from the Firebase console.
// Run `flutterfire configure` to regenerate this file automatically.

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return _unsupported('web');

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return _unsupported('iOS');
      default:
        return _unsupported(defaultTargetPlatform.name);
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: '<YOUR_ANDROID_API_KEY>',
    appId: '<YOUR_ANDROID_APP_ID>',
    messagingSenderId: '<YOUR_MESSAGING_SENDER_ID>',
    projectId: '<YOUR_PROJECT_ID>',
    storageBucket: '<YOUR_STORAGE_BUCKET>',
  );

  static Never _unsupported(String platform) {
    throw UnsupportedError(
      'Firebase is configured for Android only. Run flutterfire configure '
      'before launching on $platform.',
    );
  }
}
