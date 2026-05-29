import 'package:flutter/material.dart';
import 'package:engquest/features/world_map/world_map_screen.dart';
import 'package:engquest/features/battle/battle_screen.dart';
import 'package:engquest/features/voice/voice_screen.dart';
import 'package:engquest/features/dialog/dialog_screen.dart';

class EngQuestApp extends StatelessWidget {
  const EngQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ENG Quest',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32), // RPG forest green
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const WorldMapScreen(),
        '/battle': (context) => const BattleScreen(),
        '/voice': (context) => const VoiceScreen(),
        '/dialog': (context) => const DialogScreen(),
      },
    );
  }
}
