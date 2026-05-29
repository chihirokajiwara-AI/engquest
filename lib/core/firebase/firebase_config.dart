import 'package:firebase_core/firebase_core.dart';

// Firebase project configuration for ENG Quest
// Replace with actual Firebase project values from Firebase Console
// Project: engquest-mvp (to be created)
const FirebaseOptions kFirebaseOptions = FirebaseOptions(
  apiKey: 'REPLACE_WITH_ACTUAL_API_KEY',
  appId: 'REPLACE_WITH_ACTUAL_APP_ID',
  messagingSenderId: 'REPLACE_WITH_SENDER_ID',
  projectId: 'engquest-mvp',
  storageBucket: 'engquest-mvp.appspot.com',
);

class FirebaseConfig {
  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: kFirebaseOptions,
    );
  }
}
