// lib/features/settings/settings_screen.dart
// A-KEN Quest — Settings (おんと・あそびかた)
//
// Closes the journey gap (#27): there was no global mute / how-to-play
// affordance anywhere. Two REAL audio channels (no dead toggles):
//   • こうかおん  (SFX)   ↔ SoundService.muted        (soundMuted pref)
//   • ことばの こえ (Voice) ↔ AudioMute.voiceMuted (voiceMuted pref) — honoured by
//     BOTH WordAudioPlayerService (flashcards) and AudioCueService (everything else)
// plus a master mute and a child-friendly あそびかた (how-to-play) sheet.
//
// #68: In-app subscription cancellation surface (aken flavor only).
//   Apple App Review requires apps to surface a way to manage/cancel subscriptions.
//   We launch the OS-native management URL via url_launcher.
//
// #66 upgrade: support email addresses are now tappable (mailto:) in addition to
//   being selectable. url_launcher handles mailto: on all supported platforms
//   (opens mail client on iOS/Android/macOS; new mailto tab on web).
//
// (Music/BGM channel is intentionally NOT shown yet — there is no BGM to mute;
// a dead toggle would be theatre. It is added when BGM ships.)

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:engquest/core/analytics/analytics_service.dart';
import 'package:engquest/core/config/flavor_config.dart';
import 'package:engquest/core/sound/sound_service.dart';
import 'package:engquest/core/audio/audio_mute.dart';
import 'package:engquest/core/ui/readability_scale.dart';
import 'package:engquest/core/storage/preferences_service.dart';
import 'package:engquest/features/exam_practice/eiken_exam_config.dart'
    show gradeLabelJa;
import 'package:engquest/features/paywall/grade_gate_screen.dart';
import 'package:engquest/features/quest/ui/dq_ui.dart';
import 'package:engquest/features/parent_dashboard/parent_login_screen.dart';
import 'package:engquest/features/achievements/achievements_screen.dart';
import 'package:engquest/features/explore/case_log_screen.dart';
import 'package:engquest/features/quest/prologue_screen.dart';

// ── Platform URL helpers ──────────────────────────────────────────────────────

/// Returns the OS-native subscription management URL for the current platform.
///
/// iOS/macOS → App Store subscriptions page.
/// Android → Google Play subscriptions page.
/// Web (and any other platform) → App Store subscriptions page as a fallback;
/// if a Stripe billing-portal URL is ever configured it should replace this.
String _subscriptionManagementUrl() {
  if (kIsWeb) return 'https://apps.apple.com/account/subscriptions';
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return 'https://apps.apple.com/account/subscriptions';
    case TargetPlatform.android:
      return 'https://play.google.com/store/account/subscriptions';
    default:
      return 'https://apps.apple.com/account/subscriptions';
  }
}

/// Launches [url] via url_launcher.  On failure shows a [SnackBar] with the
/// raw URL so the user can copy it as a fallback.
Future<void> _launchOrFallback(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      _showFallbackSnackBar(context, url);
    }
  } catch (_) {
    if (context.mounted) _showFallbackSnackBar(context, url);
  }
}

void _showFallbackSnackBar(BuildContext context, String url) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: SelectableText(
        url,
        style: const TextStyle(color: Colors.white),
      ),
      duration: const Duration(seconds: 8),
    ),
  );
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _sound = SoundService();
  bool _sfxOn = true;
  bool _voiceOn = true;
  double _textScale = 1.0;
  bool _loaded = false;
  // The child's current 英検 grade (onboarding_start_level). Until now it was set
  // ONCE at onboarding with no way to change it — a mis-placed child, or one who
  // outgrew their grade, was stuck. This lets the child/parent change it.
  static const _kStartLevelKey = 'onboarding_start_level';
  static const _kGrades = ['5', '4', '3', 'pre2', 'pre2plus', '2', 'pre1'];
  String _currentGrade = '5';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _sound.loadPreferences();
    await AudioMute.loadVoicePreference();
    String grade = '5';
    try {
      final prefs = await PreferencesService.getInstance();
      grade = prefs.getString(_kStartLevelKey) ?? '5';
    } catch (_) {
      // Prefs unavailable → keep default.
    }
    if (!mounted) return;
    setState(() {
      _sfxOn = !_sound.muted;
      _voiceOn = !AudioMute.voiceMuted;
      _textScale = ReadabilityScale.value;
      _currentGrade = grade;
      _loaded = true;
    });
  }

  /// Lets the child/parent change the persisted 英検 grade. The home re-reads
  /// onboarding_start_level when it next loads (the gear-open now refreshes), so
  /// the new grade drives practice + 合格率 across the app.
  Future<void> _changeGrade() async {
    final flavor = FlavorConfig.instance;
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('英検（えいけん）の きゅうを えらぶ',
            style: dqText(size: 15, w: FontWeight.w700, color: dqInk)),
        children: [
          for (final g in _kGrades)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, g),
              child: Row(
                children: [
                  Icon(
                    g == _currentGrade
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: g == _currentGrade ? dqGold : dqGoldDeep,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(gradeLabelJa(g), style: dqText(size: 15, color: dqInk)),
                  // Paid grades (aken freemium) show a lock — selecting one opens
                  // the paywall, never switches free (no bypass of the gate).
                  if (!flavor.isGradeFree(g)) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.lock, color: dqGoldDeep, size: 16),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
    if (picked == null || picked == _currentGrade) return;
    // A locked (paid) grade must go through the paywall, not switch for free.
    if (!flavor.isGradeFree(picked)) {
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => GradeGateScreen(
          eikenGrade: picked,
          onSubscribe: () {
            Navigator.of(context).pop(); // close the gate after purchase
            _applyGrade(picked);
          },
        ),
      ));
      return;
    }
    await _applyGrade(picked);
  }

  /// Persist the new grade + confirm. Shared by the free-grade path and the
  /// post-purchase callback so the paywall is never bypassed.
  Future<void> _applyGrade(String grade) async {
    final previousGrade = _currentGrade;
    try {
      final prefs = await PreferencesService.getInstance();
      await prefs.setString(_kStartLevelKey, grade);
    } catch (_) {
      return; // best-effort; on failure the UI simply does not change
    }
    // Fire grade_switch before the state update so fromGrade is still valid.
    AnalyticsService.instance.logGradeSwitch(
      fromGrade: previousGrade,
      toGrade: grade,
    );
    if (!mounted) return;
    setState(() => _currentGrade = grade);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('きゅうを ${gradeLabelJa(grade)} に かえたよ！'),
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _setTextScale(double s) async {
    await ReadabilityScale.set(s); // updates the global notifier → live resize
    if (mounted) setState(() => _textScale = ReadabilityScale.value);
  }

  /// One selectable text-size chip; the active size is highlighted in gold.
  Widget _sizeChip(double s) {
    final selected = (_textScale - s).abs() < 0.001;
    return GestureDetector(
      onTap: () => _setTextScale(s),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? dqGold.withAlpha(40) : dqNight1,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? dqGold : dqGoldDeep.withAlpha(110),
            width: selected ? 2 : 1,
          ),
        ),
        // #77: shrink-to-fit so a long label (「とても大きい」) never wraps to two
        // lines inside the equal-width chip (which read as a broken button).
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            ReadabilityScale.labelJa(s),
            maxLines: 1,
            softWrap: false,
            textAlign: TextAlign.center,
            style: dqText(
              size: 12,
              w: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? dqGold : dqInk,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _setSfx(bool on) async {
    _sound.muted = !on; // setter persists soundMuted
    if (on) _sound.playFlip(); // gentle confirmation when turning ON
    setState(() => _sfxOn = on);
  }

  Future<void> _setVoice(bool on) async {
    await AudioMute.setVoiceMuted(!on);
    setState(() => _voiceOn = on);
  }

  Future<void> _setAll(bool on) async {
    await _setSfx(on);
    await _setVoice(on);
  }

  @override
  Widget build(BuildContext context) {
    // "Mute everything" is ON only when BOTH channels are muted; in a mixed
    // state it reads OFF (because everything is NOT muted).
    final allMuted = !_sfxOn && !_voiceOn;
    return DqScene(
      contentMaxWidth: 600, // #144: centre on tablet, full-width on phone
      child: SafeArea(
        child: Column(
          children: [
            _header(context),
            Expanded(
              child: !_loaded
                  ? const Center(
                      child: CircularProgressIndicator(color: dqGold))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                      children: [
                        DqPanel(
                          title: 'おと / Sound',
                          child: Column(
                            children: [
                              _toggle(
                                jp: 'こうかおん',
                                en: 'Sound effects',
                                icon: Icons.music_note,
                                value: _sfxOn,
                                onChanged: _setSfx,
                              ),
                              _divider(),
                              _toggle(
                                jp: 'ことばの こえ',
                                en: 'Word audio (pronunciation)',
                                icon: Icons.record_voice_over,
                                value: _voiceOn,
                                onChanged: _setVoice,
                              ),
                              _divider(),
                              _toggle(
                                jp: 'すべて 消音（しょうおん）',
                                en: 'Mute everything',
                                icon: allMuted
                                    ? Icons.volume_off
                                    : Icons.volume_up,
                                value: allMuted,
                                onChanged: (muteAll) => _setAll(!muteAll),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Readability (#114): opt-in text size. 2026 a11y research
                        // — size/spacing/adjustability help more than any "dyslexia
                        // font" (which studies show doesn't help). Default ふつう.
                        DqPanel(
                          title: 'よみやすさ / Readability',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.format_size,
                                      color: dqGold, size: 22),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('もじの 大（おお）きさ',
                                            style: dqText(
                                                size: 15,
                                                w: FontWeight.w700,
                                                color: dqInk)),
                                        Text('Text size',
                                            style: dqText(
                                                size: 11,
                                                w: FontWeight.w500,
                                                color: dqInk.withAlpha(160))),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  for (final s in ReadabilityScale.steps)
                                    Expanded(
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(right: 8),
                                        child: _sizeChip(s),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Reachability fix (#41): the parent progress dashboard and
                        // the achievements screen were built but unreachable from the
                        // live home (only the orphaned WorldMapScreen linked parent;
                        // achievements was linked nowhere). Surface both via the
                        // already-reachable Settings gear, keeping the home uncluttered.
                        DqPanel(
                          title: 'メニュー / Menu',
                          child: Column(
                            children: [
                              DqTile(
                                jp: '英検（えいけん）の きゅう：'
                                    '${gradeLabelJa(_currentGrade)}',
                                en: 'Change 英検 grade',
                                icon: Icons.school,
                                onTap: _changeGrade,
                              ),
                              _divider(),
                              DqTile(
                                jp: '保護者（ほごしゃ）の方（かた）へ',
                                en: 'For Parents',
                                icon: Icons.family_restroom,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const ParentLoginScreen(),
                                  ),
                                ),
                              ),
                              _divider(),
                              DqTile(
                                jp: 'じっせき',
                                en: 'Achievements',
                                icon: Icons.emoji_events,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const AchievementsScreen(),
                                  ),
                                ),
                              ),
                              _divider(),
                              // 事件簿 — re-read solved cases + the assembling
                              // bookmark mystery (post-clear replayability, N12).
                              DqTile(
                                jp: 'じけんぼ',
                                en: 'Case File',
                                icon: Icons.menu_book_rounded,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const CaseLogScreen(),
                                  ),
                                ),
                              ),
                              _divider(),
                              // Re-watch the opening story. It plays once-ever on
                              // first launch; a child who loved it (or a parent)
                              // had no way to see it again. onDone just pops back
                              // — the caller owns the once-ever 'seen' flag, so a
                              // replay never re-gates the first-launch flow.
                              DqTile(
                                jp: 'オープニングを もういちど みる',
                                en: 'Replay opening',
                                icon: Icons.replay,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PrologueScreen(
                                      onDone: () =>
                                          Navigator.of(context).maybePop(),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        DqPanel(
                          title: 'ヘルプ / Help',
                          child: Column(
                            children: [
                              DqTile(
                                jp: 'あそびかた',
                                en: 'How to play',
                                icon: Icons.help_outline,
                                onTap: () => _showHowToPlay(context),
                              ),
                              _divider(),
                              // #66 — Store-required reachable support contact for
                              // a paid app (Apple + Google Play mandate this).
                              DqTile(
                                jp: 'お問い合わせ（といあわせ）/ サポート',
                                en: 'Contact Support',
                                icon: Icons.support_agent,
                                onTap: () => _showSupport(context),
                              ),
                            ],
                          ),
                        ),
                        // #68 — Subscription management (aken flavor only).
                        // Apple App Review mandates a reachable cancellation
                        // surface for apps with in-app subscriptions.
                        if (FlavorConfig.instanceOrNull?.isAkenFlavor ==
                            true) ...[
                          const SizedBox(height: 14),
                          DqPanel(
                            title: 'サブスクリプション / Subscription',
                            child: DqTile(
                              jp: 'サブスクの かいやく（解約）',
                              en: 'Manage subscription',
                              icon: Icons.credit_card_outlined,
                              onTap: () => _launchOrFallback(
                                context,
                                _subscriptionManagementUrl(),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.arrow_back_ios_new, color: dqGold, size: 20),
            ),
          ),
          Expanded(
            child: Center(
              child: dqBilingual('せってい', 'Settings', jpSize: 19),
            ),
          ),
          const SizedBox(width: 36),
        ],
      ),
    );
  }

  Widget _divider() => Divider(color: dqGoldDeep.withAlpha(60), height: 18);

  Widget _toggle({
    required String jp,
    required String en,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, color: dqGold, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(jp,
                  style: dqText(size: 15, w: FontWeight.w700, color: dqInk)),
              Text(en,
                  style: dqText(
                      size: 11,
                      w: FontWeight.w500,
                      color: dqInk.withAlpha(160))),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: dqGold,
          activeTrackColor: dqGoldDeep,
        ),
      ],
    );
  }

  // #66 (upgraded) — お問い合わせダイアログ: support surface required by Apple +
  // Google Play for paid apps. Each email address is BOTH tappable (mailto: via
  // url_launcher → opens mail client) AND selectable (copy fallback).
  // Child-safe wording with furigana.
  void _showSupport(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: DqDialogBox(
          speaker: 'サポート / Support',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'お困（こま）りのことは、下（した）の メールにご連絡（れんらく）ください。',
                style: dqText(size: 13, w: FontWeight.w600, color: dqInk)
                    .copyWith(height: 1.7),
              ),
              const SizedBox(height: 14),
              // 不具合（ふぐあい）報告
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.bug_report, color: dqGold, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '不具合（ふぐあい）・ご要望（ようぼう）',
                          style: dqText(
                              size: 12, w: FontWeight.w700, color: dqGold),
                        ),
                        Text(
                          '不具合（ふぐあい）は このメールへ',
                          style: dqText(
                                  size: 11,
                                  w: FontWeight.w500,
                                  color: dqInk.withAlpha(170))
                              .copyWith(height: 1.5),
                        ),
                        const SizedBox(height: 4),
                        // Tappable mailto: row — opens mail client.
                        // SelectableText underneath keeps copy-as-fallback.
                        _EmailTile(
                          address: 'support@edilab.co',
                          onTap: () => _launchOrFallback(
                            ctx,
                            'mailto:support@edilab.co',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // プライバシー連絡先
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lock_outline, color: dqGold, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'プライバシーに関（かん）するお問い合わせ（といあわせ）',
                          style: dqText(
                              size: 12, w: FontWeight.w700, color: dqGold),
                        ),
                        const SizedBox(height: 4),
                        _EmailTile(
                          address: 'privacy@edilab.co',
                          onTap: () => _launchOrFallback(
                            ctx,
                            'mailto:privacy@edilab.co',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: DqButton(
                  label: 'とじる / Close',
                  onTap: () => Navigator.of(ctx).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHowToPlay(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: DqDialogBox(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              dqBilingual('あそびかた', 'How to play', jpSize: 18),
              const SizedBox(height: 12),
              Text(
                '① 街（まち）を たんけんして、消（き）えた 言葉（ことば）を 取（と）りもどそう。\n'
                '② カードで 単語（たんご）を おぼえ、クイズで 力（ちから）を ためそう。\n'
                '③ 毎日（まいにち）つづけて、英検（えいけん）合格（ごうかく）を めざそう！',
                style: dqText(size: 13, w: FontWeight.w500, color: dqInk)
                    .copyWith(height: 1.7),
              ),
              const SizedBox(height: 10),
              Text(
                'Explore towns to restore lost words, learn vocab on cards, test '
                'yourself with quizzes, and practise every day toward 英検!',
                style: dqText(
                        size: 11,
                        w: FontWeight.w500,
                        color: dqInk.withAlpha(170))
                    .copyWith(height: 1.6),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: DqButton(
                  label: 'OK',
                  onTap: () => Navigator.of(ctx).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── _EmailTile ────────────────────────────────────────────────────────────────
// Tappable email row: GestureDetector wraps a SelectableText so the address
// is both launchable (tap → mailto:) AND copyable (long-press → text select).

class _EmailTile extends StatelessWidget {
  final String address;
  final VoidCallback onTap;

  const _EmailTile({required this.address, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          const Icon(Icons.open_in_new, size: 14, color: Color(0xFF8BE0FF)),
          const SizedBox(width: 4),
          Flexible(
            child: SelectableText(
              address,
              style: dqText(
                size: 13,
                w: FontWeight.w800,
                color: const Color(0xFF8BE0FF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
