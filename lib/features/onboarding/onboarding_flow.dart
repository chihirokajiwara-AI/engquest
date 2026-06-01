import 'package:flutter/material.dart';

/// ENG Quest — Onboarding Flow (C10)
///
/// 4-step onboarding for new users:
///   Step 1: Welcome + age input
///   Step 2: CEFR placement (3-question mini-test)
///   Step 3: Avatar selection (5 characters)
///   Step 4: Goal setting + first session entry
///
/// On completion, calls [onComplete] with the resulting [OnboardingResult].
/// The result is persisted by the parent widget (e.g. to SharedPreferences).

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

class OnboardingResult {
  final int ageYears;
  final CefrPlacement cefrPlacement;
  final String avatarId;
  final int dailyGoalMinutes;

  const OnboardingResult({
    required this.ageYears,
    required this.cefrPlacement,
    required this.avatarId,
    required this.dailyGoalMinutes,
  });
}

enum CefrPlacement { beginner, a1, a2 }

extension CefrPlacementLabel on CefrPlacement {
  String get label {
    switch (this) {
      case CefrPlacement.beginner:
        return 'はじめて';
      case CefrPlacement.a1:
        return 'A1 (英検5級)';
      case CefrPlacement.a2:
        return 'A2 (英検4級)';
    }
  }

  String get description {
    switch (this) {
      case CefrPlacement.beginner:
        return 'アルファベットから始めよう！';
      case CefrPlacement.a1:
        return '基本単語300語からスタート';
      case CefrPlacement.a2:
        return '日常会話レベルで挑戦！';
    }
  }
}

// ---------------------------------------------------------------------------
// Mini placement test data
// ---------------------------------------------------------------------------

class PlacementQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final CefrPlacement targetLevel; // which level this question tests

  const PlacementQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.targetLevel,
  });
}

const List<PlacementQuestion> _placementQuestions = [
  PlacementQuestion(
    question: '"Dog" の意味は？',
    options: ['ねこ', 'いぬ', 'さかな', 'とり'],
    correctIndex: 1,
    targetLevel: CefrPlacement.a1,
  ),
  PlacementQuestion(
    question: '"I ___ a student." に入る言葉は？',
    options: ['am', 'is', 'are', 'be'],
    correctIndex: 0,
    targetLevel: CefrPlacement.a1,
  ),
  PlacementQuestion(
    question: '"What time do you usually wake up?" の意味は？',
    options: [
      'どこに住んでいますか？',
      '何が好きですか？',
      'いつも何時に起きますか？',
      '今日は何曜日ですか？',
    ],
    correctIndex: 2,
    targetLevel: CefrPlacement.a2,
  ),
];

CefrPlacement _scoreToCefr(int correctCount) {
  if (correctCount == 0) return CefrPlacement.beginner;
  if (correctCount <= 1) return CefrPlacement.a1;
  return CefrPlacement.a2;
}

// ---------------------------------------------------------------------------
// Avatar data
// ---------------------------------------------------------------------------

class AvatarOption {
  final String id;
  final String emoji;
  final String name;
  final String jobTitle; // RPG class

  const AvatarOption({
    required this.id,
    required this.emoji,
    required this.name,
    required this.jobTitle,
  });
}

const List<AvatarOption> _avatars = [
  AvatarOption(id: 'knight', emoji: '⚔️', name: 'アレックス', jobTitle: 'ナイト'),
  AvatarOption(id: 'mage', emoji: '🧙', name: 'ルーナ', jobTitle: 'マジシャン'),
  AvatarOption(id: 'archer', emoji: '🏹', name: 'カイ', jobTitle: 'アーチャー'),
  AvatarOption(id: 'healer', emoji: '✨', name: 'ソフィー', jobTitle: 'ヒーラー'),
  AvatarOption(id: 'rogue', emoji: '🗡️', name: 'ゼン', jobTitle: 'ローグ'),
];

// ---------------------------------------------------------------------------
// Main onboarding widget
// ---------------------------------------------------------------------------

class OnboardingFlow extends StatefulWidget {
  final void Function(OnboardingResult) onComplete;

  const OnboardingFlow({super.key, required this.onComplete});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow>
    with SingleTickerProviderStateMixin {
  int _step = 0; // 0..3
  static const int _totalSteps = 4;

  // Step 1 — age
  int _age = 8;

  // Step 2 — placement
  int _qIndex = 0;
  int _correctCount = 0;
  CefrPlacement? _placement;

  // Step 3 — avatar
  String _selectedAvatarId = _avatars.first.id;

  // Step 4 — goal
  int _dailyGoalMinutes = 10;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    _fadeCtrl.reverse().then((_) {
      setState(() => _step++);
      _fadeCtrl.forward();
    });
  }

  void _finish() {
    final result = OnboardingResult(
      ageYears: _age,
      cefrPlacement: _placement ?? CefrPlacement.a1,
      avatarId: _selectedAvatarId,
      dailyGoalMinutes: _dailyGoalMinutes,
    );
    widget.onComplete(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            _ProgressBar(step: _step, total: _totalSteps),
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: _buildCurrentStep(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case 0:
        return _StepAge(
          age: _age,
          onAgeChanged: (v) => setState(() => _age = v),
          onNext: _nextStep,
        );
      case 1:
        return _placement != null
            ? _PlacementResult(
                placement: _placement!,
                onNext: _nextStep,
              )
            : _StepPlacement(
                question: _placementQuestions[_qIndex],
                questionIndex: _qIndex,
                total: _placementQuestions.length,
                onAnswer: (isCorrect) {
                  if (isCorrect) _correctCount++;
                  if (_qIndex < _placementQuestions.length - 1) {
                    setState(() => _qIndex++);
                  } else {
                    setState(() => _placement = _scoreToCefr(_correctCount));
                  }
                },
              );
      case 2:
        return _StepAvatar(
          avatars: _avatars,
          selectedId: _selectedAvatarId,
          onSelected: (id) => setState(() => _selectedAvatarId = id),
          onNext: _nextStep,
        );
      case 3:
        return _StepGoal(
          goalMinutes: _dailyGoalMinutes,
          avatarId: _selectedAvatarId,
          placement: _placement ?? CefrPlacement.a1,
          onGoalChanged: (v) => setState(() => _dailyGoalMinutes = v),
          onFinish: _finish,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ---------------------------------------------------------------------------
// Progress bar
// ---------------------------------------------------------------------------

class _ProgressBar extends StatelessWidget {
  final int step;
  final int total;
  const _ProgressBar({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(total, (i) {
          final active = i <= step;
          return Expanded(
            child: Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFFFFC107) // amber gold
                    : const Color(0xFFCFD8DC),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 1: Age input
// ---------------------------------------------------------------------------

class _StepAge extends StatelessWidget {
  final int age;
  final ValueChanged<int> onAgeChanged;
  final VoidCallback onNext;

  const _StepAge({
    required this.age,
    required this.onAgeChanged,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          const Text(
            '🏰 ENG Quest へようこそ！',
            style: TextStyle(
              color: Color(0xFF4FC3F7),
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            '何才ですか？',
            style: TextStyle(color: Color(0xFF607D8B), fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          // Age display
          Text(
            '$age さい',
            style: const TextStyle(
              color: Color(0xFF263238),
              fontSize: 56,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // Slider
          Slider(
            value: age.toDouble(),
            min: 4,
            max: 18,
            divisions: 14,
            activeColor: const Color(0xFFFFC107),
            inactiveColor: const Color(0xFFCFD8DC),
            onChanged: (v) => onAgeChanged(v.round()),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('4さい',
                  style: TextStyle(color: Color(0xFF90A4AE), fontSize: 12)),
              Text('18さい',
                  style: TextStyle(color: Color(0xFF90A4AE), fontSize: 12)),
            ],
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC107),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('つぎへ →',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2a: Placement question
// ---------------------------------------------------------------------------

class _StepPlacement extends StatelessWidget {
  final PlacementQuestion question;
  final int questionIndex;
  final int total;
  final void Function(bool isCorrect) onAnswer;

  const _StepPlacement({
    required this.question,
    required this.questionIndex,
    required this.total,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Text(
            'えいごチェック ${questionIndex + 1}/$total',
            style: const TextStyle(color: Color(0xFF607D8B), fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFC107), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4FC3F7).withAlpha(30),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              question.question,
              style: const TextStyle(
                color: Color(0xFF263238),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          ...List.generate(question.options.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OutlinedButton(
                onPressed: () => onAnswer(i == question.correctIndex),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF263238),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFB0BEC5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(question.options[i],
                    style: const TextStyle(fontSize: 16)),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2b: Placement result
// ---------------------------------------------------------------------------

class _PlacementResult extends StatelessWidget {
  final CefrPlacement placement;
  final VoidCallback onNext;

  const _PlacementResult({required this.placement, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Text('🎉', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            placement.label,
            style: const TextStyle(
              color: Color(0xFF4FC3F7),
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            placement.description,
            style: const TextStyle(color: Color(0xFF607D8B), fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC107),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('つぎへ →',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 3: Avatar selection
// ---------------------------------------------------------------------------

class _StepAvatar extends StatelessWidget {
  final List<AvatarOption> avatars;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final VoidCallback onNext;

  const _StepAvatar({
    required this.avatars,
    required this.selectedId,
    required this.onSelected,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          const Text(
            '仲間を選ぼう！',
            style: TextStyle(
              color: Color(0xFF4FC3F7),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: avatars.map((av) {
                final selected = av.id == selectedId;
                return GestureDetector(
                  onTap: () => onSelected(av.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFFFC107).withAlpha(38)
                          : Colors.white,
                      border: Border.all(
                        color: selected
                            ? const Color(0xFFFFC107)
                            : const Color(0xFFE0E0E0),
                        width: selected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(12),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(av.emoji, style: const TextStyle(fontSize: 36)),
                        const SizedBox(height: 4),
                        Text(av.name,
                            style: const TextStyle(
                                color: Color(0xFF263238),
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                        Text(av.jobTitle,
                            style: const TextStyle(
                                color: Color(0xFF607D8B), fontSize: 11)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC107),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('このこにする！',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 4: Daily goal + summary
// ---------------------------------------------------------------------------

class _StepGoal extends StatelessWidget {
  final int goalMinutes;
  final String avatarId;
  final CefrPlacement placement;
  final ValueChanged<int> onGoalChanged;
  final VoidCallback onFinish;

  const _StepGoal({
    required this.goalMinutes,
    required this.avatarId,
    required this.placement,
    required this.onGoalChanged,
    required this.onFinish,
  });

  static const List<int> _presets = [5, 10, 15, 20];

  @override
  Widget build(BuildContext context) {
    final avatar = _avatars.firstWhere((a) => a.id == avatarId,
        orElse: () => _avatars.first);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Text(
            '${avatar.emoji} ${avatar.name}、準備はいい？',
            style: const TextStyle(
              color: Color(0xFF4FC3F7),
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '${placement.label}からスタート',
            style: const TextStyle(color: Color(0xFF607D8B), fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          const Text(
            '毎日の目標',
            style: TextStyle(color: Color(0xFF263238), fontSize: 16),
          ),
          const SizedBox(height: 12),
          Row(
            children: _presets.map((min) {
              final selected = min == goalMinutes;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => onGoalChanged(min),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color:
                            selected ? const Color(0xFFFFC107) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFFFFC107)
                              : const Color(0xFFE0E0E0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(10),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$min',
                            style: TextStyle(
                              color: selected
                                  ? Colors.black
                                  : const Color(0xFF263238),
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'ふん',
                            style: TextStyle(
                              color: selected
                                  ? Colors.black87
                                  : const Color(0xFF607D8B),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          // Summary card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E0E0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(12),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _SummaryRow(label: 'レベル', value: placement.label),
                _SummaryRow(
                    label: 'キャラ', value: '${avatar.emoji} ${avatar.name}'),
                _SummaryRow(label: '目標', value: '毎日$goalMinutesふん'),
              ],
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: onFinish,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC107),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('ぼうけんをはじめる！🗺️',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Color(0xFF607D8B), fontSize: 14)),
          Text(value,
              style: const TextStyle(
                  color: Color(0xFF263238),
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
