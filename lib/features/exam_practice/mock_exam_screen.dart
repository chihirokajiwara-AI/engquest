// lib/features/exam_practice/mock_exam_screen.dart
// A-KEN Quest — Playable timed フル模試 (full mock 一次 exam).
//
// This is the screen behind 「フル模試を開始 / Start Full Mock」 in the exam hub.
// It runs the REAL mock engine end-to-end:
//   1. MockExamAssembler.assemble(grade) → a mock in official 大問 proportions,
//      drawn from existing reading/listening/writing pools.
//   2. Present every MCQ item one at a time under an official-duration countdown
//      (kEikenExams[grade].totalMinutes). Listening items get a 🔊 replay button.
//   3. On finish (or timeout) → MockExamScorer.score → CseEstimate, record the
//      per-skill result into SkillAccuracyStore (so the live 合格メーター reflects
//      it too) → navigate to PassMeterScreen with the REAL estimate.
//
// Writing is not administered inside the mock (it requires AI grading via the
// not-yet-deployed backend). Instead the mock injects the learner's ACCUMULATED
// writing-practice accuracy (from SkillAccuracyStore) as the writing component
// of the CSE — non-zero for learners who have practiced writing, honestly 0 for
// those who have not. (Previously writing was hard-0 in every mock.)
//
// NO dart:io. No Firebase in build/init. AudioCueService is created lazily and
// play() is only called from user-gesture handlers (web autoplay contract). R4.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/audio/audio_cue_service.dart';
import '../../core/audio/audio_mute.dart';
import '../quest/ui/dq_ui.dart';
import 'eiken_exam_config.dart';
import '../quest/ui/muted_voice_banner.dart';
import 'pass/cse_model.dart';
import 'listening_data.dart';
import 'pass/mock_exam.dart';
import 'pass/mock_review_screen.dart';
import 'pass/pass_meter_screen.dart';
import 'pass/skill_accuracy_store.dart';
import '../home/streak_service.dart';
import '../../core/gamification/xp_service.dart';
import '../../core/sound/practice_feedback.dart';
import 'exam_session_rewards.dart';

class MockExamScreen extends StatefulWidget {
  final String eikenGrade;

  /// Fixed seed for reproducible mocks (tests/preview). Null = random draw.
  final int? seed;

  const MockExamScreen({super.key, required this.eikenGrade, this.seed});

  @override
  State<MockExamScreen> createState() => _MockExamScreenState();
}

class _MockExamScreenState extends State<MockExamScreen> {
  late final MockExam _exam;
  late final List<MockMcqItem> _items;
  final Map<String, int> _answers = {};

  // Deaf/HoH accessibility (#125 parity): captions let a child READ the listening
  // transcript instead of hearing it. [_captionsUsed] is sticky — if captions are
  // ever turned on, listening is honestly excluded from the 合格率 (read ≠ heard),
  // mirroring the live listening screen. [_captionsOn] is the current toggle.
  bool _captionsOn = false;
  bool _captionsUsed = false;

  int _index = 0;
  int? _selected;
  late int _secondsLeft;
  Timer? _timer;
  AudioCueService? _cue;
  bool _submitting = false;
  // Set true only once the child has confirmed leaving a half-finished mock, so
  // PopScope lets the pop through. Until then an in-progress mock (≥1 answer) is
  // guarded — navigating away would silently discard the whole timed session,
  // since results only persist at submit (#129). ADHD/interrupted-child lens.
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _exam = MockExamAssembler.assemble(widget.eikenGrade, seed: widget.seed);
    _items = _exam.mcqItems;
    final minutes = kEikenExams[widget.eikenGrade]?.totalMinutes ?? 30;
    _secondsLeft = minutes * 60;
    if (_items.isNotEmpty) _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        setState(() => _secondsLeft = 0);
        _submit(); // time up → auto-score
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  MockMcqItem get _current => _items[_index];
  bool get _isLast => _index >= _items.length - 1;

  void _playCurrentAudio() {
    if (_current.skill != EikenSkill.listening) return;
    (_cue ??= AudioCueService()).play('audio/listening/${_current.id}');
  }

  void _select(int i) => setState(() => _selected = i);

  void _advance() {
    if (_selected != null) _answers[_current.id] = _selected!;
    if (_isLast) {
      _submit();
      return;
    }
    setState(() {
      _index++;
      _selected = _answers[_current.id];
    });
    // Auto-play the next listening clip after the frame settles.
    if (_current.skill == EikenSkill.listening) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _playCurrentAudio());
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    _submitting = true;
    _timer?.cancel();
    // Capture the current selection if not yet stored.
    if (_selected != null) _answers.putIfAbsent(_current.id, () => _selected!);

    // Per-skill tally → persist into the live store so the 合格メーター updates.
    final correct = <EikenSkill, int>{};
    final total = <EikenSkill, int>{};
    for (final item in _items) {
      total[item.skill] = (total[item.skill] ?? 0) + 1;
      if (_answers[item.id] == item.correctIdx) {
        correct[item.skill] = (correct[item.skill] ?? 0) + 1;
      }
    }
    // A completed 模試 is a big study session — feed the home streak + daily-goal.
    recordExamHabit(_items.length);
    recordExamXp(_items.length);
    recordExamAchievements();
    // The mock has no writing UI, and live AI essay grading needs the (not-yet-
    // deployed) backend — so the writing component of the mock's CSE uses the
    // learner's ACCUMULATED writing-practice accuracy (from WritingPracticeScreen,
    // which records into the same store). Without this the mock counted writing
    // as 0% for every 3級+ grade and understated 合格率 by a full skill.
    double writingAccuracy = 0.0;
    int writingAttempted = 0;
    try {
      final store = await SkillAccuracyStore.getInstance();
      for (final skill in total.keys) {
        await store.record(
          grade: widget.eikenGrade,
          skill: skill,
          correct: correct[skill] ?? 0,
          total: total[skill]!,
        );
      }
      // readAccuracies always returns all three skills (writing included).
      final writing = store
          .readAccuracies(widget.eikenGrade)
          .firstWhere((a) => a.skill == EikenSkill.writing);
      writingAccuracy = writing.accuracy;
      // 0 when writing was never practiced → the scorer marks it 未測定 (not a
      // measured 0%), so the mock's 合格率 is provisional, not falsely low.
      writingAttempted = writing.itemsAttempted;
    } catch (_) {
      // Storage failure is non-fatal — the estimate below still renders.
    }

    final estimate = MockExamScorer.score(
      exam: _exam,
      answers: _answers,
      writingAccuracy: writingAccuracy,
      writingAttempted: writingAttempted,
      listeningCaptioned: _captionsUsed,
    );
    if (!mounted) return;
    if (estimate == null) {
      Navigator.of(context).pop();
      return;
    }
    // A finished 模試 is a milestone — mark it with the same completion fanfare
    // the individual sections already play (the flagship full mock previously
    // ended silently). Exam realism is preserved: there is still NO per-question
    // correct/wrong chime during the mock, only this end-of-exam flourish.
    PracticeFeedback.sessionComplete();
    // Capture items + answers for the post-mock 答え合わせ (review). Copied by
    // value so they survive this screen's disposal under pushReplacement.
    final reviewItems = List<MockMcqItem>.from(_items);
    final reviewAnswers = Map<String, int>.from(_answers);
    final reviewLabel = gradeLabelJa(widget.eikenGrade);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PassMeterScreen(
          estimate: estimate,
          onReviewBuilder: reviewItems.isEmpty
              ? null
              : (_) => MockReviewScreen(
                    items: reviewItems,
                    answers: reviewAnswers,
                    gradeLabel: reviewLabel,
                  ),
        ),
      ),
    );
  }

  String _clock(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  /// Confirm before abandoning a half-finished timed mock (#129). Returns true
  /// if the child chose to leave.
  Future<bool> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dqNight1,
        title: Text('もどりますか？', style: TextStyle(color: dqInk)),
        content: Text(
          'いま とちゅうの 模試（もし）は きえてしまいます。\n'
          'とちゅうの こたえは ほぞんされません。',
          style: TextStyle(color: dqInk, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('つづける', style: TextStyle(color: dqGold)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('やめて もどる',
                style: TextStyle(color: Color(0xFFE89090))),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final label = gradeLabelJa(widget.eikenGrade);

    // No drawable items (a grade whose pools are empty) — be honest, don't fake.
    if (_items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('$label フル模試')),
        body: const DqScene(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'この級（きゅう）の模試（もし）は じゅんびちゅうです。\n'
                'まずは 各（かく）セクションのれんしゅうから はじめましょう。',
                textAlign: TextAlign.center,
                style: TextStyle(color: dqInk, fontSize: 16, height: 1.6),
              ),
            ),
          ),
        ),
      );
    }

    final item = _current;
    final isListening = item.skill == EikenSkill.listening;
    final progress = (_index + 1) / _items.length;
    final low = _secondsLeft <= 60;

    return PopScope(
      // Guard a half-finished timed mock: ≥1 answer means leaving would discard
      // the whole session (results persist only at submit), so confirm first.
      // No answers yet → nothing to lose, leave freely. (#129)
      canPop: _leaving || _answers.isEmpty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _leaving) return;
        final navigator = Navigator.of(context);
        final leave = await _confirmLeave();
        if (leave && mounted) {
          setState(() => _leaving = true);
          navigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('$label フル模試'),
          actions: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Non-colour urgency cue (#127, WCAG 1.4.1): a colour-blind
                    // child can't see the red shift, so a warning icon appears
                    // when time is low — the SHAPE signals "hurry", not the hue.
                    if (low)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Icons.warning_amber_rounded,
                            color: Colors.redAccent,
                            size: 20,
                            semanticLabel: 'のこり時間 わずか'),
                      ),
                    Text(
                      '⏱ ${_clock(_secondsLeft)}',
                      style: TextStyle(
                        color: low ? Colors.redAccent : dqGold,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: DqScene(
          contentMaxWidth: 600, // #144: centre on tablet, full-width on phone
          child: SafeArea(
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: dqBox,
                  color: dqGold,
                  minHeight: 4,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  // #114/WCAG SC 1.4.4: Flexible so the progress + section label
                  // share width and shrink (not clip ~68px) at large text scales.
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          '${_index + 1} / ${_items.length}',
                          style: const TextStyle(color: dqInk, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          isListening ? '🎧 リスニング' : '📖 リーディング',
                          style: const TextStyle(color: dqInk, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    children: [
                      // A muted Voice channel makes the listening items silent →
                      // false wrong answers → understated 合格率. Warn + one-tap
                      // unmute, same affordance as the listening-practice screen.
                      if (isListening && AudioMute.voiceMuted)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child:
                              MutedVoiceBanner(onUnmute: () => setState(() {})),
                        ),
                      if (isListening) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: DqReplayButton(onTap: _playCurrentAudio),
                        ),
                        // Deaf/HoH accessibility (#125 parity): read the script
                        // instead of hearing it. Using captions honestly excludes
                        // listening from the 合格率 (read ≠ heard) — see _submit.
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => setState(() {
                              _captionsOn = !_captionsOn;
                              if (_captionsOn) _captionsUsed = true;
                            }),
                            icon: Icon(
                              _captionsOn
                                  ? Icons.subtitles_rounded
                                  : Icons.subtitles_outlined,
                              color: dqGold,
                              size: 20,
                            ),
                            label: Text(
                              _captionsOn ? '字幕（じまく）を かくす' : '字幕（じまく）を よむ',
                              style: dqText(size: 13, color: dqGold),
                            ),
                          ),
                        ),
                        if (_captionsOn &&
                            transcriptForAudioKey(item.id) != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: dqNight1,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                transcriptForAudioKey(item.id)!,
                                style: dqText(size: 14).copyWith(height: 1.45),
                              ),
                            ),
                          ),
                      ],
                      DqDialogBox(child: Text(item.questionText)),
                      const SizedBox(height: 14),
                      ...List.generate(item.choices.length, (i) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: DqChoice(
                            // No per-item correctness feedback in a timed mock —
                            // selection is marked only by the cursor (▶), never
                            // by a correct/wrong colour.
                            label: item.choices[i],
                            state: DqChoiceState.normal,
                            showCursor: _selected == i,
                            onTap: () => _select(i),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: DqButton(
                    label: _isLast ? '採点（さいてん）する  /  Score' : 'つぎへ  /  Next',
                    onTap: _selected == null ? null : _advance,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
