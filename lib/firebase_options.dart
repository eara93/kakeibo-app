import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

// Firebase設定ファイル
// Firebase CLIで再生成: flutterfire configure
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        throw UnsupportedError('Android用のFirebase設定が必要です。flutterfire configureを実行してください。');
      case TargetPlatform.iOS:
        throw UnsupportedError('iOS用のFirebase設定が必要です。flutterfire configureを実行してください。');
      case TargetPlatform.macOS:
        throw UnsupportedError('macOS用のFirebase設定が必要です。flutterfire configureを実行してください。');
      case TargetPlatform.windows:
        throw UnsupportedError('Windows用のFirebase設定が必要です。flutterfire configureを実行してください。');
      case TargetPlatform.linux:
        throw UnsupportedError('Linux用のFirebase設定が必要です。flutterfire configureを実行してください。');
      default:
        throw UnsupportedError('このプラットフォームはサポートされていません。');
    }
  }

  // TODO: Firebaseプロジェクト作成後に実際の値を設定

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDPyNmNz272h8aplHPVLANAG92Ir6Nwz-E',
    appId: '1:411849937179:web:b1d2e4807197c978d183be',
    messagingSenderId: '411849937179',
    projectId: 'kakeibo-1f1d8',
    authDomain: 'kakeibo-1f1d8.firebaseapp.com',
    storageBucket: 'kakeibo-1f1d8.firebasestorage.app',
    measurementId: 'G-VHH8NY9BTM',
  );
}
