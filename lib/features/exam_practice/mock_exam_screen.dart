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
import '../quest/ui/dq_ui.dart';
import 'eiken_exam_config.dart';
import 'pass/cse_model.dart';
import 'pass/mock_exam.dart';
import 'pass/pass_meter_screen.dart';
import 'pass/skill_accuracy_store.dart';

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

  int _index = 0;
  int? _selected;
  late int _secondsLeft;
  Timer? _timer;
  AudioCueService? _cue;
  bool _submitting = false;

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
    );
    if (!mounted) return;
    if (estimate == null) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => PassMeterScreen(estimate: estimate)),
    );
  }

  String _clock(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final label = kEikenExams[widget.eikenGrade]?.labelJa ?? widget.eikenGrade;

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

    return Scaffold(
      appBar: AppBar(
        title: Text('$label フル模試'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Text(
                '⏱ ${_clock(_secondsLeft)}',
                style: TextStyle(
                  color: low ? Colors.redAccent : dqGold,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      ),
      body: DqScene(
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_index + 1} / ${_items.length}',
                      style: const TextStyle(color: dqInk, fontSize: 14),
                    ),
                    Text(
                      isListening ? '🎧 リスニング' : '📖 リーディング',
                      style: const TextStyle(color: dqInk, fontSize: 14),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  children: [
                    if (isListening)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DqReplayButton(onTap: _playCurrentAudio),
                      ),
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
                  label: _isLast
                      ? '採点（さいてん）する  /  Score'
                      : 'つぎへ  /  Next',
                  onTap: _selected == null ? null : _advance,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
