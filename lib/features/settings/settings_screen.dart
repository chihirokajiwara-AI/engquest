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
// (Music/BGM channel is intentionally NOT shown yet — there is no BGM to mute;
// a dead toggle would be theatre. It is added when BGM ships.)

import 'package:flutter/material.dart';

import 'package:engquest/core/sound/sound_service.dart';
import 'package:engquest/core/audio/audio_mute.dart';
import 'package:engquest/core/ui/readability_scale.dart';
import 'package:engquest/features/quest/ui/dq_ui.dart';
import 'package:engquest/features/parent_dashboard/parent_login_screen.dart';
import 'package:engquest/features/achievements/achievements_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _sound.loadPreferences();
    await AudioMute.loadVoicePreference();
    if (!mounted) return;
    setState(() {
      _sfxOn = !_sound.muted;
      _voiceOn = !AudioMute.voiceMuted;
      _textScale = ReadabilityScale.value;
      _loaded = true;
    });
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
        child: Text(
          ReadabilityScale.labelJa(s),
          textAlign: TextAlign.center,
          style: dqText(
            size: 12,
            w: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? dqGold : dqInk,
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
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        DqPanel(
                          title: 'ヘルプ / Help',
                          child: DqTile(
                            jp: 'あそびかた',
                            en: 'How to play',
                            icon: Icons.help_outline,
                            onTap: () => _showHowToPlay(context),
                          ),
                        ),
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
                      size: 11, w: FontWeight.w500, color: dqInk.withAlpha(160))),
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
                        size: 11, w: FontWeight.w500, color: dqInk.withAlpha(170))
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
