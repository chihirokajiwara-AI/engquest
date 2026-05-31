// lib/features/exam_practice/exam_practice_screen.dart
// A-KEN Quest — Exam Practice Mode
//
// Lets the user select which section of the Eiken exam to practice.
// Tracks progress per section with completion indicators.

import 'package:flutter/material.dart';
import 'conversation_practice_screen.dart';
import 'eiken_exam_config.dart';
import 'reading_practice_screen.dart';
import 'vocab_grammar_practice_screen.dart';
import 'word_ordering_practice_screen.dart';

class ExamPracticeScreen extends StatelessWidget {
  const ExamPracticeScreen({
    super.key,
    required this.eikenGrade,
  });

  final String eikenGrade;

  @override
  Widget build(BuildContext context) {
    final exam = kEikenExams[eikenGrade];
    if (exam == null) {
      return Scaffold(
        body: Center(child: Text('未対応のレベル: $eikenGrade')),
      );
    }

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
        title: Text(
          '📝 ${exam.labelJa} 模擬試験',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Exam info header
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _InfoChip(
                    icon: Icons.timer_outlined,
                    label: '${exam.totalMinutes}分',
                    subtitle: '試験時間',
                  ),
                  _InfoChip(
                    icon: Icons.check_circle_outline,
                    label: '${exam.passingScore}',
                    subtitle: '合格ライン',
                  ),
                  _InfoChip(
                    icon: Icons.stars_outlined,
                    label: exam.cefrLevel,
                    subtitle: 'CEFRレベル',
                  ),
                ],
              ),
            ),
            // Section list
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: exam.sections.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final section = exam.sections[i];
                  return _SectionCard(
                    section: section,
                    index: i + 1,
                    onTap: () => _navigateToSection(context, section),
                  );
                },
              ),
            ),
            // Full practice test button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Full mock test mode (all sections sequential with timer)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('フル模試モードは準備中です'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text(
                    'フル模試を開始',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7043),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToSection(BuildContext context, ExamSection section) {
    switch (section.type) {
      case ExamSectionType.vocabGrammar:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VocabGrammarPracticeScreen(
              eikenGrade: eikenGrade,
              section: section,
            ),
          ),
        );
      case ExamSectionType.wordOrdering:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WordOrderingPracticeScreen(
              eikenGrade: eikenGrade,
              section: section,
            ),
          ),
        );
      case ExamSectionType.conversationComplete:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConversationPracticeScreen(
              eikenGrade: eikenGrade,
              section: section,
            ),
          ),
        );
      case ExamSectionType.readingComprehension:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReadingPracticeScreen(
              eikenGrade: eikenGrade,
              section: section,
            ),
          ),
        );
      case ExamSectionType.listening:
      case ExamSectionType.writing:
      case ExamSectionType.speaking:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${section.nameJa}は準備中です')),
        );
    }
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.subtitle,
  });

  final IconData icon;
  final String label;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF4FC3F7), size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF263238),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          subtitle,
          style: TextStyle(color: Colors.grey[600], fontSize: 11),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.section,
    required this.index,
    required this.onTap,
  });

  final ExamSection section;
  final int index;
  final VoidCallback onTap;

  IconData get _sectionIcon {
    switch (section.type) {
      case ExamSectionType.vocabGrammar:
        return Icons.abc;
      case ExamSectionType.conversationComplete:
        return Icons.chat;
      case ExamSectionType.readingComprehension:
        return Icons.menu_book;
      case ExamSectionType.wordOrdering:
        return Icons.swap_horiz;
      case ExamSectionType.listening:
        return Icons.headphones;
      case ExamSectionType.writing:
        return Icons.edit_note;
      case ExamSectionType.speaking:
        return Icons.mic;
    }
  }

  Color get _sectionColor {
    switch (section.type) {
      case ExamSectionType.vocabGrammar:
        return const Color(0xFF4CAF50);
      case ExamSectionType.conversationComplete:
        return const Color(0xFF2196F3);
      case ExamSectionType.readingComprehension:
        return const Color(0xFF9C27B0);
      case ExamSectionType.wordOrdering:
        return const Color(0xFFFF9800);
      case ExamSectionType.listening:
        return const Color(0xFF00BCD4);
      case ExamSectionType.writing:
        return const Color(0xFFF44336);
      case ExamSectionType.speaking:
        return const Color(0xFFFFD700);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _sectionColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_sectionIcon, color: _sectionColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.nameJa,
                      style: const TextStyle(
                        color: Color(0xFF263238),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${section.questionCount}問 • ${section.timeLimitMinutes}分',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
