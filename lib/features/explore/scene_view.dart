// lib/features/explore/scene_view.dart
// Wave 1 — SceneView: Layton-style explorable painted scene.
//
// A Stack of parallax background layers (Transform shifts on drag) with
// Positioned tappable hotspot targets overlaid. On tap:
//   - NPC: plays clue audio (best-effort) + shows a 「？」bubble. Tapping the
//     bubble navigates to NazoScreen. On correct, the NPC portrait
//     AnimatedCrossFades from grey→color (the restoration payoff).
//   - Coin: plays a coin SFX, adds the coin to HintCoinService, vanishes.
//
// NO dart:io. NO Firebase. Image.asset always has errorBuilder → dq gradient.
// Firebase uid must NOT be used here (see test constraint).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/audio/audio_cue_service.dart';
import '../../core/gamification/hint_coin_service.dart';
import '../../core/sound/sound_service.dart';
import '../quest/ui/dq_ui.dart';
import '../home/streak_service.dart';
import '../exam_practice/practice_encouragement.dart';
import '../../core/gamification/xp_service.dart';
import '../exam_practice/exam_session_rewards.dart';
import '../exam_practice/pass/cse_model.dart';
import '../exam_practice/pass/skill_accuracy_store.dart';
import 'hotspot.dart';
import 'nazo_screen.dart';
import 'scene_fsrs_seeder.dart';
import 'scene_solved_store.dart';

export 'hotspot.dart'
    show
        kTown5Scene,
        kTown4Scene,
        kTown3Scene,
        kTownPre2Scene,
        kTownPre2PlusScene,
        kTown2Scene,
        kTownPre1Scene,
        kScenesByGrade,
        sceneForGrade,
        SceneDef;

/// Saturation [ColorFilter] matrix. `s == 1` → identity (full colour); `s == 0`
/// → greyscale (Rec.709 luma weights). This is the lean-Layton "ことばで世界に色が
/// 戻る" verb (ART-DIRECTION.md §1.2): a scene renders DESATURATED while its ナゾ are
/// unsolved, then the whole plate floods grey→colour on chapter clear — at runtime,
/// reusing the colour plate (no separate _grey asset).
List<double> saturationMatrix(double s) {
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  final ir = (1 - s) * lr, ig = (1 - s) * lg, ib = (1 - s) * lb;
  return <double>[
    ir + s, ig, ib, 0, 0, //
    ir, ig + s, ib, 0, 0, //
    ir, ig, ib + s, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}

/// True when every NPC ナゾ in [scene] is solved (or the scene has none) — i.e. the
/// scene's colour is "restored". Drives the whole-plate grey→colour flood.
bool allNpcsSolved(SceneDef scene, Map<int, bool> solved) {
  for (var i = 0; i < scene.hotspots.length; i++) {
    if (scene.hotspots[i].kind == HotspotKind.npc && solved[i] != true) {
      return false;
    }
  }
  return true;
}

/// (solved, total) NPC ナゾ counts for [scene]. Drives the header progress pill
/// so the child can always see how many of the scene's mysteries remain before
/// its colour is restored — progress visibility, not just a binary all-or-nothing
/// flood (engagement spine: 「あと1つ」). Coins are excluded (they are optional
/// finds, not gated puzzles).
({int solved, int total}) nazoProgress(SceneDef scene, Map<int, bool> solved) {
  var total = 0;
  var done = 0;
  for (var i = 0; i < scene.hotspots.length; i++) {
    if (scene.hotspots[i].kind == HotspotKind.npc) {
      total++;
      if (solved[i] == true) done++;
    }
  }
  return (solved: done, total: total);
}

/// Scene saturation earned by progress: the muted [floor] when nothing is solved,
/// rising linearly to full colour (1.0) as [solved]/[total] reaches 1 — so every
/// ナゾ restored floods a little more colour in rather than one terminal flip.
/// [total] <= 0 (a scene with no ナゾ) → already fully alive (1.0). Pure + public
/// so the "world wakes up as you solve" formula is unit-tested.
double progressiveSaturation(int solved, int total, double floor) {
  if (total <= 0) return 1.0;
  final frac = (solved / total).clamp(0.0, 1.0);
  return floor + frac * (1.0 - floor);
}

/// True when hotspot [idx] is the LAST unsolved NPC ナゾ in [scene] — the 対決
/// (confrontation) peak. Pure + public so the climax trigger is unit-tested.
bool isFinalNazoIndex(SceneDef scene, Map<int, bool> solved, int idx) {
  if (idx < 0 ||
      idx >= scene.hotspots.length ||
      scene.hotspots[idx].kind != HotspotKind.npc ||
      solved[idx] == true) {
    return false;
  }
  var unsolved = 0;
  for (var i = 0; i < scene.hotspots.length; i++) {
    if (scene.hotspots[i].kind == HotspotKind.npc && solved[i] != true) {
      unsolved++;
    }
  }
  return unsolved == 1;
}

/// Minimum observation hotspots a child must have READ before the final ナゾ
/// (対決/confrontation) unlocks. Gates the climax behind evidence-gathering so
/// observation hotspots are meaningful evidence rather than three independent quiz
/// booths. SAFETY: the gate is skipped when a scene has fewer than this many
/// observation hotspots (no soft-lock; see [_onBubbleTap]).
const int kFinalNazoObsRequired = 2;

class SceneView extends StatefulWidget {
  final SceneDef scene;

  /// The 英検 level string for this scene (drives ミノス + hint text).
  final String eikenLevel;

  /// Design-audit only (?preview=exploresolved): start with every NPC ナゾ solved so
  /// the restored/colour state + the 探偵メモ re-read badge can be screenshot-audited
  /// (the live solved-state otherwise needs a play-through). No effect on real play.
  final bool previewAllSolved;

  const SceneView({
    super.key,
    required this.scene,
    this.eikenLevel = '5',
    this.previewAllSolved = false,
  });

  @override
  State<SceneView> createState() => _SceneViewState();
}

class _SceneViewState extends State<SceneView> with TickerProviderStateMixin {
  // ── State ─────────────────────────────────────────────────────────────────

  /// One-shot scene-entry cinematic (#83 / game-studio #5): the painted scene
  /// used to HARD-CUT in. It now settles in — a subtle scale-down (1.035→1.0) +
  /// fade over ~1.4s — so each case opens like a camera arriving, not a jump cut.
  /// Scale (not a parallax drift) so it stays coherent with the hotspots and never
  /// reveals an edge gap on the full-bleed background. Reduced-motion → instant.
  late final AnimationController _entryCtrl;

  // NPC solve state: hotspot index → solved bool
  final Map<int, bool> _solved = {};

  // Coin found state: hotspot index → found bool
  final Map<int, bool> _coinFound = {};
  // Investigated observation hotspots (#124): persisted so the lore dot settles
  // to a 探偵メモ marker (?→✓) and stays read across sessions.
  final Map<int, bool> _observed = {};

  // Which NPC index currently shows a 「？」speech-bubble (null = none)
  int? _bubbleIndex;

  // Coin balance (shown in HUD after collecting)
  int _coinBalance = 0;

  /// Running ミノス earned THIS scene session — accumulates [NazoResult.
  /// minosEarned] (previously discarded) and counts up in the header after each
  /// solve. #86 (game-studio #6): the scene loop had no between-puzzle reward
  /// accumulator, so no 「あと1問」 pull; this makes each solve visibly add up.
  int _sessionMinos = 0;

  // Parallax offset driven by pan gesture. A ValueNotifier (NOT setState) so a
  // drag updates ONLY the background layers via a ValueListenableBuilder — the
  // hotspot loop (Image+ClipOval+AnimatedCrossFade × N) is a sibling in the outer
  // Stack and must NOT rebuild ~60×/s during the pan (perf #134).
  final ValueNotifier<double> _parallax = ValueNotifier<double>(0.0);
  static const _parallaxMaxShift = 0.04; // fraction of container width

  /// Saturation FLOOR of an unsolved scene — muted "the world lost its words"
  /// grade, NOT dead grey (s=0 reads as a broken image). Raised 0.35→0.48 (studio
  /// art-direction): 0.35 read as washed-out/broken; 0.48 is unmistakably an
  /// intentional "under-the-spell" grade while still leaving a felt colour gain.
  static const _kMutedSaturation = 0.48;

  /// Progressive saturation: the village regains colour as EACH ナゾ is solved,
  /// not in one terminal all-or-nothing flip — every restored word brings the
  /// world a bit back to life ("ことばで世界に色が戻る"). This was the convergent #1
  /// recommendation of three studio experts (exploration, game-feel, art): the
  /// app's defining verb becomes a felt, incremental reward arc. Floor = muted;
  /// reaches full colour (1.0) only when every ナゾ is solved. No ナゾ → already alive.
  double get _targetSaturation {
    final p = nazoProgress(widget.scene, _solved);
    return progressiveSaturation(p.solved, p.total, _kMutedSaturation);
  }

  /// Whether the タロ companion arrival banner is currently visible.
  /// True on entry when [SceneDef.companionArrivalJa] is present; set to false
  /// immediately on tap or after [_kArrivalAutoDismissMs] milliseconds.
  bool _showArrival = false;

  /// Auto-dismiss delay for the arrival banner.  Long enough to read 2 lines
  /// of ひらがな at a child's pace; short enough not to block exploration.
  static const _kArrivalAutoDismissMs = 4500;

  /// Timer handle for the arrival banner auto-dismiss.  Cancelled in dispose
  /// so no pending-timer leaks occur (important for widget tests).
  Timer? _arrivalTimer;

  /// The サイレント lore fragment currently dripping (COMPOSITION §3) — set after a
  /// non-clearing solve of a hotspot that carries [Hotspot.mysteryFragmentJa],
  /// auto-dismissed like the arrival banner. Null → no beat visible.
  String? _loreFragment;
  Timer? _loreTimer;

  /// The NPC hotspot index whose colour just returned — drives a one-shot gold
  /// restore-glow so the game's defining verb ("ことばで世界に色が戻る") FEELS magical
  /// at the moment of solving, not just a quiet cross-fade. Cleared after the
  /// glow finishes. Null → no glow.
  int? _restoringIdx;
  Timer? _restoreTimer;
  // Witnessed restoration (studio re-audit #1): the colour-return is the game's
  // thesis but was perceptually invisible (4 ambient anims, nothing directing the
  // eye). _focusIdx + _restoreCtrl drive a brief CAMERA-PUSH on the just-restored
  // NPC so the child's eye snaps to "THIS villager came alive because I answered".
  int? _focusIdx;
  late final AnimationController _restoreCtrl;
  Timer? _focusTimer;

  /// Witnessed-victory beat (game-studio re-audit, CEO 1755 game⇄learning link):
  /// the colour-restoration is the moment the child's CORRECT ANSWER (learning)
  /// becomes the GAME payoff — but it fired silently behind their attention. A
  /// named restoration line ("〈NPC〉：ことばが… もどってきた！") now pops in when they
  /// return from the solved ナゾ, so the win is SEEN and tied to the person they
  /// helped. Lingers ~2.2s (long enough to read), then clears. Null → none.
  String? _restoreLabel;
  Timer? _restoreLabelTimer;

  // ── Held-restoration hero frame (game-studio #2) ─────────────────────────
  // When a ナゾ is solved (non-reduced-motion), a HELD RESTORATION FRAME plays:
  //   1. Full-bleed dim overlay (0→0.6→0 alpha) so the busy scene recedes.
  //   2. The just-restored NPC's colour portrait scales up to 2.2× at screen
  //      centre (easeOutBack 420ms), holds 900ms, then settles back (easeInOut
  //      380ms) — ~1700ms total.
  //   3. The restoration text appears centred below the hero portrait during hold.
  //   4. The §3 lore fragment fires ONLY AFTER the hero settles (~1700ms delay).
  // Reduced-motion → none of this; existing instant restore + top banner kept.
  late final AnimationController _heroCtrl;

  /// The hotspot index whose COLOUR portrait is currently the hero.
  /// Null → no hero frame running.
  int? _heroNpcIdx;

  /// Whether the full-bleed dim overlay is visible.
  bool _dimActive = false;

  // ── Forward-pull beat (game-studio #3) ───────────────────────────────────
  // When a non-final ナゾ is solved (remaining >= 1), タロ delivers a diegetic
  // "あとNつ！" line after the hero+lore beats, creating a variable-ratio pull
  // toward the next mystery (the same mechanic Battle has).  Null → no beat.
  String? _forwardPullText;
  Timer? _forwardPullTimer;

  // Services
  final _cue = AudioCueService();
  final _sound = SoundService();
  late final HintCoinService _coins;

  @override
  void initState() {
    super.initState();
    _restoreCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    // Hero-frame controller: 420ms up + 900ms hold + 380ms down = 1700ms total.
    // The Animation curve logic lives in _heroScaleCurve (driven by value 0→1).
    _heroCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    // Forward after the first frame so MediaQuery (reduced-motion) is available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (prefersReducedMotion(context)) {
        _entryCtrl.value = 1.0; // skip the entry settle
      } else {
        _entryCtrl.forward();
      }
    });
    _coins = HintCoinService();
    _loadCoinBalance();
    if (widget.previewAllSolved) {
      // Design-audit: seed every NPC ナゾ as solved (full-colour + memo badges).
      for (var i = 0; i < widget.scene.hotspots.length; i++) {
        if (widget.scene.hotspots[i].kind == HotspotKind.npc) _solved[i] = true;
      }
    } else {
      // _restoreSolved loads the cleared state THEN decides the arrival greeting —
      // the "this place lost its words" intro must not replay on a restored scene.
      _restoreSolved();
    }
  }

  /// Show タロ's arrival greeting, gated on scene state (N8 reactivity): the
  /// "lost its words" intro plays only when the scene is NOT already restored —
  /// re-entering a solved case would otherwise contradict its full colour.
  void _maybeGreet() {
    if (widget.scene.companionArrivalJa == null) return;
    // A restored case stays in colour → no "lost its words" loss intro.
    if (allNpcsSolved(widget.scene, _solved)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _showArrival = true);
      _arrivalTimer = Timer(
        const Duration(milliseconds: _kArrivalAutoDismissMs),
        () {
          if (mounted) setState(() => _showArrival = false);
        },
      );
    });
  }

  /// Dismiss the タロ arrival banner immediately (tap handler).
  void _dismissArrival() {
    if (_showArrival) setState(() => _showArrival = false);
  }

  /// Restore which ナゾ were already solved so the world the child coloured in
  /// STAYS coloured across sessions (#115) — no silent re-greying overnight.
  /// Also restores collected coins so a child can't re-enter and re-farm the
  /// same coin for unlimited hint coins.
  Future<void> _restoreSolved() async {
    final solved = await SceneSolvedStore.solvedIndices(widget.eikenLevel);
    final coins =
        await SceneSolvedStore.collectedCoinIndices(widget.eikenLevel);
    final observed =
        await SceneSolvedStore.seenObservationIndices(widget.eikenLevel);
    // Restore hint tiers the child already PAID for so a reopened ナゾ keeps them
    // even across a full app-restart (#155). Not part of the render, so it needs
    // no setState — it only seeds the next NazoScreen on open.
    _hintTierByHotspot
        .addAll(await SceneSolvedStore.hintTiers(widget.eikenLevel));
    if (!mounted) return;
    if (solved.isNotEmpty || coins.isNotEmpty || observed.isNotEmpty) {
      setState(() {
        for (final idx in solved) {
          _solved[idx] = true;
        }
        for (final idx in coins) {
          _coinFound[idx] = true;
        }
        for (final idx in observed) {
          _observed[idx] = true;
        }
      });
    }
    // Cleared-state is now known → decide タロ's arrival greeting (N8 reactivity).
    _maybeGreet();
  }

  Future<void> _loadCoinBalance() async {
    final b = await _coins.balance();
    if (mounted) setState(() => _coinBalance = b);
  }

  @override
  void dispose() {
    _restoreCtrl.dispose();
    _heroCtrl.dispose();
    _focusTimer?.cancel();
    _entryCtrl.dispose();
    _arrivalTimer?.cancel();
    _loreTimer?.cancel();
    _restoreTimer?.cancel();
    _restoreLabelTimer?.cancel();
    _forwardPullTimer?.cancel();
    _cue.dispose();
    _parallax.dispose();
    super.dispose();
  }

  // ── Parallax ──────────────────────────────────────────────────────────────

  void _onPanUpdate(DragUpdateDetails d) {
    // No setState: update the notifier so ONLY the ValueListenableBuilder around
    // the background layers rebuilds — not the whole scene (incl. the hotspots).
    // Drag right → layers drift left (negative shift for near, less for far).
    _parallax.value = (_parallax.value + d.delta.dx * 0.0008)
        .clamp(-_parallaxMaxShift, _parallaxMaxShift);
  }

  void _onPanEnd(DragEndDetails _) {
    // Reset to centre (same instant return as before, no setState).
    _parallax.value = 0.0;
  }

  // ── Hotspot interactions ──────────────────────────────────────────────────

  void _onHotspotTap(int idx) {
    final h = widget.scene.hotspots[idx];
    if (h.kind == HotspotKind.coin) {
      if (_coinFound[idx] == true) return;
      // Discovery beat (not a silent pickup): show タロ's authored clue first —
      // notice → discover → collect, the only real "find something" verb in the
      // world. Collection happens on the bubble's 「ひろう」 tap (_onBubbleTap).
      setState(() => _bubbleIndex = (_bubbleIndex == idx) ? null : idx);
      _cue.play(null); // best-effort discovery chirp (no asset yet → no-op)
    } else if (h.kind == HotspotKind.npc) {
      _tapNpc(idx, h);
    } else if (h.kind == HotspotKind.observation) {
      // #90 Layton "tap → something happens": an observation reveals a 探偵メモ line
      // (no puzzle). Re-tappable; shown via the existing lore-banner beat. On the
      // FIRST investigation persist "seen" so the dot settles to a marker and the
      // child can tell read from unread spots across sessions (#124).
      if (h.clueLineJa != null) {
        if (_observed[idx] != true) {
          setState(() => _observed[idx] = true);
          SceneSolvedStore.markObservationSeen(widget.eikenLevel, idx);
        }
        _cue.play(null);
        _showLore(h.clueLineJa!);
      }
    }
  }

  void _tapNpc(int idx, Hotspot h) {
    // A colour-restored NPC is NOT a dead end (game-studio finding): tapping a
    // villager you already helped re-opens their bubble so the child can re-hear
    // the story fragment they recovered — the world stays responsive and the
    // authored lore (shown once as a fleeting banner) becomes re-readable. Both
    // solved and unsolved NPCs toggle a bubble; the bubble's CONTENT differs.
    if (h.clueLineJa != null) {
      // Audio asset not available yet (generated separately); best-effort no-op.
      _cue.play(null);
    }
    setState(() {
      _bubbleIndex = (_bubbleIndex == idx) ? null : idx;
    });
  }

  void _onBubbleTap(int idx) {
    final h = widget.scene.hotspots[idx];
    if (h.kind == HotspotKind.coin) {
      // The discovery payoff: collect on the 「ひろう」 tap.
      setState(() => _bubbleIndex = null);
      _collectCoin(idx, h);
      return;
    }
    // A solved NPC's bubble is a re-readable memory, not a puzzle — tapping it
    // (or its 「とじる」) just dismisses; there is no ナゾ to re-open.
    if (_solved[idx] == true || h.step == null) {
      setState(() => _bubbleIndex = null);
      return;
    }
    // ── Evidence gate: the final ナゾ (対決) requires the child to have read at
    // least [kFinalNazoObsRequired] observation notes first, so hotspots become
    // EVIDENCE that unlocks the confrontation rather than independent quiz booths
    // (studio rank #6 — cross-hotspot deduction loop). The gate is skipped when the
    // scene has fewer observation hotspots than the threshold (no soft-lock).
    // _observed is seeded from persistence in _restoreSolved(), so a returning child
    // who already explored is never re-gated.
    if (isFinalNazoIndex(widget.scene, _solved, idx)) {
      final obsCount = widget.scene.hotspots
          .where((hs) => hs.kind == HotspotKind.observation)
          .length;
      if (obsCount >= kFinalNazoObsRequired) {
        final seenObs = _observed.values.where((seen) => seen == true).length;
        if (seenObs < kFinalNazoObsRequired) {
          // Not enough evidence yet — dismiss the bubble and show the gate prompt.
          setState(() => _bubbleIndex = null);
          _showLore(
            'まだ てがかりが たりない。'
            'このまちを もっと しらべてみよう。'
            '（てがかり $seenObs/$kFinalNazoObsRequired）',
          );
          return;
        }
      }
    }
    setState(() => _bubbleIndex = null);
    _openNazo(idx, h);
  }

  /// A thematic "enter the mystery" route: the ナゾ fades in with a subtle
  /// zoom — a deliberate beat that frames the puzzle as a case to investigate,
  /// instead of the abrupt default page push (#51 game-feel). Reduced-motion →
  /// instant (no transition) for vestibular/seizure-sensitive children.
  Route<NazoResult> _nazoRoute(Widget child) {
    final reduce = prefersReducedMotion(context);
    return PageRouteBuilder<NazoResult>(
      transitionDuration:
          reduce ? Duration.zero : const Duration(milliseconds: 320),
      reverseTransitionDuration:
          reduce ? Duration.zero : const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => child,
      transitionsBuilder: (_, anim, __, c) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
            child: c,
          ),
        );
      },
    );
  }

  /// Hint tier already unlocked per hotspot THIS scene session (idx → tier). A
  /// reopened ナゾ is seeded with this so the child keeps the hints they already
  /// paid for (#155): the coin spend is durable, but the reveal lived only in the
  /// NazoScreen State and was lost when an unsolved puzzle was closed + reopened.
  final Map<int, int> _hintTierByHotspot = {};

  Future<void> _openNazo(int idx, Hotspot h) async {
    // Deduction spine (studio run-2 #5): when this IS the final ナゾ (対決),
    // collect the clue lines from every observation hotspot the child has already
    // read (_observed[i]==true) and pass them to NazoScreen as a 探偵メモ block
    // so the confrontation reads as evidence-led deduction, not an anonymous quiz.
    String? gatheredCluesJa;
    if (isFinalNazoIndex(widget.scene, _solved, idx)) {
      final clues = <String>[];
      for (var i = 0; i < widget.scene.hotspots.length; i++) {
        final hs = widget.scene.hotspots[i];
        if (hs.kind == HotspotKind.observation &&
            _observed[i] == true &&
            hs.clueLineJa != null &&
            hs.clueLineJa!.isNotEmpty) {
          clues.add('・${hs.clueLineJa!.trim()}');
        }
      }
      if (clues.isNotEmpty) {
        gatheredCluesJa = clues.join('\n');
      }
    }
    final result = await Navigator.of(context).push<NazoResult>(
      _nazoRoute(
        NazoScreen(
          hotspot: h,
          eikenLevel: widget.eikenLevel,
          hintCoinService: _coins,
          initialHintsShown: _hintTierByHotspot[idx] ?? 0,
          sceneBackgroundAsset: widget.scene.backgroundAsset,
          gatheredCluesJa: gatheredCluesJa,
        ),
      ),
    );
    if (!mounted) return;
    // Remember the paid-for hint tier so a reopen restores it instead of charging
    // again. idx is stable for the scene session; a solved hotspot short-circuits
    // before it can reopen, so this only matters for unsolved (dismissed) puzzles.
    // Persist it too (#155) so it survives a full app-restart, not just this session.
    if (result != null && result.hintsShown > (_hintTierByHotspot[idx] ?? 0)) {
      _hintTierByHotspot[idx] = result.hintsShown;
      SceneSolvedStore.markHintTier(widget.eikenLevel, idx, result.hintsShown);
    }
    if (result != null && result.solved) {
      // Witnessed restoration (studio #1): apply the grey→colour restore AFTER the
      // ナゾ exit transition (220ms) finishes, so the child is back in the scene to
      // SEE the signature colour-return — today it fired during the unseen
      // transition. Reduced-motion keeps the instant restore.
      if (prefersReducedMotion(context)) {
        _applyRestore(idx, h, result);
      } else {
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted) _applyRestore(idx, h, result);
        });
      }
    }
  }

  Future<void> _applyRestore(int idx, Hotspot h, NazoResult result) async {
    final wasRestored = _sceneRestored;
    setState(() {
      _solved[idx] = true;
      _restoringIdx = idx; // one-shot gold glow on the restored NPC
      _sessionMinos += result.minosEarned; // #86 reward accumulator
    });
    // Clear the glow flag once it has played, so it never re-glows on rebuild.
    _restoreTimer?.cancel();
    _restoreTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _restoringIdx = null);
    });
    // Persist so the restored colour survives the next session (#115).
    SceneSolvedStore.markSolved(widget.eikenLevel, idx);
    _sound.playCorrect();
    // Completion payoff: when THIS solve restores the whole scene (grey→colour
    // flood), give a "case closed" beat so the world earns a return visit —
    // not just a silent saturation tween (#115). Only on the live transition.
    final justCleared = !wasRestored && _sceneRestored;
    // Build the restoration line (used in hero frame AND reduced-motion banner).
    final String? restorationLine = justCleared
        ? null
        : () {
            final name =
                h.kind == HotspotKind.npc ? (h.step?.npcName.trim() ?? '') : '';
            final who = name.isNotEmpty ? '$name：' : '';
            // Mastery-reflected reward (2026 SOTA): a FIRST-TRY solve earns a
            // 「かんぺき！」 flourish. No-scold: a retried solve still earns the FULL
            // restoration, just without the perfect badge.
            const tail = 'ことばが… もどってきた！';
            return result.firstTryCorrect ? '🌟 かんぺき！ $who$tail' : '$who$tail';
          }();
    // Forward-pull beat (game-studio #3): compute the remaining ナゾ count AFTER
    // this solve (_solved already updated above).  justCleared → remaining == 0
    // → no pull (the cleared modal handles that). The language escalates naturally
    // as remaining decrements (あと3つ→あと1つ), giving variable-ratio acceleration
    // without a randomizer.  Side-effect: lore state is ALWAYS recorded (see
    // _showLore call below) even when the pull replaces the visible lore banner.
    final progress = nazoProgress(widget.scene, _solved);
    final remaining = progress.total - progress.solved;
    final String? forwardPullLine = (!justCleared && remaining >= 1)
        ? (remaining >= 2
            ? 'あと $remainingつ！ このまちの ことばを、とりもどそう！'
            : 'あと 1つ！ さいごの なぞ が まっている——')
        : null;
    // Fire all fire-and-forget side effects BEFORE any await, so they are
    // never skipped by an early `if (!mounted) return` guard below.
    // recordExamXp / recordExamAchievements / _recordSkill / seedSceneWords are
    // context-free and must run on every solve regardless of whether justCleared.
    recordExamXp(1);
    recordExamAchievements();
    // …and feed 合格率 with an HONEST signal: record first-try correctness
    // (a ナゾ retries to solve, so 1/1 every time would inflate the meter).
    // Scene ナゾ test vocab/reading 英検 knowledge → EikenSkill.reading.
    _recordSkill(result.firstTryCorrect);
    // Game⇄learning interconnect: seed the rescued words into the FSRS deck
    // so they surface in Battle ("まちで であった ことば"). Fire-and-forget;
    // non-fatal — never breaks the restore flow. Only first-try-correct words
    // are seeded (knewWords). Skip if knewWords is empty (e.g. a retried solve
    // with no first-try correct answers).
    if (result.knewWords.isNotEmpty) {
      seedSceneWords(widget.eikenLevel, result.knewWords);
    }

    if (prefersReducedMotion(context)) {
      // ── Reduced-motion: instant colour swap + static top banner + lore ─────
      // Existing behaviour preserved exactly. No camera-push, no hero overlay,
      // no dim — the colour swap is instant and the text is a static top banner.
      // Forward-pull shown statically after restoration (no animated chaining).
      _focusIdx = null;
      if (justCleared) {
        // Front-door 英検 puzzle solved → feed the home engagement spine (streak
        // + daily-goal). justCleared: use recordExamHabitAndGet to capture the
        // updated StreakState so the payoff dialog can surface the SessionEndHook
        // at the emotional peak (studio run-2 #4). Single call — no double-count.
        final streak = await recordExamHabitAndGet(1);
        if (!mounted) return;
        _showSceneClearedPayoff(streak);
      } else {
        // Non-clearing solve: fire-and-forget habit record (no streak surface needed).
        recordExamHabit(1);
        if (h.mysteryFragmentJa != null) _showLore(h.mysteryFragmentJa!);
        if (restorationLine != null) {
          setState(() => _restoreLabel = restorationLine);
          _restoreLabelTimer?.cancel();
          _restoreLabelTimer = Timer(const Duration(milliseconds: 2200), () {
            if (mounted) setState(() => _restoreLabel = null);
          });
        }
        // Reduced-motion forward-pull: fire after restoration label clears (~2.5s).
        if (forwardPullLine != null) {
          _forwardPullTimer?.cancel();
          _forwardPullTimer = Timer(const Duration(milliseconds: 2500), () {
            if (mounted) _showForwardPull(forwardPullLine);
          });
        }
      }
    } else {
      // ── Non-reduced-motion: HELD RESTORATION FRAME ───────────────────────
      // Studio #2 spec: dim → hero portrait scales to screen centre → hold →
      // settle. The §3 lore fires ONLY AFTER the hero frame (~1700ms).
      // Studio #3 forward-pull fires AFTER the lore has had its moment (~1300ms
      // after lore appears).  Strict beat sequence: hero → lore → forward-pull.
      //
      // Step 1: keep the brief camera-push on the in-scene NPC (studio #1 —
      // retained as a sub-beat; the hero overlay REPLACES the top banner but
      // the camera-push still snaps the eye to the in-scene position first).
      setState(() => _focusIdx = idx);
      _restoreCtrl.forward(from: 0);
      _focusTimer?.cancel();
      _focusTimer = Timer(const Duration(milliseconds: 640), () {
        if (mounted) setState(() => _focusIdx = null);
      });
      // Step 2: launch the hero overlay (dim + enlarged portrait + restore text).
      // Only fires for a non-clearing solve (justCleared uses the modal instead).
      if (!justCleared && restorationLine != null) {
        // Non-clearing solve: fire-and-forget habit record.
        recordExamHabit(1);
        setState(() {
          _heroNpcIdx = idx;
          _dimActive = true;
          _restoreLabel = restorationLine; // displayed inside hero overlay
        });
        _heroCtrl.forward(from: 0);
        // After the hero frame settles (~1700ms): clear hero, fire lore.
        _restoreLabelTimer?.cancel();
        _restoreLabelTimer = Timer(const Duration(milliseconds: 1700), () {
          if (!mounted) return;
          setState(() {
            _heroNpcIdx = null;
            _dimActive = false;
            _restoreLabel = null;
          });
          // Step 3: §3 lore drip — fires ONLY AFTER the hero frame, never
          // simultaneously (was the root of the perceptual invisibility).
          if (h.mysteryFragmentJa != null) _showLore(h.mysteryFragmentJa!);
          // Step 4: forward-pull — fires ~1300ms after the lore appears, so the
          // beat sequence is strictly: hero(1700ms) → lore(shown) → pull(+1300ms).
          // The lore auto-dismisses after _kArrivalAutoDismissMs (4500ms), so the
          // pull fires while lore is still visible then lore dismisses naturally
          // and pull takes over the slot — no overlap with the hero frame.
          if (forwardPullLine != null) {
            _forwardPullTimer?.cancel();
            _forwardPullTimer = Timer(const Duration(milliseconds: 1300), () {
              if (mounted) _showForwardPull(forwardPullLine);
            });
          }
        });
      }
      // justCleared: record habit + capture streak, then show the modal.
      // The await naturally lands us past the current frame (no postFrameCallback
      // needed) while the camera-push/colour-flood animation plays.
      if (justCleared) {
        final streak = await recordExamHabitAndGet(1);
        if (!mounted) return;
        _showSceneClearedPayoff(streak);
      }
    }
  }

  /// Records one front-door ナゾ into 合格率 (SkillAccuracyStore). Fire-and-forget;
  /// storage failures are swallowed and never interrupt the learner.
  void _recordSkill(bool firstTryCorrect) {
    () async {
      try {
        final store = await SkillAccuracyStore.getInstance();
        await store.record(
          grade: widget.eikenLevel,
          skill: EikenSkill.reading,
          correct: firstTryCorrect ? 1 : 0,
          total: 1,
        );
      } catch (_) {
        // Non-fatal: the pass meter simply won't reflect this one puzzle.
      }
    }();
  }

  /// Test seam: invoke the restore payoff for hotspot [idx] directly, bypassing
  /// the NazoScreen navigation. This is the only way to test the hero-frame
  /// path from a widget test without a real Navigator round-trip. Not in the
  /// production call graph — the real entry is [_openNazo] → [_applyRestore].
  @visibleForTesting
  void applyRestoreForTest(int idx, Hotspot h, NazoResult result) =>
      _applyRestore(idx, h, result);

  Future<void> _collectCoin(int idx, Hotspot h) async {
    if (_coinFound[idx] == true) return;
    setState(() => _coinFound[idx] = true);
    // Persist BEFORE awarding so a re-entry can never re-collect this coin even
    // if the award races — the coin is finite (one collect per scene, ever).
    await SceneSolvedStore.markCoinCollected(widget.eikenLevel, idx);
    _sound.playXpGain();
    final newBalance = await _coins.addCoin(h.coinValue);
    if (mounted) setState(() => _coinBalance = newBalance);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  /// Whole-scene colour is "restored" once every ナゾ is solved → the background
  /// plate floods grey→colour (the lean-Layton core verb).
  bool get _sceneRestored => allNpcsSolved(widget.scene, _solved);

  /// One-time "case closed" payoff shown the moment the last ナゾ floods the
  /// scene back to colour (#115). A real beat — not just the silent saturation
  /// tween — so clearing a town feels earned and worth coming back to.
  ///
  /// When [widget.scene.cleared] is non-null, the authored story beat from
  /// kQuestTowns is shown verbatim (G2). A generic fallback covers scenes
  /// whose SceneDef has no authored cleared text.
  /// Drip one サイレント lore fragment as a brief diegetic 探偵メモ banner after a
  /// solve (COMPOSITION §3). Replaces any visible fragment so rapid solves don't
  /// stack, and auto-dismisses on the same cadence as the arrival banner.
  void _showLore(String fragment) {
    _loreTimer?.cancel();
    setState(() => _loreFragment = fragment);
    _loreTimer = Timer(
      const Duration(milliseconds: _kArrivalAutoDismissMs),
      () {
        if (mounted) setState(() => _loreFragment = null);
      },
    );
  }

  void _dismissLore() {
    _loreTimer?.cancel();
    if (_loreFragment != null) setState(() => _loreFragment = null);
  }

  /// Show タロ's diegetic forward-pull line ("あとNつ！…") using the arrival-banner
  /// widget.  Replaces any pending pull or lore so rapid solves don't stack.
  /// Dismisses the lore banner (if still showing) so the beats run strictly in
  /// sequence without an overlap window: the pull OWNS the bottom slot.
  /// Auto-dismisses after ~3.5s (slightly faster than the arrival banner's 4.5s
  /// — the message is shorter and the pull effect lands quickly).
  void _showForwardPull(String line) {
    _forwardPullTimer?.cancel();
    // Dismiss the lore so the pull can take over the bottom slot immediately
    // (lore has already had its ~1.3s moment; this keeps beats strictly sequential).
    _loreTimer?.cancel();
    setState(() {
      _loreFragment = null;
      _forwardPullText = line;
    });
    _forwardPullTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted) setState(() => _forwardPullText = null);
    });
  }

  void _dismissForwardPull() {
    _forwardPullTimer?.cancel();
    if (_forwardPullText != null) setState(() => _forwardPullText = null);
  }

  void _showSceneClearedPayoff(StreakState? streak) {
    // Multi-sensory "case closed" payoff for the moment the village fully wakes
    // up — the colour-flood used to land in SILENCE (studio game-feel/art
    // convergence: the app's biggest moment had no audio/haptic punctuation).
    // The fanfare is mute-gated inside SoundService; the haptic respects
    // reduce-motion (a heavy buzz is a motion cue for sensitive users).
    _sound.playLevelUp();
    if (!prefersReducedMotion(context)) HapticFeedback.heavyImpact();

    // Authored story beat sourced from kQuestTowns[n].cleared via SceneDef.
    // Generic fallback for any scene that has no authored cleared text yet.
    final storyBeat = widget.scene.cleared ??
        'たんていメモ：さいしょの「こえの いし」を とりもどした。\n'
            'タロ：「きみと いっしょなら、つぎの まちも きっと いける！」';

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withAlpha(160),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          decoration: BoxDecoration(
            color: dqBox,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: dqGold, width: 2),
            boxShadow: [BoxShadow(color: dqGold.withAlpha(70), blurRadius: 24)],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // A diegetic "case closed" stamp instead of a generic 🎉 — the
                // game's biggest moment now reads as a detective solving the case
                // (本格 feel + 事件→英検 fusion, #51/#52). Slightly rotated like a
                // real case-file stamp.
                Transform.rotate(
                  angle: -0.06,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    decoration: BoxDecoration(
                      color: dqGold.withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: dqGold, width: 3),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('事件（じけん） 解決（かいけつ）',
                            style: dqText(
                                size: 20, w: FontWeight.w900, color: dqGold)),
                        Text('CASE CLOSED',
                            style: dqText(
                                size: 9,
                                w: FontWeight.w700,
                                color: dqGold.withAlpha(210),
                                spacing: 3)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'この まちに、ことばと いろが もどった！',
                  textAlign: TextAlign.center,
                  style: dqText(size: 17, w: FontWeight.w800, color: dqGold),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: dqNight1,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: dqGoldDeep.withAlpha(120)),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      storyBeat,
                      style:
                          dqText(size: 13, color: dqInk).copyWith(height: 1.6),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Tie the per-case payoff to the meta-mystery collectible: a 解決 ど
                // restores one bookmark — point the child to the 事件簿 (Settings →
                // じけんぼ) where the 7-bookmark sentence assembles (N1/N12 loop).
                Text(
                  '🔖 ことばの しおりが、1まい もどった。\n'
                  '「じけんぼ」で、つながっていく おはなしを たしかめよう。',
                  textAlign: TextAlign.center,
                  style: dqText(size: 11, color: dqGold.withAlpha(220))
                      .copyWith(height: 1.5),
                ),
                // Episodic forward-pull (N6/N12): name the NEXT case so the chapter
                // doesn't end in a vacuum — Layton's "to be continued" hook. On the
                // final chapter (準1級) tease nothing; close the arc instead. Purely
                // narrative — it does NOT navigate (the paywall still gates entry).
                ...(() {
                  final next = nextChapterTitleJa(widget.eikenLevel);
                  return [
                    const SizedBox(height: 12),
                    Text(
                      next != null
                          ? '🗺️ どこかで、また ことばが きえはじめた——\n'
                              'つぎの事件（じけん）：「$next」が きみを まっている。'
                          : '🕯️ すべての事件（じけん）が つながった。\n'
                              'やぶれた おはなしの さいごの 1ページへ——「じけんぼ」で たしかめよう。',
                      textAlign: TextAlign.center,
                      style: dqText(size: 11.5, color: dqInk.withAlpha(210))
                          .copyWith(height: 1.5),
                    ),
                  ];
                })(),
                // Engagement spine: surface the streak / daily-goal the child just
                // earned at the scene-clear emotional peak (#4 studio run-2) — the
                // same SessionEndHook all 5 exam-practice screens show at results.
                if (streak != null) ...[
                  const SizedBox(height: 14),
                  SessionEndHook(streak: streak),
                ],
                const SizedBox(height: 16),
                DqButton(
                  label: 'つづける',
                  onTap: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Pop the scene, passing whether it was fully cleared so callers (map, home)
  /// can advance the quest node without polling Firestore (G2).
  void _popScene() {
    Navigator.of(context).pop(_sceneRestored);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<bool>(
      // Always allow the pop; we intercept only to attach the cleared payload.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _popScene();
      },
      child: Scaffold(
        backgroundColor: dqNight0,
        body: SafeArea(
          child: Column(
            children: [
              _header(),
              Expanded(
                child: ClipRect(
                  child: AnimatedBuilder(
                    animation: _entryCtrl,
                    builder: (_, child) {
                      // #89 re-audit: 3.5% over easeOutCubic was below the
                      // perceptual threshold (~a hard cut). easeOutExpo FRONT-LOADS
                      // the motion and 7% is clearly felt — a camera pushing in then
                      // settling — while ClipRect contains the overscan.
                      final e = Curves.easeOutExpo.transform(_entryCtrl.value);
                      return Opacity(
                        // Floor at 0.2 so the scene (and its hotspots) are never
                        // fully semantics-excluded during the fade.
                        opacity: (0.2 + 0.8 * e).clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: 1.0 + (1 - e) * 0.07, // 1.07 → 1.0 settle
                          child: child,
                        ),
                      );
                    },
                    child: _sceneStack(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        child: Row(
          children: [
            IconButton(
              tooltip: 'もどる / Back',
              onPressed: _popScene,
              icon: const Icon(Icons.arrow_back, color: dqInk),
            ),
            Expanded(
              child: Text(
                widget.scene.titleJa,
                textAlign: TextAlign.center,
                style: dqText(size: 16, w: FontWeight.w800, color: dqGold),
              ),
            ),
            // Running ミノス earned this session — counts up per solve (#86).
            _minosPill(),
            // ナゾ progress pill — how many of the scene's mysteries are solved.
            // Makes progress visible instead of a binary all-done colour flood.
            _nazoProgressPill(),
            // Coin HUD
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('✦',
                      style: TextStyle(color: Color(0xFFFFD700), fontSize: 16)),
                  const SizedBox(width: 3),
                  Text('$_coinBalance', style: dqText(size: 14, color: dqGold)),
                ],
              ),
            ),
          ],
        ),
      );

  /// Running ミノス accumulator (#86): a count-up reward total in the header
  /// that grows after each solve — the between-puzzle 「あと1問」 pull the scene loop
  /// lacked (Battle already has streak/XP). Diamond-cyan to read distinct from the
  /// gold ✦ coins. Hidden until the first ミノス is earned (a reward reveal).
  Widget _minosPill() {
    if (_sessionMinos <= 0) return const SizedBox.shrink();
    const cyan = Color(0xFFB8F0FF);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Semantics(
        label: 'ミノス $_sessionMinos',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(70),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: cyan.withAlpha(120)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.diamond, color: cyan, size: 12),
              const SizedBox(width: 3),
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: _sessionMinos),
                duration: prefersReducedMotion(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 600),
                curve: Curves.easeOut,
                builder: (_, v, __) => Text('$v',
                    style: dqText(size: 13, w: FontWeight.w800, color: cyan)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Compact "ナゾ solved/total" pill shown in the header. Hidden for scenes with
  /// fewer than two ナゾ (a single puzzle needs no progress bar). Turns green with
  /// a check when every ナゾ is solved — the visible "this case is closed" cue
  /// that mirrors the grey→colour restoration. Semantics-labelled for screen
  /// readers / tap-to-speak.
  Widget _nazoProgressPill() {
    final p = nazoProgress(widget.scene, _solved);
    if (p.total < 2) return const SizedBox.shrink();
    final done = p.solved == p.total;
    final color = done ? const Color(0xFF8BE08B) : dqGold;
    return Semantics(
      label: done ? 'ナゾ ぜんぶ クリア' : 'ナゾ ${p.total}こ のうち ${p.solved}こ クリア',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(70),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: color.withAlpha(150)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(done ? Icons.check_circle : Icons.search,
                color: color, size: 14),
            const SizedBox(width: 4),
            Text('${p.solved}/${p.total}',
                style: dqText(size: 13, w: FontWeight.w800, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _sceneStack() {
    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // ── Background / parallax layers ──────────────────────────────
              // The whole plate renders desaturated until the chapter's ナゾ are
              // solved, then floods grey→colour over 2s (ART-DIRECTION §1.2 —
              // "ことばで世界に色が戻る"). Runtime saturation of the colour plate;
              // no separate _grey asset. Built inside the builder so parallax
              // pan still updates each frame.
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  // Floor at a MUTED saturation, not dead grey (s=0): a fully
                  // desaturated painting reads as a broken/missing image (the
                  // very defect class the CEO flagged). A muted "under-the-spell"
                  // grade is unmistakably intentional and the colour-flood payoff
                  // still lands. Restored → full colour.
                  // Progressive: animates to the saturation earned by the ナゾ
                  // solved so far — each solve floods a little more colour in.
                  tween: Tween<double>(
                    begin: _kMutedSaturation,
                    end: _targetSaturation,
                  ),
                  duration: prefersReducedMotion(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 1400),
                  curve: Curves.easeInOut,
                  builder: (context, sat, _) => ColorFiltered(
                    colorFilter: ColorFilter.matrix(saturationMatrix(sat)),
                    // Only this subtree rebuilds/repaints on a parallax pan —
                    // RepaintBoundary keeps the drag off the hotspots' layer.
                    child: RepaintBoundary(
                      child: ValueListenableBuilder<double>(
                        valueListenable: _parallax,
                        builder: (_, parallax, __) => Stack(
                            children: _buildParallaxLayers(w, h, parallax)),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Dark vignette overlay for legibility ──────────────────────
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withAlpha(80),
                        Colors.transparent,
                        Colors.black.withAlpha(130),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),

              // ── Hotspot overlay ───────────────────────────────────────────
              for (var i = 0; i < widget.scene.hotspots.length; i++)
                _hotspotWidget(i, w, h),

              // ── Held-restoration hero frame (game-studio #2) ──────────────
              // Full-bleed dim overlay: sits ABOVE the scene+hotspots so the busy
              // painted scene recedes and the restored NPC portrait is isolated.
              // Animates 0→0.6→0 over the 1700ms hero window.
              if (_dimActive)
                Positioned.fill(
                  key: const ValueKey('hero_dim_overlay'),
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _heroCtrl,
                        builder: (_, __) {
                          // Fade in fast (first 25%), hold, fade out (last 22%).
                          final t = _heroCtrl.value;
                          final alpha = t < 0.247
                              ? (0.74 * (t / 0.247))
                              : t < 0.776
                                  ? 0.74
                                  : 0.74 * (1 - (t - 0.776) / 0.224);
                          return ColoredBox(
                            color: Colors.black.withAlpha(
                                (alpha.clamp(0.0, 1.0) * 255).round()),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              // Hero portrait: the just-restored NPC's COLOUR portrait enlarges
              // to 2.2× at screen centre over the dim.  Two-phase curve:
              //   0 → 420ms  : scale 0→2.2 easeOutBack
              //   420–1320ms  : hold at 2.2 (900ms hold window)
              //   1320–1700ms : scale 2.2→1.0 easeInOut
              // Decoupled overlay — the in-scene portrait keeps its grey→colour
              // crossfade underneath; layout is never disturbed.
              if (_heroNpcIdx != null)
                Positioned.fill(
                  key: const ValueKey('hero_portrait_overlay'),
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _heroCtrl,
                        builder: (_, __) {
                          final t = _heroCtrl.value;
                          // Phase fractions: up=24.7%, hold=52.9%, down=22.4%
                          final double scale;
                          if (t < 0.247) {
                            final s = t / 0.247;
                            scale = Curves.easeOutBack.transform(s) * 2.2;
                          } else if (t < 0.776) {
                            scale = 2.2;
                          } else {
                            final s = (t - 0.776) / 0.224;
                            scale = 2.2 - 1.2 * Curves.easeInOut.transform(s);
                          }
                          // Opacity mirrors the dim: fade with it so the hero
                          // doesn't pop in before the scene has receded.
                          final dimT = t < 0.247 ? t / 0.247 : 1.0;
                          final opacity = dimT.clamp(0.0, 1.0);
                          final hotspot = widget.scene.hotspots[_heroNpcIdx!];
                          final colorAsset = hotspot.npcColorAsset;
                          const heroSize = 120.0; // base size before scale
                          return Center(
                            child: Opacity(
                              opacity: opacity,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Transform.scale(
                                    scale: scale,
                                    child: colorAsset != null
                                        ? _npcPortraitImage(
                                            colorAsset, heroSize)
                                        : Container(
                                            width: heroSize,
                                            height: heroSize,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: dqBox,
                                              border: Border.all(
                                                  color: dqGold, width: 3),
                                            ),
                                            child: Center(
                                              child: Text(
                                                hotspot.step?.npcEmoji ?? '👤',
                                                style: const TextStyle(
                                                    fontSize: 48),
                                              ),
                                            ),
                                          ),
                                  ),
                                  // Restoration line centred below the hero
                                  // portrait — visible during the hold phase.
                                  if (_restoreLabel != null &&
                                      t >= 0.247 &&
                                      t < 0.776) ...[
                                    const SizedBox(height: 16),
                                    Semantics(
                                      liveRegion: true,
                                      label: _restoreLabel!,
                                      excludeSemantics: true,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: dqBox.withAlpha(240),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: dqGold, width: 2),
                                          boxShadow: [
                                            BoxShadow(
                                                color: dqGold.withAlpha(80),
                                                blurRadius: 14),
                                            const BoxShadow(
                                                color: Colors.black54,
                                                blurRadius: 8,
                                                offset: Offset(0, 3)),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text('✨',
                                                style: TextStyle(fontSize: 18)),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                _restoreLabel!,
                                                textAlign: TextAlign.center,
                                                style: dqText(
                                                    size: 14,
                                                    w: FontWeight.w800,
                                                    color: dqGold),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

              // ── Active NPC speech bubble (scene-level so it is TAPPABLE) ────
              if (_bubbleIndex != null) _bubbleOverlay(_bubbleIndex!, w, h),

              // ── タロ companion arrival banner ─────────────────────────────
              // Shown on first entry when SceneDef.companionArrivalJa is set.
              // Tap anywhere on the banner to dismiss; auto-dismissed after
              // _kArrivalAutoDismissMs.  Must not block the scene: it is
              // positioned at the bottom edge and the rest of the scene remains
              // interactive.
              if (_showArrival && widget.scene.companionArrivalJa != null)
                _arrivalBanner(widget.scene.companionArrivalJa!, w, h),

              // §3 per-solve サイレント lore drip — a 探偵メモ beat above the arrival
              // slot. Gated so it never co-renders with the arrival banner.
              if (_loreFragment != null && !_showArrival)
                _loreBanner(_loreFragment!, w, h),

              // Game-studio #3 forward-pull beat: タロ's diegetic "あとNつ！" line.
              // Rendered via the existing _arrivalBanner widget (same placement,
              // same teal border — this IS タロ speaking).  Gated so it never
              // co-renders with the arrival banner, the lore banner, OR the hero
              // overlay (the hero dim is down before the pull ever fires).
              if (_forwardPullText != null &&
                  !_showArrival &&
                  _loreFragment == null &&
                  _heroNpcIdx == null)
                _arrivalBanner(_forwardPullText!, w, h,
                    onDismiss: _dismissForwardPull),

              // Reduced-motion fallback: the static top-centre restoration banner
              // (unchanged from before the hero-frame feature). Only shown when
              // the hero overlay is NOT active — i.e. on the reduced-motion path
              // where _heroNpcIdx is always null.
              if (_restoreLabel != null && _heroNpcIdx == null)
                _restorationBanner(_restoreLabel!, w),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildParallaxLayers(double w, double h, double parallax) {
    final layers = widget.scene.parallaxLayers;
    if (layers.isEmpty) {
      // Single background layer, no parallax.
      return [_backgroundImage(widget.scene.backgroundAsset, 0, w, parallax)];
    }
    // Multiple layers: far layer shifts least, near layer shifts most.
    return [
      for (var i = 0; i < layers.length; i++)
        _backgroundImage(layers[i], i / (layers.length - 1), w, parallax),
    ];
  }

  /// Render one parallax layer. [depthFraction] 0.0 = far (least movement),
  /// 1.0 = near (most movement). Shift is applied via Transform.translate.
  Widget _backgroundImage(
      String asset, double depthFraction, double w, double parallax) {
    final shift = parallax * w * depthFraction * 3;
    return Positioned.fill(
      child: Transform.translate(
        offset: Offset(shift, 0),
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _gradientFallback(),
        ),
      ),
    );
  }

  Widget _gradientFallback() => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [dqNight0, dqNight1, dqNight0],
          ),
        ),
      );

  // ── Hotspot widget ────────────────────────────────────────────────────────

  Widget _hotspotWidget(int idx, double w, double h) {
    final hotspot = widget.scene.hotspots[idx];
    final isSolved = _solved[idx] == true;
    final isCoinFound = _coinFound[idx] == true;
    final isObserved = _observed[idx] == true;

    if (hotspot.kind == HotspotKind.coin && isCoinFound) {
      return const SizedBox.shrink(); // Vanished after collection
    }

    // Position: Alignment → pixel offset.
    final cx = (hotspot.pos.x + 1) / 2 * w;
    final cy = (hotspot.pos.y + 1) / 2 * h;
    final size = hotspot.size * w.clamp(100.0, 480.0);

    return Positioned(
      left: cx - size / 2,
      top: cy - size / 2,
      width: size,
      height: size,
      // a11y: each hotspot is an invisible CanvasKit target — without a label a
      // screen-reader child cannot find or play the 探偵 exploration scene at all.
      // Mark it a named button so it is announced and activatable.
      child: Semantics(
        button: true,
        label: _hotspotSemanticLabel(hotspot, isSolved, isObserved),
        excludeSemantics: true,
        child: GestureDetector(
          onTap: () => _onHotspotTap(idx),
          // Just the hotspot target. The speech bubble is rendered separately at
          // SCENE level (see _bubbleOverlay) so it stays hit-testable — nesting it
          // here overflowed this small GestureDetector's bounds and silently ate
          // the tap (the 「ナゾをみる」-does-nothing bug, CEO 2026-06-09).
          child: switch (hotspot.kind) {
            HotspotKind.coin => _coinTarget(size),
            HotspotKind.observation => _observationTarget(size, isObserved),
            HotspotKind.npc => _npcTarget(idx, hotspot, isSolved, size),
          },
        ),
      ),
    );
  }

  /// a11y label for a scene hotspot — describes the interactive target by kind +
  /// solved state (the Hotspot model carries no per-NPC name, so labels are
  /// generic but clear). Child-facing ひらがな + English.
  String _hotspotSemanticLabel(
      Hotspot hotspot, bool isSolved, bool isObserved) {
    if (hotspot.kind == HotspotKind.coin) {
      return 'ひかる てがかり。タップして しらべる / A shining clue — tap to investigate';
    }
    if (hotspot.kind == HotspotKind.observation) {
      // ?→✓ once investigated so a screen-reader child can tell read from unread
      // spots (the label used to never change — #124).
      return isObserved
          ? 'しらべた メモ。もういちど よめる / A noted clue — tap to re-read'
          : 'なにか ありそう。タップして しらべる / Something here — tap to look';
    }
    return isSolved
        ? 'ナゾ クリアずみ。タップして おはなしを きく / Mystery solved — tap to hear their story'
        : 'ナゾの ぬし。タップして はなしかける / A mystery to solve — tap to talk';
  }

  /// The 「？」speech bubble for the active NPC, rendered at SCENE level (a direct
  /// child of the scene Stack) so its 「ナゾをみる」 button is inside the hit-test
  /// bounds. Positioned just above the NPC and clamped to stay on-screen.
  /// True when [idx] is the LAST unsolved NPC ナゾ — the chapter's 対決
  /// (confrontation) peak. The composition bible places a beat here (Arrival /
  /// 対決 / 解決); we mark this ナゾ as the climax so the final mystery FEELS like
  /// the confrontation, not just another tap (rubric N6).
  bool isFinalNazo(int idx) => isFinalNazoIndex(widget.scene, _solved, idx);

  Widget _bubbleOverlay(int idx, double w, double h) {
    final hotspot = widget.scene.hotspots[idx];
    final solvedNpc = hotspot.kind == HotspotKind.npc && _solved[idx] == true;
    final isFinal = isFinalNazo(idx);
    final cx = (hotspot.pos.x + 1) / 2 * w;
    final cy = (hotspot.pos.y + 1) / 2 * h;
    final size = hotspot.size * w.clamp(100.0, 480.0);
    const bubbleW = 220.0;
    return Positioned(
      left: (cx - bubbleW / 2).clamp(4.0, (w - bubbleW - 4).clamp(4.0, w)),
      bottom: (h - (cy - size / 2) + 6).clamp(4.0, h - 48),
      child: Semantics(
        button: true,
        label: hotspot.kind == HotspotKind.coin
            ? 'てがかりを ひろう / Pick up the clue'
            : solvedNpc
                ? 'おはなしを とじる / Close their story'
                : 'ナゾを みる / Open the mystery',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: () => _onBubbleTap(idx),
          // #82 game-feel: the bubble used to POP in (bare if in the Stack). It now
          // materialises — rises + fades + settles — so "tap NPC → clue appears"
          // reads as a detective beat, not a div toggling. Keyed by idx so switching
          // NPC re-triggers it; reduced-motion → instant.
          child: _EntryAnim(
            key: ValueKey('bubble_$idx'),
            reduceMotion: prefersReducedMotion(context),
            child: solvedNpc
                // A restored villager re-shares the memory you recovered — the lore
                // fragment (shown once as a banner) is re-readable here, on demand.
                ? _speechBubble(
                    hotspot.mysteryFragmentJa ?? 'ありがとう、たんていさん。\nことばが もどってきたよ。',
                    ctaLabel: '✓ とじる',
                  )
                : _speechBubble(
                    // 対決 beat: the final mystery is framed as the confrontation.
                    isFinal
                        ? '⚔️ さいごの ナゾ。この まちの しずけさの、いちばん ふかい ところ。\n'
                            '${hotspot.clueLineJa ?? ''}'
                        : hotspot.clueLineJa,
                    ctaLabel: isFinal ? '⚔️ 対決（たいけつ）する' : '「？」ナゾをみる',
                  ),
          ),
        ),
      ),
    );
  }

  /// Companion arrival banner: タロ speaks a short in-character line on scene
  /// entry.  Positioned at the bottom of the scene, full-width but short, with
  /// a teal accent border matching タロ's dominant hue (CHARACTER-BIBLE §3 —
  /// dusty teal #5DA9E9).  Tap anywhere to dismiss.
  ///
  /// [onDismiss] overrides the default [_dismissArrival] handler so the same
  /// widget can be reused for the forward-pull beat (game-studio #3) with a
  /// distinct dismiss action.
  Widget _arrivalBanner(String text, double w, double h,
      {VoidCallback? onDismiss}) {
    return Positioned(
      left: 12,
      right: 12,
      bottom: 16,
      // a11y: a transient overlay banner is SILENT to a screen reader unless it
      // is a liveRegion — announce タロ's arrival line the moment it appears so a
      // low-vision child perceives the companion beat (it auto-dismisses anyway).
      child: _EntryAnim(
        key: const ValueKey('arrival_banner'),
        reduceMotion: prefersReducedMotion(context),
        child: Semantics(
          liveRegion: true,
          label: 'タロ。$text',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: onDismiss ?? _dismissArrival,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: dqBox.withAlpha(235),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  // タロ's canonical dusty-teal #5DA9E9 (CHARACTER-BIBLE dominant hue)
                  color: const Color(0xFF5DA9E9),
                  width: 2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // タロ slime icon
                  const Text('🟢', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'タロ',
                          style: dqText(
                            size: 11,
                            w: FontWeight.w700,
                            color: const Color(0xFF5DA9E9),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          text,
                          style: dqText(size: 13, color: dqInk)
                              .copyWith(height: 1.55),
                        ),
                      ],
                    ),
                  ),
                  // Dismiss hint
                  const Padding(
                    padding: EdgeInsets.only(left: 4, top: 2),
                    child: Text(
                      'タップで とばす',
                      style: TextStyle(
                        fontSize: 9,
                        color: Color(0xFF8899AA),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Witnessed-victory restoration beat: a top-centre gold banner that pops in
  /// naming the villager the child's correct answer just restored — the moment the
  /// LEARNING outcome becomes the visible GAME payoff (game⇄learning, CEO 1755).
  /// liveRegion so a low-vision child hears the win. Auto-clears after ~2.2s.
  Widget _restorationBanner(String text, double w) {
    return Positioned(
      top: 12,
      left: 16,
      right: 16,
      child: _EntryAnim(
        key: ValueKey('restore_$text'),
        reduceMotion: prefersReducedMotion(context),
        child: Semantics(
          liveRegion: true,
          label: text,
          excludeSemantics: true,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: dqBox.withAlpha(240),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: dqGold, width: 2),
                boxShadow: [
                  BoxShadow(color: dqGold.withAlpha(80), blurRadius: 14),
                  const BoxShadow(
                      color: Colors.black54,
                      blurRadius: 8,
                      offset: Offset(0, 3)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('✨', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(text,
                        textAlign: TextAlign.center,
                        style: dqText(
                            size: 14, w: FontWeight.w800, color: dqGold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// §3 per-solve lore beat. Same placement/cadence as the arrival banner but a
  /// distinct 探偵メモ identity — gold (dqGold), 🔖 bookmark icon — so a clue reads
  /// as the unfolding サイレント mystery, not タロ chatter. Tap anywhere to dismiss.
  Widget _loreBanner(String text, double w, double h) {
    return Positioned(
      left: 12,
      right: 12,
      bottom: 16,
      // a11y: announce the 探偵メモ lore drip via a liveRegion so a low-vision
      // child perceives the §3 サイレント mystery beat, not just the painted banner.
      child: _EntryAnim(
        // Key by the fragment TEXT, not a const: a const key let a second lore
        // fragment (rapid sequential solves) reuse the still-mounted _EntryAnim,
        // so its entrance animation never re-fired and the new fragment just
        // text-swapped in invisibly (game-studio world/narrative expert, team #5).
        // A per-text key remounts _EntryAnim so each fragment animates in.
        key: ValueKey('lore_banner_$text'),
        reduceMotion: prefersReducedMotion(context),
        child: Semantics(
          liveRegion: true,
          label: '探偵メモ。$text',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: _dismissLore,
            child: Container(
              key: const ValueKey('scene_lore_banner'),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: dqBox.withAlpha(238),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: dqGold, width: 2),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black54,
                      blurRadius: 10,
                      offset: Offset(0, 3)),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🔖', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      text,
                      style:
                          dqText(size: 13, color: dqInk).copyWith(height: 1.55),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 4, top: 2),
                    child: Text(
                      'タップで とばす',
                      style: TextStyle(fontSize: 9, color: Color(0xFF8899AA)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // #50 探索の深さ: the hidden ひらめきコイン is a scene's ONLY discovery reward —
  // and its own a11y label calls it a "ひかる てがかり" (shining clue). But it used
  // to scale in once (0.8→1.0) then sit DEAD-STATIC, while the NPCs got a breathing
  // idle-pulse (#60). A static orb doesn't catch a wandering child's eye, so the
  // "find something" beat never fires. _CoinTwinkle gives it a continuous, gentle
  // twinkle (glow + ✦ breathe) so it reads as alive treasure — findable for 4–8yo,
  // not frustrating. Reduced-motion → static glint.
  Widget _coinTarget(double size) =>
      _CoinTwinkle(size: size, reduceMotion: prefersReducedMotion(context));

  /// #90 observation point — a SUBTLE searchable spot (a faint magnifier dot), far
  /// quieter than the gold coin/NPC so it rewards a curious child who looks around
  /// (Layton density) without shouting. Re-tappable; reveals a 探偵メモ line.
  // Observation hotspots are faint by design (Layton "not pre-marked"), but the
  // real-render audit showed a child may never notice them on a busy painted
  // scene → the 探偵メモ lore goes unseen. A SLOW, subtle breathing shimmer (clearly
  // dimmer than the coin's bright glint) rewards a curious sweep without becoming
  // a loud marker. Respects reduce-motion.
  Widget _observationTarget(double size, bool seen) {
    if (seen) {
      // Investigated: a STATIC 探偵メモ marker (a settled しおり), dimmer than the
      // active shimmer and animation-free — so the world reads as responsive
      // (?→✓) and a child can see which spots remain to explore (#124). No
      // controller here keeps it off the per-frame budget (cf. #123).
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withAlpha(28),
          border: Border.all(color: dqGold.withAlpha(85), width: 1.0),
        ),
        child: Icon(Icons.bookmark_rounded,
            color: dqGold.withAlpha(150), size: size * 0.5),
      );
    }
    return _ObservationShimmer(
        size: size, reduceMotion: prefersReducedMotion(context));
  }

  // Camera-push curve for the witnessed restoration: snap up to 1.28×, hold at
  // peak briefly, then settle back to 1.0 — a felt "the eye is pulled here" beat.
  double _focalPush(double t) {
    if (t < 0.35) return 1.0 + 0.28 * Curves.easeOutCubic.transform(t / 0.35);
    if (t < 0.55) return 1.28; // hold at peak so the change is registered
    final s = (t - 0.55) / 0.45;
    return 1.28 - 0.28 * Curves.easeInOut.transform(s);
  }

  Widget _npcTarget(int idx, Hotspot hotspot, bool solved, double size) {
    final grey = hotspot.npcGreyAsset;
    final color = hotspot.npcColorAsset;

    final Widget portrait;
    if (grey == null && color == null) {
      // If no art exists yet: fallback to emoji/icon portrait.
      portrait = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: dqBox.withAlpha(200),
          border: Border.all(
            color: solved ? const Color(0xFF8BE08B) : dqGold,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (solved ? const Color(0xFF8BE08B) : dqGold).withAlpha(100),
              blurRadius: 10,
            ),
          ],
        ),
        child: Center(
          child: Text(
            hotspot.step?.npcEmoji ?? '👤',
            style: TextStyle(fontSize: size * 0.45),
          ),
        ),
      );
    } else {
      // Grey→color cross-fade on solve.
      portrait = AnimatedCrossFade(
        duration: prefersReducedMotion(context)
            ? Duration.zero
            : const Duration(milliseconds: 600),
        crossFadeState:
            solved ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        firstChild: _npcPortraitImage(grey ?? '', size),
        secondChild: _npcPortraitImage(color ?? '', size),
      );
    }

    // Game-feel: a one-shot gold glow blooms outward the moment THIS NPC's colour
    // returns — making the game's defining verb ("ことばで世界に色が戻る") feel magical,
    // not a quiet cross-fade. Subtle + brief (fits the 本格 dark-RPG palette).
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Idle-pulse halo (#60): an UNSOLVED NPC faintly "breathes" a brass-gold
        // aura — the Layton exploration affordance ("this is alive, tap me") AND
        // the ことばを失った metaphor (silenced villagers straining to speak). It
        // sits BEHIND the portrait, stops the instant the ナゾ is solved (the widget
        // leaves the tree → its controller disposes), and is reduced-motion gated.
        if (!solved && !prefersReducedMotion(context))
          _IdlePulseHalo(key: const ValueKey('npc_idle_pulse'), size: size),
        // Witnessed restoration (studio #1): a brief camera-push (1.0→1.28→1.0)
        // on the just-restored NPC so the child's eye snaps to it AS it comes
        // alive — making the colour-return the felt payoff, not an unseen tween.
        if (_focusIdx == idx)
          AnimatedBuilder(
            animation: _restoreCtrl,
            builder: (_, child) => Transform.scale(
                scale: _focalPush(_restoreCtrl.value), child: child),
            child: portrait,
          )
        else
          portrait,
        // #87 re-audit (CEO 1748): a solved NPC lost its idle-pulse and looked
        // inert, so a child had NO cue that tapping it re-opens the story they
        // recovered (#3). A small gold 探偵メモ (book) badge on the restored villager
        // is that affordance — distinct from the unsolved "tap me to solve" pulse,
        // it reads "there's a story to re-read here". Decorative (taps fall through
        // to the NPC's GestureDetector); the a11y label already says so.
        if (solved)
          Positioned(
            right: size * 0.02,
            bottom: size * 0.02,
            child: Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: BoxDecoration(
                color: dqBox.withAlpha(235),
                shape: BoxShape.circle,
                border: Border.all(color: dqGold.withAlpha(210), width: 1.5),
                boxShadow: [
                  BoxShadow(color: dqGold.withAlpha(90), blurRadius: 5),
                  const BoxShadow(color: Colors.black54, blurRadius: 3),
                ],
              ),
              child: Center(
                child: Icon(Icons.menu_book_rounded,
                    color: dqGold, size: size * 0.16),
              ),
            ),
          ),
        if (idx == _restoringIdx)
          Positioned.fill(
            child: IgnorePointer(
              child: TweenAnimationBuilder<double>(
                key: const ValueKey('restore_glow'),
                tween: Tween(begin: 0.0, end: 1.0),
                duration: prefersReducedMotion(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 850),
                curve: Curves.easeOut,
                builder: (_, t, __) => Opacity(
                  opacity: (1.0 - t).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 1.0 + 0.6 * t,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [Color(0xB3F0D080), Color(0x00F0D080)],
                          radius: 0.75,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _npcPortraitImage(String asset, double size) {
    return Container(
      width: size,
      height: size,
      // Ground the portrait as a framed 探偵 case-file medallion in the scene,
      // not a raw cut-out pasted on the painting (composition audit, CEO 1629):
      // a soft drop-shadow lifts it off the background and a thin gold rim defines
      // a clean edge + signals "tappable". The coin target and the no-art fallback
      // already carry this framing — only the real-art portrait lacked it, so it
      // read as a sticker. ClipOval keeps the image circular under the shadow
      // (a clipping Container would swallow the boxShadow).
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: dqGold.withAlpha(170), width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          // Decode at ~3× the display size (covers high-DPR) instead of the WebP's
          // native 525×768 — the portrait renders in a 52–96px circle, so the full
          // decode wasted ~5-10× GPU/heap per NPC over a long explore session
          // (flaw-hunt R7; sibling of #131).
          cacheWidth: (size * 3).round().clamp(1, 1600),
          cacheHeight: (size * 3).round().clamp(1, 1600),
          errorBuilder: (_, __, ___) => Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dqBox.withAlpha(200),
              border: Border.all(color: dqGold, width: 2),
            ),
            child:
                const Center(child: Text('👤', style: TextStyle(fontSize: 28))),
          ),
        ),
      ),
    );
  }

  Widget _speechBubble(String? clueLineJa, {String ctaLabel = '「？」ナゾをみる'}) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: dqBox.withAlpha(245),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: dqGold, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 3))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (clueLineJa != null) ...[
            Text(clueLineJa,
                style: dqText(size: 12, w: FontWeight.w500, color: dqInk)
                    .copyWith(height: 1.5)),
            const SizedBox(height: 6),
          ],
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [dqGold, dqGoldDeep]),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  ctaLabel,
                  style: dqText(
                      size: 12,
                      w: FontWeight.w800,
                      color: const Color(0xFF2A1C00)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A faint, continuously-breathing brass-gold aura placed BEHIND an unsolved NPC
/// hotspot (#60). It is the Layton-style "this is alive, tap me" affordance and
/// the ことばを失った metaphor (the silenced villager straining to speak). Self-
/// contained: owns its own ticker, so it starts when an unsolved NPC mounts and
/// stops/disposes the moment the ナゾ is solved (the widget leaves the tree).
/// Only mounted when motion is allowed (the call site gates on
/// prefersReducedMotion), so vestibular/seizure-sensitive children never see it.
class _IdlePulseHalo extends StatefulWidget {
  final double size;
  const _IdlePulseHalo({super.key, required this.size});

  @override
  State<_IdlePulseHalo> createState() => _IdlePulseHaloState();
}

class _IdlePulseHaloState extends State<_IdlePulseHalo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ring = widget.size * 1.4;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          // Ease the breath so it lingers at the dim ends and glides through the
          // peak — a calm pulse, not a strobe.
          final t = Curves.easeInOut.transform(_ctrl.value);
          // Animate the gradient's mid-stop ALPHA, not an Opacity wrapper:
          // Opacity forces a per-frame saveLayer on CanvasKit, ×3 NPCs running
          // continuously. A shader-param change has no offscreen layer. The
          // RepaintBoundary contains the repaint so the painted plate + sibling
          // hotspots don't redraw with the pulse (perf #123).
          final midAlpha = (102 * t * 0.5).round(); // 0 → ~51, matches old peak
          return RepaintBoundary(
            child: SizedBox(
              width: ring,
              height: ring,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    // dqGoldDeep (0xB8923C): transparent core (don't wash the
                    // portrait) → soft ring → transparent rim.
                    colors: [
                      const Color(0x00B8923C),
                      const Color(0xFFB8923C).withAlpha(midAlpha),
                      const Color(0x00B8923C),
                    ],
                    stops: const [0.42, 0.70, 1.0],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The hidden ひらめきコイン's visual — a gold glint that twinkles continuously so a
/// wandering child notices "something shiny over there" (the scene's only discovery
/// beat, #50). The glow blur/spread and the ✦ scale breathe in a calm, eased cycle
/// (never a strobe). Reduced-motion → a static glint at the cycle's mid brightness.
/// Subtle breathing shimmer for an observation hotspot — deliberately dimmer and
/// slower than [_CoinTwinkle] so it stays SECONDARY to coins while still catching
/// a curious sweep (the real-render audit showed static dots get missed on a busy
/// painted scene, leaving the 探偵メモ lore undiscovered). Reduce-motion → static.
class _ObservationShimmer extends StatefulWidget {
  final double size;
  final bool reduceMotion;
  const _ObservationShimmer({required this.size, required this.reduceMotion});

  @override
  State<_ObservationShimmer> createState() => _ObservationShimmerState();
}

class _ObservationShimmerState extends State<_ObservationShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600), // slow, calm breathing
    );
    if (!widget.reduceMotion) _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _dot(double t) {
    // t: 0 (dim) → 1 (a touch brighter). Reduced-motion passes 0.45.
    final borderAlpha = (70 + 60 * t).round(); // 70 → 130
    final iconAlpha = (130 + 60 * t).round(); // 130 → 190
    final glowAlpha = (10 + 45 * t).round(); // very soft halo, 10 → 55
    // Hold the blur radius CONSTANT (was 4→9): an animated blurRadius can't be
    // layer-cached on CanvasKit — it re-rasterizes the gaussian mask every
    // frame. The breathe stays legible via the animated border/icon/glow alpha
    // above (perf #123). Mid value keeps the prior look.
    const glowBlur = 6.5;
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withAlpha(45),
        border: Border.all(color: dqGold.withAlpha(borderAlpha), width: 1.2),
        boxShadow: [
          BoxShadow(color: dqGold.withAlpha(glowAlpha), blurRadius: glowBlur),
        ],
      ),
      child: Center(
        child: Icon(Icons.search,
            color: dqGold.withAlpha(iconAlpha), size: widget.size * 0.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reduceMotion) return _dot(0.45);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => _dot(Curves.easeInOut.transform(_ctrl.value)),
      ),
    );
  }
}

class _CoinTwinkle extends StatefulWidget {
  final double size;
  final bool reduceMotion;
  const _CoinTwinkle({required this.size, required this.reduceMotion});

  @override
  State<_CoinTwinkle> createState() => _CoinTwinkleState();
}

class _CoinTwinkleState extends State<_CoinTwinkle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (!widget.reduceMotion) _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static const _gold = Color(0xFFFFD700);

  Widget _glint(double t) {
    // t: 0 (dim) → 1 (bright). Reduced-motion passes 0.5 (mid glint).
    final glowAlpha = (120 + 90 * t).round(); // 120 → 210
    // Hold blur + spread CONSTANT (were 9→18 / 1→3.5): animating a BoxShadow's
    // blurRadius/spreadRadius re-rasterizes the gaussian mask every frame on
    // CanvasKit. The twinkle stays vivid via the animated glow alpha + the
    // cheap Transform.scale below (perf #123). Mid values keep the prior look.
    const glowBlur = 13.5;
    const glowSpread = 2.25;
    final starScale = 0.9 + 0.18 * t; // 0.90 → 1.08
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF2A1C00).withAlpha(180),
        border: Border.all(color: _gold, width: 2),
        boxShadow: [
          BoxShadow(
            color: _gold.withAlpha(glowAlpha),
            blurRadius: glowBlur,
            spreadRadius: glowSpread,
          ),
        ],
      ),
      child: Center(
        child: Transform.scale(
          scale: starScale,
          child: const Text('✦', style: TextStyle(color: _gold, fontSize: 20)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reduceMotion) return _glint(0.5);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => _glint(Curves.easeInOut.transform(_ctrl.value)),
      ),
    );
  }
}

/// One-shot entry animation for scene overlays (#82 game-feel): the speech bubble
/// and banners used to POP in via a bare `if` in the Stack. _EntryAnim makes them
/// rise + fade + settle on mount (~240ms easeOutCubic) so a clue "materialises"
/// instead of a div toggling visibility. Reduced-motion → static (no movement).
class _EntryAnim extends StatefulWidget {
  final Widget child;
  final bool reduceMotion;
  const _EntryAnim(
      {super.key, required this.child, required this.reduceMotion});

  @override
  State<_EntryAnim> createState() => _EntryAnimState();
}

class _EntryAnimState extends State<_EntryAnim>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    if (widget.reduceMotion) {
      _c.value = 1.0;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = Curves.easeOutCubic.transform(_c.value);
        return Opacity(
          // Floor just above 0: Opacity(0.0) EXCLUDES the subtree from semantics,
          // which would make these liveRegion banners a11y-invisible during the
          // fade-in (a screen-reader child must hear タロ / the 探偵メモ immediately).
          opacity: t.clamp(0.04, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 14),
            child: Transform.scale(scale: 0.96 + 0.04 * t, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}
