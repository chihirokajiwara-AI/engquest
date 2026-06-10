// lib/core/gamification/hint_coin_service.dart
// Wave 1 — ひらめきコイン (Hint Coin) service.
//
// Persistent coin balance via PreferencesService (seed: 10 coins).
// Coins are SPENT on teaching hints — they TEACH, never reveal the answer.
//
// Tier contract (from the design):
//   T1 (1 coin) — the grammar/phonics PRINCIPLE in Japanese.
//   T2 (2 coins) — eliminate ONE distractor WITH the reason.
//   T3 (3 coins) — a worked PARALLEL example the kid must still map.

import '../../core/storage/preferences_service.dart';

class HintCoinService {
  static const _prefKey = 'hint_coin_balance';
  static const _seededKey = 'hint_coin_seeded';
  static const _seedBalance = 10;
  static const _costByTier = [0, 1, 2, 3]; // index = tier (1-based: use index 1..3)

  HintCoinService({PreferencesService? prefs}) : _prefs = prefs;

  PreferencesService? _prefs;

  // ── Lazy init ─────────────────────────────────────────────────────────────

  Future<void> _ensurePrefs() async {
    _prefs ??= await PreferencesService.getInstance();
  }

  // ── Balance ───────────────────────────────────────────────────────────────

  /// Returns the current coin balance (async first call, sync after).
  Future<int> balance() async {
    await _ensurePrefs();
    // getInt returns 0 for BOTH "never initialised" and "spent down to 0", so a
    // separate PERSISTED flag marks the one-time seed. The old code returned the
    // seed (10) whenever the balance read 0 — so a child who spent all their
    // coins, navigated away, and returned got 10 back every time → infinite hint
    // coins (the hint scaffold became free/unlimited). R9.
    if (!_prefs!.getBool(_seededKey)) {
      await _prefs!.setInt(_prefKey, _seedBalance);
      await _prefs!.setBool(_seededKey, true);
      return _seedBalance;
    }
    return _prefs!.getInt(_prefKey); // real balance, including a legitimate 0
  }

  // ── Add coin ──────────────────────────────────────────────────────────────

  /// Add [n] coins (called when player taps a coin hotspot). Returns new balance.
  Future<int> addCoin([int n = 1]) async {
    await _ensurePrefs();
    final current = await balance();
    final newBalance = current + n;
    await _prefs!.setInt(_prefKey, newBalance);
    return newBalance;
  }

  // ── Spend ─────────────────────────────────────────────────────────────────

  /// Try to spend [cost] coins. Returns true + new balance if successful,
  /// false if insufficient funds.
  Future<({bool ok, int balance})> spend(int cost) async {
    await _ensurePrefs();
    final current = await balance();
    if (current < cost) return (ok: false, balance: current);
    final newBalance = current - cost;
    await _prefs!.setInt(_prefKey, newBalance);
    return (ok: true, balance: newBalance);
  }

  /// Cost in coins for hint tier [tier] (1, 2, or 3).
  static int costForTier(int tier) {
    if (tier < 1 || tier > 3) return 0;
    return _costByTier[tier];
  }
}

// ── Hint content model ────────────────────────────────────────────────────────

/// One of the three teaching-hint tiers for a ナゾ.
/// Hints TEACH; they must never encode the correct option directly.
class NazoHint {
  /// 1, 2, or 3.
  final int tier;

  /// Cost in ひらめきコイン for this tier.
  int get cost => HintCoinService.costForTier(tier);

  /// The hint text shown to the player (natural Japanese, ひらがな-friendly).
  final String textJa;

  const NazoHint({required this.tier, required this.textJa});
}

/// Built-in fallback hints generated from the step's eikenLevel + penalizeWrong.
/// Used when no authored hints are supplied in the Hotspot.
List<NazoHint> defaultHintsForLevel(String eikenLevel) {
  switch (eikenLevel) {
    case '5':
      return const [
        NazoHint(
          tier: 1,
          textJa: '【ヒント T1】英語では、だれが（主語）・する（動詞）の順（じゅん）番（ばん）が大切（たいせつ）。'
              '選択肢（せんたくし）の最初（さいしょ）の単語（たんご）に注目（ちゅうもく）しよう。',
        ),
        NazoHint(
          tier: 2,
          textJa: '【ヒント T2】「be動詞（どうし）」(am/are/is) と「一般動詞（いっぱんどうし）」(play/like など) は'
              '一緒（いっしょ）には使（つか）えないよ。それを使っている選択肢（せんたくし）を外（はず）してみて。',
        ),
        NazoHint(
          tier: 3,
          textJa: '【ヒント T3】例（たと）えば："I play soccer." → "He plays soccer."（三人称単数（さんにんしょうたんすう）のときは -s がつく）。'
              'この問題（もんだい）の主語（しゅご）はだれ？同（おな）じルールで考（かんが）えてみよう。',
        ),
      ];
    default:
      return const [
        NazoHint(tier: 1, textJa: '【ヒント T1】もう一度（いちど）、問題（もんだい）の文（ぶん）をよく読（よ）もう。どんな文法（ぶんぽう）が使われているかな？'),
        NazoHint(tier: 2, textJa: '【ヒント T2】日本語（にほんご）の意味（いみ）をヒントに、意味（いみ）の合（あ）わない選択肢（せんたくし）を外（はず）してみよう。'),
        NazoHint(tier: 3, textJa: '【ヒント T3】似（に）た例文（れいぶん）を思（おも）い出（だ）して。パターンが同（おな）じなら、答（こた）えも見（み）えてくるよ。'),
      ];
  }
}
