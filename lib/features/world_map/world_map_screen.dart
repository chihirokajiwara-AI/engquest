import 'package:flutter/material.dart';
import 'package:engquest/features/parent_dashboard/parent_dashboard_screen.dart';

/// ENG Quest A1 World Map — Village Square
/// Four zones: Blacksmith (Battle), Town Crier (Dialog), Echo Cave (Voice),
/// Scholar's Tower (Parent Dashboard)
class WorldMapScreen extends StatelessWidget {
  const WorldMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          '🏰 Village Square',
          style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Where will you go?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 40),
              _ZoneCard(
                emoji: '⚔️',
                title: 'Blacksmith',
                subtitle: 'Battle — Practice your words',
                color: const Color(0xFFB71C1C),
                onTap: () => Navigator.pushNamed(context, '/battle'),
              ),
              const SizedBox(height: 16),
              _ZoneCard(
                emoji: '💬',
                title: 'Town Crier',
                subtitle: 'Dialog — Talk with NPCs',
                color: const Color(0xFF1565C0),
                onTap: () => Navigator.pushNamed(context, '/dialog'),
              ),
              const SizedBox(height: 16),
              _ZoneCard(
                emoji: '🗣️',
                title: 'Echo Cave',
                subtitle: 'Voice — Speak and be heard',
                color: const Color(0xFF4A148C),
                onTap: () => Navigator.pushNamed(context, '/voice'),
              ),
              const SizedBox(height: 16),
              _ZoneCard(
                emoji: '📊',
                title: "Scholar's Tower",
                subtitle: 'Parent Dashboard — Track progress',
                color: const Color(0xFF004D40),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ParentDashboardScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZoneCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ZoneCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.85),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 36)),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 18),
          ],
        ),
      ),
    );
  }
}
