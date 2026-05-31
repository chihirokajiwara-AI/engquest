// lib/features/battle/grade_selector_screen.dart
// ENG Quest / A-KEN Quest — Eiken Grade Selector
//
// Users select which 英検 grade they want to study for.
// Free tier (Grade 5) always accessible; other grades gated in aken flavor.

import 'package:flutter/material.dart';
import '../../core/config/flavor_config.dart';
import '../paywall/grade_gate_screen.dart';
import 'battle_screen.dart';

class _GradeInfo {
  final String grade;
  final String label;
  final String cefrLabel;
  final String description;
  final IconData icon;
  final Color color;
  final bool hasContent;

  const _GradeInfo({
    required this.grade,
    required this.label,
    required this.cefrLabel,
    required this.description,
    required this.icon,
    required this.color,
    this.hasContent = true,
  });
}

const _grades = [
  _GradeInfo(
    grade: '5',
    label: '英検5級',
    cefrLabel: 'A1',
    description: '小学生レベル・600語',
    icon: Icons.star_outline,
    color: Color(0xFF4CAF50),
  ),
  _GradeInfo(
    grade: '4',
    label: '英検4級',
    cefrLabel: 'A1-A2',
    description: '中1レベル・700語',
    icon: Icons.star_half,
    color: Color(0xFF2196F3),
  ),
  _GradeInfo(
    grade: '3',
    label: '英検3級',
    cefrLabel: 'A2',
    description: '中学卒業レベル・1,300語',
    icon: Icons.star,
    color: Color(0xFF9C27B0),
  ),
  _GradeInfo(
    grade: 'pre2',
    label: '英検準2級',
    cefrLabel: 'B1',
    description: '高校中級レベル・1,500語',
    icon: Icons.shield_outlined,
    color: Color(0xFFFF9800),
  ),
  _GradeInfo(
    grade: '2',
    label: '英検2級',
    cefrLabel: 'B1-B2',
    description: '高校卒業レベル・800語',
    icon: Icons.shield,
    color: Color(0xFFF44336),
  ),
  _GradeInfo(
    grade: 'pre1',
    label: '英検準1級',
    cefrLabel: 'B2',
    description: '大学中級レベル・3,000語',
    icon: Icons.military_tech,
    color: Color(0xFFFFD700),
    hasContent: false, // not yet generated
  ),
];

class GradeSelectorScreen extends StatelessWidget {
  const GradeSelectorScreen({super.key, this.childAge = 8});

  final int childAge;

  @override
  Widget build(BuildContext context) {
    final flavor = FlavorConfig.instance;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4FC3F7), Color(0xFF29B6F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '⚔️ 級を選ぶ',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _grades.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final g = _grades[i];
            final isFree = flavor.isGradeFree(g.grade);
            final isLocked = !isFree && flavor.paymentRequired;

            return _GradeCard(
              info: g,
              isLocked: isLocked,
              onTap: () {
                if (!g.hasContent) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${g.label}のコンテンツは準備中です'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  return;
                }

                if (isLocked) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GradeGateScreen(
                        eikenGrade: g.grade,
                        onSubscribe: () {
                          // TODO: Stripe checkout
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BattleScreen(
                        childAge: childAge,
                        eikenGrade: g.grade,
                      ),
                    ),
                  );
                }
              },
            );
          },
        ),
      ),
    );
  }
}

class _GradeCard extends StatelessWidget {
  const _GradeCard({
    required this.info,
    required this.isLocked,
    required this.onTap,
  });

  final _GradeInfo info;
  final bool isLocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final opacity = info.hasContent ? 1.0 : 0.5;

    return Opacity(
      opacity: opacity,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        shadowColor: info.color.withAlpha(40),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: info.color.withAlpha(60)),
            ),
            child: Row(
              children: [
                // Grade icon
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: info.color.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(info.icon, color: info.color, size: 28),
                ),
                const SizedBox(width: 16),
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            info.label,
                            style: const TextStyle(
                              color: Color(0xFF263238),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: info.color.withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              info.cefrLabel,
                              style: TextStyle(
                                color: info.color,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        info.description,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // Lock or arrow
                if (isLocked)
                  const Icon(Icons.lock, color: Colors.grey, size: 22)
                else if (!info.hasContent)
                  const Icon(Icons.hourglass_empty, color: Colors.grey, size: 22)
                else
                  Icon(Icons.arrow_forward_ios,
                      color: info.color.withAlpha(150), size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
