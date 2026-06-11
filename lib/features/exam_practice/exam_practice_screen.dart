// lib/features/exam_practice/exam_practice_screen.dart
// A-KEN Quest — Exam Practice Mode (模擬試験 / Mock Exam)
//
// Lets the user select which section of the Eiken exam to practice.
// Restyled to the 本格 Dragon-Quest scene framework (dq_ui): dark atmospheric
// field, navy+cream command windows, ▶cursor tiles, gold serif headings.
// Behaviour, navigation, and eikenGrade handling are preserved exactly.
//
// LIVE 合格メーター:
//   The 「合格率をみる」 button reads SkillAccuracyStore.readAccuracies(grade),
//   runs CseEstimator.estimate(), and navigates to PassMeterScreen with the REAL
//   estimate — not the hardcoded _kDemoEstimate. When the learner has no data
//   yet (hasAnyData == false) an explanatory message is shown instead.
//
//   The ?preview=passmeter route (app.dart, design audit) still uses the const
//   PassMeterScreen() constructor which falls back to _kDemoEstimate — that path
//   is explicitly for design preview only and is clearly commented there.

import 'package:flutter/material.dart';

import '../quest/ui/dq_ui.dart';
import 'conversation_practice_screen.dart';
import 'eiken_exam_config.dart';
import 'mock_exam_screen.dart';
import 'listening_practice_screen.dart';
import 'pass/cse_model.dart';
import 'pass/pass_meter_screen.dart';
import 'pass/skill_accuracy_store.dart';
import 'reading_practice_screen.dart';
import 'vocab_grammar_practice_screen.dart';
import 'word_ordering_practice_screen.dart';
import 'writing_practice_screen.dart';
import '../speaking/speaking_consent_notice.dart';
import '../speaking/speaking_screen.dart';

class ExamPracticeScreen extends StatefulWidget {
  const ExamPracticeScreen({
    super.key,
    required this.eikenGrade,
  });

  final String eikenGrade;

  @override
  State<ExamPracticeScreen> createState() => _ExamPracticeScreenState();
}

class _ExamPracticeScreenState extends State<ExamPracticeScreen> {
  @override
  Widget build(BuildContext context) {
    final exam = kEikenExams[widget.eikenGrade];
    if (exam == null) {
      return DqScene(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _DqHeader(
                title: dqBilingual('模擬試験', 'Mock Exam', jpSize: 20),
                onBack: () => Navigator.of(context).pop(),
              ),
              const Spacer(),
              DqPanel(
                child: Center(
                  child: Text(
                    '未対応のレベル: ${widget.eikenGrade}',
                    style: dqText(size: 16, color: dqInk),
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      );
    }

    return DqScene(
      contentMaxWidth:
          600, // #144: centre the column on tablet, full-width on phone
      child: Column(
        children: [
          // Dark DQ header replaces the bright app bar.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: _DqHeader(
              title:
                  dqBilingual('${exam.labelJa} 模擬試験', 'Mock Exam', jpSize: 19),
              onBack: () => Navigator.of(context).pop(),
            ),
          ),
          // Below the pinned header, the exam-info panel + section tiles + footer
          // buttons all scroll together in one list so nothing overflows on a
          // short (phone-landscape) viewport (#144); on a tall screen the content
          // simply sits at the top with the dark scene below.
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              children: [
                // Exam info panel (試験時間 / 合格ライン / CEFR).
                DqPanel(
                  title: '試験概要（しけんがいよう） / Exam Overview',
                  // #114/WCAG SC 1.4.4: Wrap (not Row) so the three chips reflow
                  // onto extra lines at 2.0x text instead of clipping ~88px.
                  child: Wrap(
                    alignment: WrapAlignment.spaceAround,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      _DqInfoChip(
                        icon: Icons.timer_outlined,
                        label: '${exam.totalMinutes}分',
                        jp: '試験時間',
                        en: 'Time',
                      ),
                      _DqInfoChip(
                        icon: Icons.check_circle_outline,
                        label: '${exam.passingScore}',
                        jp: '合格ライン',
                        en: 'Pass',
                      ),
                      _DqInfoChip(
                        icon: Icons.stars_outlined,
                        label: exam.cefrLevel,
                        jp: 'CEFRレベル',
                        en: 'CEFR',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Section list — each part as a DQ command tile.
                for (final section in exam.sections)
                  _SectionTile(
                    section: section,
                    onTap: () => _navigateToSection(context, section),
                  ),
                const SizedBox(height: 8),
                // ── 合格メーター (LIVE — reads real SkillAccuracyStore data) ──
                // Sources REAL practice results; the const PassMeterScreen() demo
                // path is used ONLY by the ?preview=passmeter route in app.dart.
                DqButton(
                  label: '合格率をみる  /  Check Pass Meter',
                  onTap: () => _openLivePassMeter(context),
                ),
                const SizedBox(height: 8),
                DqButton(
                  label: 'フル模試を開始  /  Start Full Mock',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          MockExamScreen(eikenGrade: widget.eikenGrade),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Opens PassMeterScreen with the learner's REAL accumulated accuracy data.
  ///
  /// Flow:
  ///   1. Load SkillAccuracyStore (SharedPreferences-backed, instant if already
  ///      initialised by a practice session).
  ///   2. readAccuracies(grade) → `List<SkillAccuracy>`.
  ///   3. CseEstimator.estimate() → CseEstimate.
  ///   4. Navigate to PassMeterScreen(estimate: real) — NOT the demo profile.
  ///
  /// If the learner has no practice data yet, show an encouraging snackbar
  /// prompting them to complete at least one section first.
  Future<void> _openLivePassMeter(BuildContext context) async {
    final grade = widget.eikenGrade;
    try {
      final store = await SkillAccuracyStore.getInstance();
      if (!store.hasAnyData(grade)) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'まずれんしゅうをしてみましょう！\n'
              '合格メーターはれんしゅう後にひょうじされます。',
            ),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
      final accuracies = store.readAccuracies(grade);
      final estimate = CseEstimator.estimate(
        grade: grade,
        accuracies: accuracies,
      );
      if (!context.mounted) return;
      if (estimate == null) {
        // Grade not in spec table (should not happen for supported grades).
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('このグレードは未対応です: $grade')),
        );
        return;
      }
      // LIVE path: real estimate injected. NOT the demo fallback.
      // Awaits the screen: if the child taps "practise <weak skill>", the meter
      // pops the limiting EikenSkill and we route straight into a section that
      // trains it — closing the diagnose→practice loop (#68).
      final weakSkill = await Navigator.push<EikenSkill?>(
        context,
        MaterialPageRoute(
          builder: (_) => PassMeterScreen(estimate: estimate),
        ),
      );
      if (weakSkill == null || !context.mounted) return;
      final exam = kEikenExams[grade];
      if (exam == null) return;
      for (final section in exam.sections) {
        if (_skillForSectionType(section.type) == weakSkill) {
          _navigateToSection(context, section);
          return;
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('合格メーターの読み込みに失敗しました')),
      );
    }
  }

  /// Which 合格率 skill a section trains. Reading 大問 (vocab/会話/並びかえ/長文) all
  /// feed reading; listening and writing map 1:1. Used to route the PassMeter's
  /// weak-skill CTA into a matching section (#68).
  static EikenSkill _skillForSectionType(ExamSectionType t) {
    switch (t) {
      case ExamSectionType.listening:
        return EikenSkill.listening;
      case ExamSectionType.writing:
        return EikenSkill.writing;
      case ExamSectionType.vocabGrammar:
      case ExamSectionType.conversationComplete:
      case ExamSectionType.readingComprehension:
      case ExamSectionType.wordOrdering:
      // speaking is 二次 (not in the 一次 合格率 R/W/L) — it never appears in the
      // section list nor as a limiting skill, so reading is a harmless fallback.
      case ExamSectionType.speaking:
        return EikenSkill.reading;
    }
  }

  void _navigateToSection(BuildContext context, ExamSection section) {
    switch (section.type) {
      case ExamSectionType.vocabGrammar:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VocabGrammarPracticeScreen(
              eikenGrade: widget.eikenGrade,
              section: section,
            ),
          ),
        );
      case ExamSectionType.wordOrdering:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WordOrderingPracticeScreen(
              eikenGrade: widget.eikenGrade,
              section: section,
            ),
          ),
        );
      case ExamSectionType.conversationComplete:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConversationPracticeScreen(
              eikenGrade: widget.eikenGrade,
              section: section,
            ),
          ),
        );
      case ExamSectionType.readingComprehension:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReadingPracticeScreen(
              eikenGrade: widget.eikenGrade,
              section: section,
            ),
          ),
        );
      case ExamSectionType.writing:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WritingPracticeScreen(
              eikenGrade: widget.eikenGrade,
              section: section,
            ),
          ),
        );
      case ExamSectionType.listening:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ListeningPracticeScreen(
              eikenGrade: widget.eikenGrade,
              section: section,
            ),
          ),
        );
      case ExamSectionType.speaking:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SpeakingConsentNotice(
              eikenGrade: widget.eikenGrade,
              onConsent: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => SpeakingScreen(eikenGrade: widget.eikenGrade),
                ),
              ),
            ),
          ),
        );
    }
  }
}

/// Dark DQ header: cream back arrow + gold serif bilingual title.
class _DqHeader extends StatelessWidget {
  const _DqHeader({required this.title, required this.onBack});

  final Widget title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onBack,
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: dqBox.withAlpha(220),
              shape: BoxShape.circle,
              border: Border.all(color: dqBorder, width: 1.5),
            ),
            child: const Icon(Icons.arrow_back, color: dqInk, size: 20),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: title),
      ],
    );
  }
}

/// A single info stat inside the overview panel (gold icon + value + bilingual
/// caption).
class _DqInfoChip extends StatelessWidget {
  const _DqInfoChip({
    required this.icon,
    required this.label,
    required this.jp,
    required this.en,
  });

  final IconData icon;
  final String label;
  final String jp;
  final String en;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: dqGold, size: 24),
        const SizedBox(height: 5),
        Text(label, style: dqText(size: 18, w: FontWeight.w800, color: dqInk)),
        const SizedBox(height: 2),
        dqBilingual(jp, en,
            jpSize: 11, jpColor: dqInk, align: TextAlign.center, stacked: true),
      ],
    );
  }
}

/// An exam section rendered as a DQ command tile: gold-framed navy row, leading
/// icon medallion, bilingual section name, question/time meta, and a ▶ cursor.
class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.section,
    required this.onTap,
  });

  final ExamSection section;
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [dqBox.withAlpha(235), dqNight1.withAlpha(235)],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: dqBorder, width: 2),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black54, blurRadius: 8, offset: Offset(0, 3)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dqNight0,
                  border: Border.all(color: dqGold, width: 2),
                  boxShadow: [
                    BoxShadow(color: dqGold.withAlpha(70), blurRadius: 8)
                  ],
                ),
                child: Icon(_sectionIcon, color: dqGold, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    dqBilingual(section.nameJa, section.nameEn,
                        jpSize: 14, stacked: true),
                    const SizedBox(height: 4),
                    Text(
                      '${section.questionCount}問 • ${section.timeLimitMinutes}分',
                      style: dqText(
                          size: 12,
                          w: FontWeight.w600,
                          color: dqGoldDeep,
                          spacing: 0.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.play_arrow, color: dqGold, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
