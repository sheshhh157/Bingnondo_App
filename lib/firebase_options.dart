import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static const String _apiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'AIzaSyDRmWMkmXG0R_gHnsSB_P1PYZYNXr-2rZ4',
  );
  static const String _projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'push-notifications-ce109',
  );
  static const String _messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '257873602297',
  );
  static const String _androidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
    defaultValue: '1:257873602297:android:77e2f03fc37f09e0562428',
  );
  static const String _iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const String _iosBundleId = String.fromEnvironment(
    'FIREBASE_IOS_BUNDLE_ID',
  );

  static bool get isConfigured =>
      _apiKey.isNotEmpty &&
      _projectId.isNotEmpty &&
      _messagingSenderId.isNotEmpty &&
      (defaultTargetPlatform == TargetPlatform.android
          ? _androidAppId.isNotEmpty
          : defaultTargetPlatform == TargetPlatform.iOS &&
                _iosAppId.isNotEmpty &&
                _iosBundleId.isNotEmpty);

  static FirebaseOptions get currentPlatform {
    if (!isConfigured) {
      throw StateError(
        'Firebase options are not configured for this platform.',
      );
    }

    return FirebaseOptions(
      apiKey: _apiKey,
      appId: defaultTargetPlatform == TargetPlatform.android
          ? _androidAppId
          : _iosAppId,
      messagingSenderId: _messagingSenderId,
      projectId: _projectId,
      iosBundleId: defaultTargetPlatform == TargetPlatform.iOS
          ? _iosBundleId
          : null,
    );
  }
}
