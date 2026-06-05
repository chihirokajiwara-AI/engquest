// lib/features/exam_practice/listening_practice_screen.dart
// A-KEN Quest — Eiken Listening Practice (リスニング練習)
//
// Implements the 英検 listening section for all grades 5–2 (seed bank).
// Structure per grade (verified spec, EIKEN-MASTERY-AND-GAPS-2026-06-06):
//   5級/4級 : 第1部 応答選択 + 第2部 会話内容一致 + 第3部 文内容一致
//   3級     : 第1部–3部 (会話/会話/文)
//   準2級/2級: 第1部 会話応答選択 + 第2部 文内容一致
//
// UX CONTRACT (web autoplay + child UX):
//   - Audio-first: 🔊 play button is primary. The question is shown BELOW the player.
//   - Child can replay any number of times before answering.
//   - No scolding on wrong answers — green check shows correct, red shows wrong, done.
//   - Uses DqScene + DqDialogBox + DqChoice (dq_ui) for the 本格 game feel.
//   - AudioCueService: fire-and-forget, errors are swallowed (missing clip = silence).
//   - R4: NO Firebase/network in build or init. AudioCueService created lazily in state.
//
// DESIGN NOTES:
//   - _cue is created once in State.initState and disposed in dispose().
//   - play() is ONLY called from user-gesture tap handlers (web autoplay contract).
//   - The 🔊 large replay button always visible above the question (CEO directive).
//   - Part header shown between parts; individual items shown one at a time.

import 'package:flutter/material.dart';

import '../../core/audio/audio_cue_service.dart';
import '../quest/ui/dq_ui.dart';
import 'eiken_exam_config.dart';
import 'listening_data.dart';

class ListeningPracticeScreen extends StatefulWidget {
  const ListeningPracticeScreen({
    super.key,
    required this.eikenGrade,
    required this.section,
  });

  final String eikenGrade;
  final ExamSection section;

  @override
  State<ListeningPracticeScreen> createState() =>
      _ListeningPracticeScreenState();
}

class _ListeningPracticeScreenState extends State<ListeningPracticeScreen> {
  late final AudioCueService _cue;
  late final List<ListeningItem> _items;

  int _currentIdx = 0;
  int? _selectedAnswer;
  bool _answered = false;
  int _correctCount = 0;
  bool _sessionDone = false;
  bool _partHeaderShown = false;

  @override
  void initState() {
    super.initState();
    _cue = AudioCueService();
    _items = kListeningItems[widget.eikenGrade] ?? [];
    _partHeaderShown = _items.isEmpty;
  }

  @override
  void dispose() {
    _cue.dispose();
    super.dispose();
  }

  ListeningItem? get _current =>
      (_items.isNotEmpty && _currentIdx < _items.length)
          ? _items[_currentIdx]
          : null;

  int get _currentPart => _current?.part ?? 1;

  /// True when we're transitioning to a new part number.
  bool get _isPartBoundary {
    if (_currentIdx == 0) return true;
    return _items[_currentIdx - 1].part != _currentPart;
  }

  void _playAudio() {
    final item = _current;
    if (item == null) return;
    _cue.play('audio/listening/${item.audioKey}');
  }

  void _selectAnswer(int idx) {
    if (_answered) return;
    final item = _current;
    if (item == null) return;
    setState(() {
      _selectedAnswer = idx;
      _answered = true;
      if (idx == item.correctIndex) _correctCount++;
    });
  }

  void _next() {
    if (_currentIdx >= _items.length - 1) {
      setState(() => _sessionDone = true);
    } else {
      setState(() {
        _currentIdx++;
        _selectedAnswer = null;
        _answered = false;
        _partHeaderShown = false;
      });
    }
  }

  void _dismissPartHeader() => setState(() => _partHeaderShown = true);

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return _buildEmpty(context);
    }
    return DqScene(
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: _sessionDone
                ? _buildResults(context)
                : (!_partHeaderShown && _isPartBoundary)
                    ? _buildPartHeader(context)
                    : _buildItem(context),
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
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
          Expanded(
            child: dqBilingual(
              'リスニング / Listening',
              widget.eikenGrade == 'pre2'
                  ? '準2級'
                  : widget.eikenGrade == 'pre1'
                      ? '準1級'
                      : '英検${widget.eikenGrade}級',
              jpSize: 17,
              stacked: false,
            ),
          ),
          if (!_sessionDone && _items.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: dqBox.withAlpha(220),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: dqBorder, width: 1.5),
              ),
              child: Text(
                '${_currentIdx + 1} / ${_items.length}',
                style: dqText(size: 13, color: dqGold),
              ),
            ),
        ],
      ),
    );
  }

  // ── Part header interstitial ───────────────────────────────────────────────

  Widget _buildPartHeader(BuildContext context) {
    final partLabels = {
      1: ('第1部', _partSubtitle(1)),
      2: ('第2部', _partSubtitle(2)),
      3: ('第3部', _partSubtitle(3)),
    };
    final (jp, sub) = partLabels[_currentPart] ?? ('リスニング', 'Listening');
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          DqDialogBox(
            speaker: jp,
            child: Column(
              children: [
                Text(
                  sub,
                  style: dqText(size: 15, color: dqInk),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  _partInstruction(_currentPart),
                  style: dqText(size: 13, color: dqGold),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          DqButton(
            label: 'はじめる / Start',
            onTap: _dismissPartHeader,
          ),
          const Spacer(),
        ],
      ),
    );
  }

  String _partSubtitle(int part) {
    final grade = widget.eikenGrade;
    if (grade == '5' || grade == '4') {
      if (part == 1) return '応答選択 / Response Selection';
      if (part == 2) return '会話内容一致 / Dialogue Content';
      return '文内容一致 / Passage Content';
    }
    if (grade == '3') {
      if (part == 1) return '会話内容一致 / Dialogue Content';
      if (part == 2) return '会話内容一致 / Dialogue Content';
      return '文内容一致 / Passage Content';
    }
    // pre2 / 2
    if (part == 1) return '会話応答選択 / Dialogue Q&A';
    return '文内容一致 / Passage Content';
  }

  String _partInstruction(int part) {
    final grade = widget.eikenGrade;
    if (grade == '5' || grade == '4') {
      if (part == 1) {
        return '音声を聞いて、最も適切な返答を選んでください。\n'
            'Listen and choose the best response.';
      }
    }
    return '音声を聞いて、質問に答えてください。\n'
        'Listen and answer the question.';
  }

  // ── Item view ─────────────────────────────────────────────────────────────

  Widget _buildItem(BuildContext context) {
    final item = _current;
    if (item == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _items.isEmpty ? 0 : (_currentIdx + 1) / _items.length,
              backgroundColor: dqNight1,
              valueColor: const AlwaysStoppedAnimation<Color>(dqGold),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 16),

          // 🔊 Large replay button — always visible (CEO directive + web autoplay)
          Center(
            child: DqReplayButton(
              label: '🔊 もう いちど きく',
              onTap: _playAudio,
            ),
          ),
          const SizedBox(height: 20),

          // Question card (shown after play or after answer)
          DqDialogBox(
            speaker: '問${_currentIdx + 1}',
            child: Text(
              item.question,
              style: dqText(size: 15, color: dqInk),
            ),
          ),
          const SizedBox(height: 16),

          // Answer choices
          ...List.generate(item.choices.length, (i) {
            DqChoiceState state = DqChoiceState.normal;
            if (_answered) {
              if (i == item.correctIndex) {
                state = DqChoiceState.correct;
              } else if (i == _selectedAnswer) {
                state = DqChoiceState.wrong;
              }
            }
            return DqChoice(
              label: '${i + 1}.  ${item.choices[i]}',
              state: state,
              showCursor: !_answered && _selectedAnswer == null,
              onTap: _answered ? null : () => _selectAnswer(i),
            );
          }),

          // Next button after answer
          if (_answered) ...[
            const SizedBox(height: 12),
            DqButton(
              label: _currentIdx < _items.length - 1
                  ? 'つぎへ / Next'
                  : 'けっか / Results',
              onTap: _next,
            ),
          ],
        ],
      ),
    );
  }

  // ── Results ───────────────────────────────────────────────────────────────

  Widget _buildResults(BuildContext context) {
    final pct =
        _items.isEmpty ? 0 : (_correctCount / _items.length * 100).round();
    final passed = pct >= 60;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              passed ? '🎉' : '💪',
              style: const TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 12),
            Text(
              passed ? '合格ライン到達！' : 'もう少し！',
              style: dqText(size: 22, color: dqGold),
            ),
            const SizedBox(height: 16),
            DqPanel(
              title: 'RESULT',
              child: Column(
                children: [
                  Text(
                    '$_correctCount / ${_items.length} 正解',
                    style: dqText(size: 20, color: dqInk),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$pct%',
                    style: dqText(
                      size: 28,
                      color: passed ? const Color(0xFF8BE08B) : const Color(0xFFE89090),
                      w: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            DqButton(
              label: 'もどる / Back',
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmpty(BuildContext context) {
    return DqScene(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildHeader(context),
            const Spacer(),
            DqPanel(
              child: Text(
                'このグレードのリスニング問題は準備中です。\n'
                'Listening items for this grade are coming soon.',
                style: dqText(size: 15, color: dqInk),
                textAlign: TextAlign.center,
              ),
            ),
            const Spacer(),
            DqButton(
              label: 'もどる / Back',
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
