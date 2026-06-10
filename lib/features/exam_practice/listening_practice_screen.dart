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

import 'dart:math';

import 'package:flutter/material.dart';

import 'choice_shuffle.dart';
import '../../core/audio/audio_assets.dart';
import '../../core/audio/audio_cue_service.dart';
import '../../core/audio/audio_mute.dart';
import '../../core/storage/preferences_service.dart';
import '../quest/ui/dq_ui.dart';
import '../home/streak_service.dart';
import 'eiken_exam_config.dart';
import 'listening_data.dart';
import '../quest/ui/muted_voice_banner.dart';
import 'pass/cse_model.dart';
import 'pass/skill_accuracy_store.dart';

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

  // HONESTY (CEO 2026-06-09 flaw-hunt #112): a listening item whose audio clip
  // is not actually bundled (the 40 ALLOWED_MISSING l3/l4 part-2/3 clips) can be
  // "answered" only by guessing from the question — recording that as listening
  // skill would inflate the 合格率 with un-heard answers. We therefore (a) mark
  // each item's audio availability, (b) show an honest 準備中 note instead of a
  // dead 🔊, and (c) feed 合格率 ONLY the items the child could actually hear.
  // [_audioOk] defaults true (AudioAssets.exists degrades to "present" if the
  // manifest can't be read) so a real clip is never wrongly excluded.
  List<bool> _audioOk = const [];
  int _measuredTotal = 0; // items answered with real, audible audio
  int _measuredCorrect = 0; // correct among those

  // Brings the post-answer スクリプト (transcript) into view — it renders below
  // the choices, so without this the listening 解説 sits below the fold.
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _cue = AudioCueService();
    // Shuffle each item's choices at load — the authored listening keys cluster
    // at position 2 (40%, position 4 nearly unused), so an always-tap-1 child
    // would score ~40% with no comprehension, inflating the listening 合格率.
    // Choices are on-screen text (not spoken in the audio), so moving them is
    // safe. Mirrors reading/conversation (#79). See [shuffledChoiceSet].
    final rng = Random();
    _items = (kListeningItems[widget.eikenGrade] ?? []).map((it) {
      final s = shuffledChoiceSet(it.choices, it.correctIndex, rng);
      return it.copyWith(choices: s.choices, correctIndex: s.correctIdx);
    }).toList();
    _partHeaderShown = _items.isEmpty;
    // Probe each item's audio availability (manifest-based, no byte load). Starts
    // optimistic (all true) so an item is never wrongly excluded before the check
    // resolves; flips an item false only if its clip is genuinely not bundled.
    _audioOk = List<bool>.filled(_items.length, true);
    for (var i = 0; i < _items.length; i++) {
      final idx = i;
      AudioAssets.exists('audio/listening/${_items[i].audioKey}').then((ok) {
        if (mounted && !ok) setState(() => _audioOk[idx] = false);
      });
    }
    _loadCaptionPref();
  }

  /// Deaf/HoH "read the script" mode (#125): when ON, the スクリプト is shown
  /// BEFORE answering so a child who can't hear can still practise listening
  /// comprehension. Persisted so the choice sticks.
  bool _captionsOn = false;

  // Whether the child actually PLAYED the current item's audio before answering
  // (#R5 metric-gamer): the screen does not (and on web cannot reliably) auto-play,
  // so a child could rapid-guess without ever hearing the clip and still feed the
  // by-ear 合格率. Reset per item; an un-played item is not honest listening
  // measurement and is excluded — same principle as muted/captioned (#112/#125).
  bool _playedCurrent = false;

  Future<void> _loadCaptionPref() async {
    final prefs = await PreferencesService.getInstance();
    final on = prefs.getBool(PrefKeys.listeningCaptions);
    if (mounted && on) setState(() => _captionsOn = true);
  }

  Future<void> _toggleCaptions() async {
    setState(() => _captionsOn = !_captionsOn);
    final prefs = await PreferencesService.getInstance();
    await prefs.setBool(PrefKeys.listeningCaptions, _captionsOn);
  }

  /// Whether the CURRENT item can honestly count toward the listening 合格率:
  /// its audio is bundled, the Voice channel isn't muted, the child is not in
  /// "read the script" caption mode (reading ≠ hearing), AND the child actually
  /// PLAYED the clip (answering blind without listening is not a by-ear result).
  /// A muted/captioned/un-played child did not actually HEAR it, so it stays out
  /// of the by-ear 合格率 (#112/#125/#R5).
  bool get _currentMeasurable =>
      _currentIdx < _audioOk.length &&
      _audioOk[_currentIdx] &&
      !AudioMute.voiceMuted &&
      !_captionsOn &&
      _playedCurrent;

  @override
  void dispose() {
    _scroll.dispose();
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
    _playedCurrent = true; // heard it → this item may count toward 合格率
    _cue.play('audio/listening/${item.audioKey}');
  }

  void _selectAnswer(int idx) {
    if (_answered) return;
    final item = _current;
    if (item == null) return;
    final measurable = _currentMeasurable;
    setState(() {
      _selectedAnswer = idx;
      _answered = true;
      final correct = idx == item.correctIndex;
      if (correct) _correctCount++;
      // Only audible items feed the 合格率 (honest listening measurement).
      if (measurable) {
        _measuredTotal++;
        if (correct) _measuredCorrect++;
      }
    });
    // Reveal the スクリプト (what was said) so the child can read what they
    // misheard — the listening learning loop, using the authored transcript.
    // jumpTo (not animateTo): instant, leaves no pending animation that would
    // fight a flow that pumps single frames.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  /// Records the completed session result into [SkillAccuracyStore].
  /// listening → EikenSkill.listening.
  Future<void> _recordSessionResult() async {
    if (_items.isEmpty) return;
    recordExamHabit(_items.length); // streak + daily-goal, not just 合格率
    // Honesty: feed 合格率 ONLY the items the child could actually hear. If none
    // were audible (e.g. a grade whose clips aren't bundled), record nothing —
    // listening stays honestly 未測定 rather than logging un-heard guesses.
    if (_measuredTotal == 0) return;
    try {
      final store = await SkillAccuracyStore.getInstance();
      await store.record(
        grade: widget.eikenGrade,
        skill: EikenSkill.listening,
        correct: _measuredCorrect,
        total: _measuredTotal,
      );
    } catch (_) {
      // Store errors are non-fatal — never interrupt the learner.
    }
  }

  void _next() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    if (_currentIdx >= _items.length - 1) {
      _recordSessionResult(); // fire-and-forget; UI does not wait
      setState(() => _sessionDone = true);
    } else {
      setState(() {
        _currentIdx++;
        _selectedAnswer = null;
        _answered = false;
        _partHeaderShown = false;
        _playedCurrent = false; // new item: must hear it again to count (#R5)
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
          // A listening exercise is 100% audio — if the child muted the Voice
          // channel they'd face a silent, unanswerable quiz. Warn + offer a
          // one-tap unmute right here.
          if (AudioMute.voiceMuted)
            MutedVoiceBanner(onUnmute: () => setState(() {})),
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
              gradeLabelJa(widget.eikenGrade),
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
    if (grade == 'pre1') {
      // 準1: 第1部 会話の内容一致 / 第2部 説明文の内容一致 / 第3部 Real-Life形式.
      if (part == 1) return '会話の内容一致 / Dialogue Content';
      if (part == 2) return '説明文の内容一致 / Passage Content';
      return 'Real-Life形式 / Real-Life';
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
      controller: _scroll,
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

          // 🔊 Large replay button — OR, when this item's clip isn't bundled, an
          // honest 準備中 note (no dead button) that also says it won't count
          // toward 合格率 (#112). [_audioOk] starts true so the button is the
          // default; the note only appears for a genuinely-missing clip.
          Center(
            child: (_currentIdx < _audioOk.length && !_audioOk[_currentIdx])
                ? _missingAudioNote()
                : DqReplayButton(
                    label: '🔊 もう いちど きく',
                    onTap: _playAudio,
                  ),
          ),
          const SizedBox(height: 8),
          // Deaf/HoH inclusion (#125): read the script instead of hearing it.
          // The transcript already exists; in caption mode we show it BEFORE the
          // choices so a child who can't hear can still practise comprehension.
          Center(
            child: TextButton.icon(
              onPressed: _toggleCaptions,
              icon: Icon(
                _captionsOn ? Icons.volume_up_rounded : Icons.subtitles_rounded,
                color: dqGold,
                size: 18,
              ),
              label: Text(
                _captionsOn
                    ? '音（おと）で きくモードに もどす'
                    : '🔤 文字（もじ）で よむ（音（おと）が きこえないとき）',
                style: dqText(size: 12, color: dqGold),
              ),
            ),
          ),
          if (_captionsOn && !_answered) ...[
            const SizedBox(height: 8),
            _TranscriptPanel(item: item),
            const SizedBox(height: 4),
            Text(
              '※ 文字（もじ）で よむモードは「聞（き）く力（ちから）」の'
              '合格率（ごうかくりつ）には 入（い）れません。',
              textAlign: TextAlign.center,
              style: dqText(size: 11, color: dqInk.withAlpha(150)),
            ),
          ],
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

          // 解説 after answer: show the スクリプト (what was said) so a child who
          // misheard can read it — the listening learning loop. Replay (🔊 above)
          // stays available to hear it again.
          if (_answered) ...[
            const SizedBox(height: 14),
            _TranscriptPanel(item: item),
          ],

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

  /// Honest stand-in when this item's listening clip isn't bundled (#112): no
  /// dead 🔊, and a plain note that this question won't count toward 合格率.
  Widget _missingAudioNote() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: dqBox.withAlpha(220),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: dqGoldDeep.withAlpha(120)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '🔇 この問題（もんだい）は 音声（おんせい）じゅんびちゅう',
              textAlign: TextAlign.center,
              style: dqText(size: 13, w: FontWeight.w700, color: dqInk),
            ),
            const SizedBox(height: 3),
            Text(
              '合格率（ごうかくりつ）には 入（い）れません',
              textAlign: TextAlign.center,
              style: dqText(size: 11, color: dqGold),
            ),
          ],
        ),
      );

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
              passed ? '合格（ごうかく）ライン到達（とうたつ）！' : 'もう少（すこ）し！',
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
                      color: passed
                          ? const Color(0xFF8BE08B)
                          : const Color(0xFFE89090),
                      w: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            if (_items.length - _measuredTotal > 0) ...[
              const SizedBox(height: 12),
              Text(
                '音声（おんせい）のない ${_items.length - _measuredTotal}問（もん）は、\n'
                '合格率（ごうかくりつ）に 入（い）れていません。',
                textAlign: TextAlign.center,
                style: dqText(size: 12, color: dqInk.withAlpha(170)),
              ),
            ],
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

/// Post-answer スクリプト panel (#4): reveals the authored transcript of what was
/// said, so a child who misheard can READ it (the listening learning loop —
/// listening had only a Next button before). Dialogue items (2 speakers) are
/// labelled A / B; a monologue passage is shown as plain lines.
class _TranscriptPanel extends StatelessWidget {
  final ListeningItem item;
  const _TranscriptPanel({required this.item});

  @override
  Widget build(BuildContext context) {
    // Render VERBATIM: the authored transcripts already carry their own speaker
    // labels ("A:" / "B:") and a trailing "Question:" line where applicable, so
    // we must NOT re-prefix (that would double-label and mislabel the question).
    final lines = item.transcripts;
    return Container(
      key: const ValueKey('listening_transcript'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: dqBox.withAlpha(235),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: dqGoldDeep, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.subject_rounded, color: dqGold, size: 18),
              const SizedBox(width: 6),
              Text('スクリプト / Script',
                  style: dqText(
                      size: 12, w: FontWeight.w800, color: dqGold, spacing: 1)),
            ],
          ),
          const SizedBox(height: 8),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                line,
                style: dqText(size: 14, w: FontWeight.w500, color: dqInk)
                    .copyWith(height: 1.5),
              ),
            ),
        ],
      ),
    );
  }
}
