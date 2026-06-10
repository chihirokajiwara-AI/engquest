// lib/features/speaking/speaking_session.dart
// A-KEN Quest — 英検 二次 Speaking Session Model (pure Dart, no Flutter).
//
// Models the structured flow of the 英検 二次試験 (Secondary / Interview exam)
// per grade:
//
//   3級  (A2)  : 音読 ~30語 → No.1 パッセージ質問 → No.2/3 イラスト → No.4/5 自分自身 (5問)
//   準2級 (A2) : 音読 ~70語 → No.1 パッセージ質問 → No.2/3/4/5 イラスト2枚 (5問)
//   2級  (B1)  : 音読 ~90語 → No.1 パッセージ質問 → No.2 イラスト展開 → No.3/4 意見 (4問)
//   準1級 (B2) : 自由会話 → 4コマナレーション (~2分) → No.1-4 意見質問 (4問)
//
// The session is a linear list of [SpeakingStep]s.  The screen calls
//   session.currentStep  — the active step
//   session.advance()    — move to next step (returns false when done)
//   session.isComplete   — true when all steps are done
//
// アティチュード coach:
//   silenceCount tracks consecutive silent responses (transcript == '').
//   At silenceCount >= 1 the coach message is set to a gentle prompt.
//   Attitude is worth 3 pts in the real exam — encouraging any attempt is correct.

// ── Step types ────────────────────────────────────────────────────────────────

/// The type of a single step in the interview flow.
enum SpeakingStepType {
  /// Child reads the passage aloud.
  ondo,

  /// Examiner asks a question about the passage (No.1).
  passageQuestion,

  /// Child describes or narrates an illustration (No.2/3 準2級, No.2 2級,
  /// or the 4コマ narration in 準1級).
  illustrationNarration,

  /// Free-response opinion question (No.4/5 3級, No.3/4 2級, No.1-4 準1級).
  opinionQuestion,

  /// Free conversation intro (準1級 before narration).
  freeConversation,
}

/// A single step in the interview.
class SpeakingStep {
  final SpeakingStepType type;

  /// Display label (e.g. 'No. 1' or '音読').
  final String label;

  /// The reference text shown on screen — the passage text (for 音読 / No.1),
  /// the question text (for Q&A steps), or narration prompt.
  final String referenceText;

  /// Optional illustration emoji / description shown as a placeholder
  /// until real art is available.
  final String? illustrationPlaceholder;

  /// Preparation time in seconds (e.g. 20秒 for 準2級/2級 illustration).
  final int prepSeconds;

  const SpeakingStep({
    required this.type,
    required this.label,
    required this.referenceText,
    this.illustrationPlaceholder,
    this.prepSeconds = 0,
  });
}

// ── Per-grade session data ─────────────────────────────────────────────────────

/// Build the ordered list of steps for [eikenGrade].
///
/// Passages are representative practice texts — not official 英検 material.
/// They match the real exam's approximate word count and topic style.
List<SpeakingStep> buildSessionSteps(String eikenGrade) {
  switch (eikenGrade) {
    case '3':
      return _grade3Steps();
    case 'pre2':
      return _gradePre2Steps();
    case '2':
      return _grade2Steps();
    case 'pre1':
      return _gradePre1Steps();
    default:
      return _grade3Steps();
  }
}

List<SpeakingStep> _grade3Steps() => [
      const SpeakingStep(
        type: SpeakingStepType.ondo,
        label: '音読',
        referenceText: 'Many schools in Japan now have English classes. '
            'Students learn to speak and write in English. '
            'Some students also watch English videos to improve their skills.',
      ),
      const SpeakingStep(
        type: SpeakingStepType.passageQuestion,
        label: 'No. 1',
        referenceText:
            'According to the passage, what do some students do to improve their English skills?',
      ),
      const SpeakingStep(
        type: SpeakingStepType.illustrationNarration,
        label: 'No. 2',
        referenceText: 'Please describe what you see in the picture.',
        illustrationPlaceholder:
            '🏃 [イラスト: 公園で男の子がサッカーをしている / A boy playing soccer in a park]',
        prepSeconds: 10,
      ),
      const SpeakingStep(
        type: SpeakingStepType.illustrationNarration,
        label: 'No. 3',
        referenceText: 'Please describe what you see in this picture.',
        illustrationPlaceholder:
            '🛒 [イラスト: お母さんと子どもがスーパーで買い物している / Mother and child shopping in a supermarket]',
        prepSeconds: 10,
      ),
      const SpeakingStep(
        type: SpeakingStepType.opinionQuestion,
        label: 'No. 4',
        referenceText: 'Do you like studying English? Why or why not?',
      ),
      const SpeakingStep(
        type: SpeakingStepType.opinionQuestion,
        label: 'No. 5',
        referenceText: 'What do you usually do on weekends?',
      ),
    ];

List<SpeakingStep> _gradePre2Steps() => [
      const SpeakingStep(
        type: SpeakingStepType.ondo,
        label: '音読',
        referenceText:
            'In recent years, more and more young people are interested in '
            'environmental issues. Many schools now teach students about recycling '
            'and how to reduce waste. Some students even start projects in their '
            'local communities to help protect the environment. By learning about '
            'these issues early, young people can make a difference in the future.',
        prepSeconds: 20,
      ),
      const SpeakingStep(
        type: SpeakingStepType.passageQuestion,
        label: 'No. 1',
        referenceText:
            'According to the passage, what do some students do in their local communities?',
      ),
      const SpeakingStep(
        type: SpeakingStepType.illustrationNarration,
        label: 'No. 2',
        referenceText:
            'Please look at the two pictures. Please describe the situation in each picture.',
        illustrationPlaceholder:
            '🌱 [イラスト1: 学生が公園でゴミを拾っている / Students picking up litter in a park]\n'
            '♻️ [イラスト2: 家族が分別ゴミを出している / Family sorting recycling bins]',
        prepSeconds: 20,
      ),
      const SpeakingStep(
        type: SpeakingStepType.opinionQuestion,
        label: 'No. 3',
        referenceText:
            'Do you think it is important for schools to teach students about environmental issues? Why?',
      ),
      const SpeakingStep(
        type: SpeakingStepType.opinionQuestion,
        label: 'No. 4',
        referenceText:
            'These days, many people use reusable bags when shopping. What do you think about this?',
      ),
      const SpeakingStep(
        type: SpeakingStepType.opinionQuestion,
        label: 'No. 5',
        referenceText:
            'Have you ever participated in a community event? Please tell me more.',
      ),
    ];

List<SpeakingStep> _grade2Steps() => [
      const SpeakingStep(
        type: SpeakingStepType.ondo,
        label: '音読',
        referenceText:
            'Advances in technology have changed the way people work and communicate. '
            'Remote work has become common in many countries, allowing employees to '
            'work from home using the internet. While this offers more flexibility, '
            'some people argue that it makes it harder to build strong working relationships. '
            'Companies are now experimenting with hybrid work models to find the right balance.',
        prepSeconds: 20,
      ),
      const SpeakingStep(
        type: SpeakingStepType.passageQuestion,
        label: 'No. 1',
        referenceText:
            'According to the passage, what are companies doing to find the right balance?',
      ),
      const SpeakingStep(
        type: SpeakingStepType.illustrationNarration,
        label: 'No. 2',
        referenceText:
            'This card shows a situation. Please describe what is happening and predict what will happen next.',
        illustrationPlaceholder: '💻 [イラスト: 女性がカフェでノートパソコンを使って仕事している / '
            'A woman working on a laptop in a café; a "Low Battery" warning appears]',
        prepSeconds: 20,
      ),
      const SpeakingStep(
        type: SpeakingStepType.opinionQuestion,
        label: 'No. 3',
        referenceText:
            'Some people say that remote work is better than working in an office. What do you think?',
      ),
      const SpeakingStep(
        type: SpeakingStepType.opinionQuestion,
        label: 'No. 4',
        referenceText:
            'In recent years, more young people are choosing to work as freelancers. '
            'Do you think this trend will continue in the future?',
      ),
    ];

List<SpeakingStep> _gradePre1Steps() => [
      const SpeakingStep(
        type: SpeakingStepType.freeConversation,
        label: '自由会話',
        referenceText: 'Let\'s start with some free conversation. '
            'Can you tell me about yourself — your hobbies or interests?',
      ),
      const SpeakingStep(
        type: SpeakingStepType.illustrationNarration,
        label: '4コマナレーション',
        referenceText: 'Please look at the four pictures. They tell a story. '
            'Please narrate the story. You have about two minutes.',
        illustrationPlaceholder:
            '🌧️ [コマ1: 男性が傘を忘れて雨の中を歩いている / Man walking in rain, no umbrella]\n'
            '🏪 [コマ2: コンビニで傘を購入している / Man buying an umbrella at a convenience store]\n'
            '☀️ [コマ3: 外に出たら晴れている / Sunny outside when he exits]\n'
            '😅 [コマ4: 家に帰ると傘が沢山ある / He arrives home to find many umbrellas]',
        prepSeconds: 60,
      ),
      const SpeakingStep(
        type: SpeakingStepType.opinionQuestion,
        label: 'No. 1',
        referenceText:
            'Please look at the third picture. If you were the man in this situation, '
            'what would you be thinking?',
      ),
      const SpeakingStep(
        type: SpeakingStepType.opinionQuestion,
        label: 'No. 2',
        referenceText:
            'Do you think people are becoming too dependent on convenience stores in Japan? Why?',
      ),
      const SpeakingStep(
        type: SpeakingStepType.opinionQuestion,
        label: 'No. 3',
        referenceText:
            'Some people say that cashless payments will eventually replace cash entirely. '
            'What is your opinion?',
      ),
      const SpeakingStep(
        type: SpeakingStepType.opinionQuestion,
        label: 'No. 4',
        referenceText:
            'Do you think working hours in Japan will decrease in the future? Why or why not?',
      ),
    ];

// ── Session controller ────────────────────────────────────────────────────────

/// Manages state for a single 二次 practice session.
///
/// R4 compliant: no Firebase, no network.  Pure in-memory state.
class SpeakingSession {
  SpeakingSession({required this.eikenGrade})
      : _steps = buildSessionSteps(eikenGrade);

  final String eikenGrade;
  final List<SpeakingStep> _steps;

  int _currentIndex = 0;

  /// Consecutive silent responses — drives アティチュード coach.
  int silenceCount = 0;

  /// アティチュード coach message.  Non-null when silence has been detected.
  String? get attitudeCoachMessage {
    if (silenceCount == 0) return null;
    if (silenceCount == 1) {
      return 'もう少し、ゆっくり言ってみよう！\nAny words are fine — just try!';
    }
    return 'だいじょうぶ！まず「I think...」だけでもいいよ。\n'
        'It\'s OK — start with "I think…" and keep going!';
  }

  /// The current step in the session.
  SpeakingStep get currentStep => _steps[_currentIndex];

  /// Whether all steps have been completed.
  bool get isComplete => _currentIndex >= _steps.length;

  /// Total step count.
  int get totalSteps => _steps.length;

  /// Index of the current step (0-based).
  int get currentIndex => _currentIndex;

  /// Advance to the next step.
  ///
  /// [transcript] is the recognised text from the current step.
  /// Tracks silence for the アティチュード coach.
  ///
  /// Returns false if the session is already complete.
  bool advance({required String transcript}) {
    if (isComplete) return false;

    if (transcript.trim().isEmpty) {
      silenceCount++;
    } else {
      silenceCount = 0; // reset on any speech
    }

    _currentIndex++;
    return !isComplete;
  }

  /// Restart the session from the beginning.
  void restart() {
    _currentIndex = 0;
    silenceCount = 0;
  }

  /// All steps (read-only).
  List<SpeakingStep> get steps => List.unmodifiable(_steps);
}
