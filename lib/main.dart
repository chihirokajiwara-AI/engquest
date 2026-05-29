import 'package:flutter/material.dart';
import 'package:engquest/core/firebase/firebase_config.dart';
import 'package:engquest/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase initialization — skipped in offline/dev mode if config not set
  try {
    await FirebaseConfig.initialize();
  } catch (e) {
    debugPrint('[Firebase] Init skipped: $e');
  }
  runApp(const EngQuestApp());
}
