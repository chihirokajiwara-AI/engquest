import 'package:flutter/material.dart';

import '../../core/audio/nav_speak.dart';
import '../../core/config/flavor_config.dart';
import '../quest/ui/dq_ui.dart';
import 'placement_engine.dart';
import 'placement_item_bank.dart';

/// ENG Quest — Onboarding Flow (C10)
///
/// 4-step onboarding for new users:
///   Step 1: Welcome + age input
///   Step 2: Adaptive placement (3–8 questions, CAT engine)
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

  /// 英検 level string for QuestMapScreen.startLevel.
  /// One of: '5' | '4' | '3' | 'pre2' | 'pre2plus' | '2' | 'pre1'
  final String startEikenLevel;

  /// θ rung index (0..6) — persisted for T12 adaptive difficulty.
  final int placementGrade;

  /// Final θ̂ value — persisted for T12 adaptive difficulty.
  final double placementTheta;

  final String avatarId;
  final int dailyGoalMinutes;

  const OnboardingResult({
    required this.ageYears,
    required this.startEikenLevel,
    required this.placementGrade,
    required this.placementTheta,
    required this.avatarId,
    required this.dailyGoalMinutes,
  });
}

/// Legacy 3-level enum — kept so existing callers (integration test) still
/// compile.  New code uses [OnboardingResult.startEikenLevel] directly.
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
// Avatar data
// ---------------------------------------------------------------------------

class AvatarOption {
  final String id;
  final String emoji;
  final String name;
  final String jobTitle; // RPG class
  final String? asset; // bundled portrait (M5/M6); null → render the emoji

  const AvatarOption({
    required this.id,
    required this.emoji,
    required this.name,
    required this.jobTitle,
    this.asset,
  });
}

// #110 gender-select: the child picks one of the two LOCKED protagonist mains
// (M5「ストリート」/ M6「クラシック」, docs/character/CHARACTER_BIBLE.md). The choice
// is stored as avatarId and drives the grey→colour hero everywhere via HeroChoice.
const List<AvatarOption> _avatars = [
  AvatarOption(
      id: 'm5',
      emoji: '🕵️',
      name: 'ストリート',
      jobTitle: 'たんてい',
      asset: 'assets/art/characters/m5_hero.webp'),
  AvatarOption(
      id: 'm6',
      emoji: '🕵️‍♀️',
      name: 'クラシック',
      jobTitle: 'たんてい',
      asset: 'assets/art/characters/m6_hero.webp'),
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
    case 'たんてい':
      return 'Detective';
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

  // Step 2 — adaptive placement
  PlacementEngine? _engine; // created once age is committed
  PlacementItem? _currentItem; // item being shown
  int? _currentItemBankIdx; // its index in kPlacementBank
  PlacementOutcome? _outcome; // set when engine.done == true

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
      setState(() {
        _step++;
        // Entering placement step — initialise the engine now so the age seed
        // is correct.  The engine itself is pure Dart (no Firebase, no async).
        if (_step == 1 && _engine == null) {
          _engine = PlacementEngine.fromAge(_age);
          _pickNextItem();
        }
      });
      _fadeCtrl.forward();
    });
  }

  /// Pick the next item from the bank and store it (+ its bank index) so the
  /// widget can render it.  Called at the start of placement and after each answer.
  void _pickNextItem() {
    final engine = _engine;
    if (engine == null) return;
    final grade = engine.nextGrade();
    final item = unusedItemForGrade(grade, engine.usedItemIds);
    final idx = bankIndexOf(item);
    _currentItem = item;
    _currentItemBankIdx = idx;
  }

  void _answerItem(bool correct) {
    final engine = _engine;
    final item = _currentItem;
    final idx = _currentItemBankIdx;
    if (engine == null || item == null || idx == null) return;

    engine.usedItemIds.add(idx);
    engine.record(correct, grade: item.grade);

    setState(() {
      if (engine.done) {
        _outcome = engine.result();
        _currentItem = null;
      } else {
        _pickNextItem();
      }
    });
  }

  void _finish() {
    final outcome = _outcome;
    final result = OnboardingResult(
      ageYears: _age,
      startEikenLevel: outcome?.eikenLevel ?? '5',
      placementGrade: outcome?.grade ?? 0,
      placementTheta: outcome?.theta ?? 0.0,
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
        final outcome = _outcome;
        if (outcome != null) {
          return _PlacementResult(outcome: outcome, onNext: _nextStep);
        }
        final item = _currentItem;
        final engine = _engine;
        if (item == null || engine == null) return const SizedBox.shrink();
        return _StepPlacement(
          item: item,
          itemNumber: engine.n + 1,
          onAnswer: _answerItem,
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
          outcome: _outcome,
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
              // Flavor-aware: aken → "A-KEN Quest", edilab → "ENG Quest".
              // Was a hardcoded "ENG Quest" (old codename) shown even on the
              // commercial build — the first screen after Start (#25, UX P1).
              '${FlavorConfig.instanceOrNull?.appName ?? 'A-KEN Quest'} へようこそ',
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
                  speaker: '賢者（けんじゃ） / Sage',
                  child: Text(
                    'ようこそ、勇者（ゆうしゃ）よ。旅（たび）をはじめる前（まえ）に、'
                    'いくつか たずねたいことがある。\nそなたは 何才（なんさい）かな？',
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
                        style:
                            dqText(size: 56, w: FontWeight.w800, color: dqGold),
                      ),
                      TextSpan(
                        text: '  さい',
                        style: dqText(size: 20, color: dqInk),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 10),
                // Large tappable −/+ steppers instead of a thin slider: a young
                // child (and a parent) can hit ≥48dp buttons, whereas a slider
                // thumb demands fine motor control they don't have (§H audit).
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _AgeStepButton(
                      icon: Icons.remove_rounded,
                      onTap: age > 4 ? () => onAgeChanged(age - 1) : null,
                    ),
                    const SizedBox(width: 44),
                    _AgeStepButton(
                      icon: Icons.add_rounded,
                      onTap: age < 18 ? () => onAgeChanged(age + 1) : null,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('（4さい 〜 18さい）',
                    textAlign: TextAlign.center,
                    style: dqText(size: 11, color: dqInk.withAlpha(150))),
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

/// A large (≥48dp) circular −/+ button for the age stepper. [onTap] null = the
/// limit (4 or 18) is reached → muted/disabled.
class _AgeStepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _AgeStepButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: enabled
              ? const LinearGradient(colors: [dqGold, dqGoldDeep])
              : null,
          color: enabled ? null : dqNight1,
          border: Border.all(color: dqBorder, width: 2),
        ),
        child: Icon(icon,
            color: enabled ? const Color(0xFF2A1C00) : dqInk.withAlpha(80),
            size: 30),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2a: Adaptive placement question — DQ command-window quiz.
// ---------------------------------------------------------------------------

class _StepPlacement extends StatelessWidget {
  final PlacementItem item;

  /// 1-based item number (displayed as "Question N").
  final int itemNumber;

  final void Function(bool isCorrect) onAnswer;

  const _StepPlacement({
    required this.item,
    required this.itemNumber,
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
              'えいごチェック $itemNumber',
              'Placement Q$itemNumber',
              jpSize: 15,
              jpColor: dqInk,
              align: TextAlign.center,
            ),
          ),
          const SizedBox(height: 22),
          DqDialogBox(
            speaker: '賢者（けんじゃ） / Sage',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  item.stemEn,
                  style: dqText(size: 17, w: FontWeight.w700, color: dqInk),
                ),
                if (item.stemJa != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.stemJa!,
                    style: dqText(size: 13, color: dqInk, w: FontWeight.w400),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 26),
          ...List.generate(item.choices.length, (i) {
            return DqChoice(
              label: item.choices[i],
              showCursor: true,
              onTap: () => onAnswer(i == item.correctIndex),
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

/// Maps [PlacementOutcome.eikenLevel] to a human-readable 英検 grade label.
String _eikenLabel(String level) {
  switch (level) {
    case '5':
      return '英検5級 (A1)';
    case '4':
      return '英検4級 (A1)';
    case '3':
      return '英検3級 (A1+)';
    case 'pre2':
      return '英検準2級 (A2)';
    case 'pre2plus':
      return '英検準2級プラス (A2+)';
    case '2':
      return '英検2級 (B1)';
    case 'pre1':
      return '英検準1級 (B2)';
    default:
      return '英検5級';
  }
}

/// Human-readable confidence label.
String _confidenceLabel(PlacementConfidence c) {
  switch (c) {
    case PlacementConfidence.high:
      return '自信あり ★★★';
    case PlacementConfidence.medium:
      return '自信あり ★★';
    case PlacementConfidence.low:
      return '自信あり ★';
  }
}

class _PlacementResult extends StatelessWidget {
  final PlacementOutcome outcome;
  final VoidCallback onNext;

  const _PlacementResult({required this.outcome, required this.onNext});

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
                    _eikenLabel(outcome.eikenLevel),
                    style: dqText(size: 24, w: FontWeight.w800, color: dqGold),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  outcome.cefr,
                  style:
                      dqText(size: 18, w: FontWeight.w700, color: dqGoldDeep),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _confidenceLabel(outcome.confidence),
                  style: dqText(size: 12, color: dqInk, w: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          DqDialogBox(
            speaker: '賢者（けんじゃ） / Sage',
            child: Text(
              'よし、そなたの ちからは わかった。\nさあ、旅（たび）の仲間（なかま）を えらぼう。',
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
              '仲間（なかま）を選（えら）ぼう',
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
              crossAxisCount: 2, // two locked mains, M5 / M6 (#110)
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.82,
              children: avatars.map((av) {
                final selected = av.id == selectedId;
                return _AvatarCard(
                  avatar: av,
                  selected: selected,
                  // #133: a non-reading 4–7yo hears the detective's name spoken
                  // as they tap to choose (m5/m6 clips); selection still happens.
                  onTap: () {
                    NavSpeak.speak(av.id);
                    onSelected(av.id);
                  },
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
                      color: Colors.black54,
                      blurRadius: 6,
                      offset: Offset(0, 3))
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (avatar.asset != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  avatar.asset!,
                  height: selected ? 110 : 100,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      DqPortrait(emoji: avatar.emoji, size: selected ? 46 : 42),
                ),
              )
            else
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
  final PlacementOutcome? outcome;
  final ValueChanged<int> onGoalChanged;
  final VoidCallback onFinish;

  const _StepGoal({
    required this.goalMinutes,
    required this.avatarId,
    required this.outcome,
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
                  speaker:
                      '${avatar.name} / ${_avatarClassEn(avatar.jobTitle)}',
                  child: Text(
                    '準備（じゅんび）はいい？\n${_eikenLabel(outcome?.eikenLevel ?? '5')} から旅（たび）を はじめよう！',
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
                              ? const LinearGradient(
                                  colors: [dqGold, dqGoldDeep])
                              : null,
                          color: selected ? null : dqNight0.withAlpha(180),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color:
                                selected ? dqBorder : dqGoldDeep.withAlpha(110),
                            width: selected ? 2 : 1.5,
                          ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                      color: dqGold.withAlpha(90),
                                      blurRadius: 8)
                                ]
                              : null,
                        ),
                        child: Column(
                          children: [
                            Text(
                              '$min',
                              style: dqText(
                                size: 22,
                                w: FontWeight.w800,
                                color:
                                    selected ? const Color(0xFF2A1C00) : dqGold,
                              ),
                            ),
                            Text(
                              'min',
                              style: dqText(
                                size: 11,
                                w: FontWeight.w600,
                                color:
                                    selected ? const Color(0xFF2A1C00) : dqInk,
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
                _SummaryRow(
                    jp: 'レベル',
                    en: 'Level',
                    value: _eikenLabel(outcome?.eikenLevel ?? '5')),
                const SizedBox(height: 6),
                _SummaryRow(
                    jp: 'なかま',
                    en: 'Hero',
                    value: '${avatar.emoji} ${avatar.name}'),
                const SizedBox(height: 6),
                _SummaryRow(
                    jp: 'もくひょう', en: 'Goal', value: '毎日 $goalMinutes min'),
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
