import 'package:flutter/material.dart';

import '../quest/ui/dq_ui.dart';

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
///
/// Visually this is the Dragon-Quest "賢者 asks you questions" opening: a dark
/// atmospheric scene, a navy+cream command/dialogue window, ▶-cursor choices,
/// serif text, and bilingual (日本語 / English) short labels.

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

// English class names for the bilingual avatar labels (cosmetic only — does not
// change the stored avatarId or the AvatarOption values).
String _avatarClassEn(String jobTitle) {
  switch (jobTitle) {
    case 'ナイト':
      return 'Knight';
    case 'マジシャン':
      return 'Mage';
    case 'アーチャー':
      return 'Archer';
    case 'ヒーラー':
      return 'Healer';
    case 'ローグ':
      return 'Rogue';
    default:
      return jobTitle;
  }
}

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
    return DqScene(
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
// Progress bar — a row of gold/dim "gems" tracking the 4 setup steps.
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
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                gradient: active
                    ? const LinearGradient(colors: [dqGold, dqGoldDeep])
                    : null,
                color: active ? null : dqNight1,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: active ? dqBorder : dqGoldDeep.withAlpha(90),
                  width: 1,
                ),
                boxShadow: active
                    ? [BoxShadow(color: dqGold.withAlpha(90), blurRadius: 6)]
                    : null,
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 1: Age input — the Sage greets you and asks your age.
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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Center(
            child: dqBilingual(
              'ENG Quest へようこそ',
              'Welcome, brave one',
              jpSize: 22,
              jpColor: dqGold,
              stacked: true,
              align: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DqPortrait(emoji: '🧙‍♂️', size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: DqDialogBox(
                  speaker: '賢者 / Sage',
                  child: Text(
                    'ようこそ、勇者よ。旅をはじめる前に、'
                    'いくつか たずねたいことがある。\nそなたは 何才かな？',
                    style: dqText(size: 15, color: dqInk),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          DqPanel(
            title: 'ねんれい / Age',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: RichText(
                    text: TextSpan(children: [
                      TextSpan(
                        text: '$age',
                        style: dqText(size: 56, w: FontWeight.w800, color: dqGold),
                      ),
                      TextSpan(
                        text: '  さい',
                        style: dqText(size: 20, color: dqInk),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: dqGold,
                    inactiveTrackColor: dqNight1,
                    thumbColor: dqGold,
                    overlayColor: dqGold.withAlpha(40),
                    valueIndicatorColor: dqGoldDeep,
                  ),
                  child: Slider(
                    value: age.toDouble(),
                    min: 4,
                    max: 18,
                    divisions: 14,
                    label: '$age',
                    onChanged: (v) => onAgeChanged(v.round()),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('4さい',
                        style: dqText(size: 12, color: dqInk, w: FontWeight.w500)),
                    Text('18さい',
                        style: dqText(size: 12, color: dqInk, w: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          DqButton(label: 'つぎへ / Next ▶', onTap: onNext),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2a: Placement question — DQ command-window quiz.
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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Center(
            child: dqBilingual(
              'えいごチェック ${questionIndex + 1}/$total',
              'Placement ${questionIndex + 1}/$total',
              jpSize: 15,
              jpColor: dqInk,
              align: TextAlign.center,
            ),
          ),
          const SizedBox(height: 22),
          DqDialogBox(
            speaker: '賢者 / Sage',
            child: Text(
              question.question,
              style: dqText(size: 21, w: FontWeight.w700, color: dqInk),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 26),
          ...List.generate(question.options.length, (i) {
            return DqChoice(
              label: question.options[i],
              showCursor: true,
              onTap: () => onAnswer(i == question.correctIndex),
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2b: Placement result — the Sage proclaims your starting rank.
// ---------------------------------------------------------------------------

class _PlacementResult extends StatelessWidget {
  final CefrPlacement placement;
  final VoidCallback onNext;

  const _PlacementResult({required this.placement, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          const Center(child: DqPortrait(emoji: '📜', size: 88)),
          const SizedBox(height: 24),
          DqPanel(
            title: 'はんてい / Your Rank',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Center(
                  child: Text(
                    placement.label,
                    style: dqText(size: 30, w: FontWeight.w800, color: dqGold),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  placement.description,
                  style: dqText(size: 15, color: dqInk),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          DqDialogBox(
            speaker: '賢者 / Sage',
            child: Text(
              'よし、そなたの ちからは わかった。\nさあ、旅の仲間を えらぼう。',
              style: dqText(size: 15, color: dqInk),
            ),
          ),
          const Spacer(),
          DqButton(label: 'つぎへ / Next ▶', onTap: onNext),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 3: Avatar selection — choose your party hero.
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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Center(
            child: dqBilingual(
              '仲間を選ぼう',
              'Choose Your Hero',
              jpSize: 22,
              jpColor: dqGold,
              stacked: true,
              align: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.82,
              children: avatars.map((av) {
                final selected = av.id == selectedId;
                return _AvatarCard(
                  avatar: av,
                  selected: selected,
                  onTap: () => onSelected(av.id),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          DqButton(label: 'このこにする / Choose ▶', onTap: onNext),
        ],
      ),
    );
  }
}

class _AvatarCard extends StatelessWidget {
  final AvatarOption avatar;
  final bool selected;
  final VoidCallback onTap;

  const _AvatarCard({
    required this.avatar,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: selected
                ? [dqNight1.withAlpha(245), dqBox.withAlpha(245)]
                : [dqBox.withAlpha(220), dqNight0.withAlpha(220)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? dqGold : dqGoldDeep.withAlpha(110),
            width: selected ? 2.5 : 1.5,
          ),
          boxShadow: selected
              ? [BoxShadow(color: dqGold.withAlpha(110), blurRadius: 12)]
              : const [
                  BoxShadow(
                      color: Colors.black54, blurRadius: 6, offset: Offset(0, 3))
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DqPortrait(emoji: avatar.emoji, size: selected ? 46 : 42),
            const SizedBox(height: 6),
            Text(
              avatar.name,
              style: dqText(
                size: 12,
                w: FontWeight.w700,
                color: selected ? dqGold : dqInk,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              _avatarClassEn(avatar.jobTitle),
              style: dqText(
                size: 10,
                w: FontWeight.w600,
                color: dqGoldDeep,
                spacing: 1,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 4: Daily goal + summary — the quest contract before you set out.
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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DqPortrait(emoji: avatar.emoji, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: DqDialogBox(
                  speaker: '${avatar.name} / ${_avatarClassEn(avatar.jobTitle)}',
                  child: Text(
                    '準備はいい？\n${placement.label} から旅を はじめよう！',
                    style: dqText(size: 15, color: dqInk),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          DqPanel(
            title: 'まいにちの もくひょう / Daily Goal',
            child: Row(
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
                          gradient: selected
                              ? const LinearGradient(colors: [dqGold, dqGoldDeep])
                              : null,
                          color: selected ? null : dqNight0.withAlpha(180),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: selected ? dqBorder : dqGoldDeep.withAlpha(110),
                            width: selected ? 2 : 1.5,
                          ),
                          boxShadow: selected
                              ? [BoxShadow(color: dqGold.withAlpha(90), blurRadius: 8)]
                              : null,
                        ),
                        child: Column(
                          children: [
                            Text(
                              '$min',
                              style: dqText(
                                size: 22,
                                w: FontWeight.w800,
                                color: selected
                                    ? const Color(0xFF2A1C00)
                                    : dqGold,
                              ),
                            ),
                            Text(
                              'min',
                              style: dqText(
                                size: 11,
                                w: FontWeight.w600,
                                color: selected
                                    ? const Color(0xFF2A1C00)
                                    : dqInk,
                                spacing: 1,
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
          ),
          const SizedBox(height: 16),
          // Summary panel — the quest contract.
          DqPanel(
            title: 'けいやく / Quest Contract',
            child: Column(
              children: [
                _SummaryRow(jp: 'レベル', en: 'Level', value: placement.label),
                const SizedBox(height: 6),
                _SummaryRow(
                    jp: 'なかま',
                    en: 'Hero',
                    value: '${avatar.emoji} ${avatar.name}'),
                const SizedBox(height: 6),
                _SummaryRow(
                    jp: 'もくひょう',
                    en: 'Goal',
                    value: '毎日 $goalMinutes min'),
              ],
            ),
          ),
          const Spacer(),
          // Eiken trademark disclaimer — required for compliance.
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '英検®は公益財団法人日本英語検定協会の登録商標です。'
              '本アプリは英検協会の公式アプリではありません。',
              style: dqText(
                size: 10,
                w: FontWeight.w400,
                color: dqInk.withAlpha(140),
              ).copyWith(height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),
          DqButton(label: 'ぼうけんをはじめる / Begin Quest ▶', onTap: onFinish),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String jp;
  final String en;
  final String value;
  const _SummaryRow({required this.jp, required this.en, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            child: dqBilingual(jp, en, jpSize: 14, jpColor: dqInk),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              style: dqText(size: 14, w: FontWeight.w700, color: dqGold),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
