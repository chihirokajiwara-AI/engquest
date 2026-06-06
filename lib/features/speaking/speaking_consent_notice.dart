// lib/features/speaking/speaking_consent_notice.dart
// A-KEN Quest — 英検 二次 保護者同意 (Parental Consent) Notice
//
// COPPA-2025 / APPI-2026 COMPLIANCE:
//   Child voice is biometric under both regimes (COPPA 2025 effective date
//   2026-04-22; APPI 2026 under-16 guardian consent).  This screen is a
//   MANDATORY launch gate — audio capture must not start until the parent
//   (not the child) has actively ticked the checkbox.
//
// Design brief (from ASR-SPEAKING-RESEARCH.json §buildApproach):
//   - Lightweight, calm — not a scary legal wall.
//   - Parent-readable Japanese.
//   - Three bullet points covering recording, processing, and deletion.
//   - A checkbox the parent checks, then a "同意して はじめる" gold button.
//   - Consent is NOT persisted here — the caller receives it via [onConsent]
//     and decides where/how to store it (PreferencesService, Firestore, etc.).
//     This keeps the widget R4-clean (no storage calls in build/init).
//
// Usage:
//   Navigator.push(context, MaterialPageRoute(
//     builder: (_) => SpeakingConsentNotice(
//       eikenGrade: '3',
//       onConsent: () => _openSpeakingScreen(),
//     ),
//   ));

import 'package:flutter/material.dart';

import '../quest/ui/dq_ui.dart';

class SpeakingConsentNotice extends StatefulWidget {
  const SpeakingConsentNotice({
    super.key,
    required this.eikenGrade,
    required this.onConsent,
  });

  /// The 英検 grade being practiced (e.g. '3', 'pre2', '2', 'pre1').
  final String eikenGrade;

  /// Called when the parent checks the box AND taps "同意して はじめる".
  /// The caller is responsible for persisting the consent flag if needed.
  final VoidCallback onConsent;

  @override
  State<SpeakingConsentNotice> createState() => _SpeakingConsentNoticeState();
}

class _SpeakingConsentNoticeState extends State<SpeakingConsentNotice> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    return DqScene(
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _buildTitle(),
                  const SizedBox(height: 20),
                  _buildNoticePanel(),
                  const SizedBox(height: 24),
                  _buildCheckbox(),
                  const SizedBox(height: 20),
                  _buildConsentButton(),
                  const SizedBox(height: 12),
                  _buildDeclineLink(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: dqInk),
            onPressed: () => Navigator.maybePop(context),
          ),
          Expanded(
            child: dqBilingual(
              '保護者の方へ',
              'For Parents / Guardians',
              jpSize: 18,
              stacked: false,
            ),
          ),
        ],
      ),
    );
  }

  // ── Title block ─────────────────────────────────────────────────────────────

  Widget _buildTitle() {
    return DqPanel(
      child: Row(
        children: [
          const Text('🎤', style: TextStyle(fontSize: 40)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '英検 二次（スピーキング）練習',
                  style: dqText(size: 17, w: FontWeight.w800, color: dqInk),
                ),
                const SizedBox(height: 4),
                Text(
                  'Speaking Practice — 音声収録について',
                  style: dqText(size: 12, color: dqGold, spacing: 0.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Notice panel ────────────────────────────────────────────────────────────

  Widget _buildNoticePanel() {
    return DqPanel(
      title: 'ご確認ください / Please read',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBullet(
            icon: Icons.mic_outlined,
            ja: '音声を録音して採点に使います',
            en: 'Voice is recorded for scoring feedback.',
          ),
          const SizedBox(height: 14),
          _buildBullet(
            icon: Icons.cloud_outlined,
            ja: 'クラウドで処理後、音声データは即時削除します（保存しません）',
            en:
                'Audio is processed in the cloud (Microsoft Azure) and '
                'deleted immediately after scoring. No audio is stored.',
          ),
          const SizedBox(height: 14),
          _buildBullet(
            icon: Icons.family_restroom_outlined,
            ja: '18歳未満のお子さまが使用する場合、保護者の方の同意が必要です',
            en:
                'Parental or guardian consent is required for children '
                'under 18 (COPPA / APPI compliance).',
          ),
          const SizedBox(height: 14),
          _buildBullet(
            icon: Icons.school_outlined,
            ja: 'スコアは合格・不合格の判定ではなく、練習のためのアドバイスとして表示されます',
            en:
                'Scores are formative coaching, not pass/fail verdicts. '
                'No published benchmark exists for Japanese child L2 English; '
                'all feedback is encouragement-biased.',
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF15201A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF4A8B5C), width: 1.5),
            ),
            child: Text(
              'プライバシーポリシーの詳細は アプリ内 → 設定 → プライバシーポリシー をご覧ください。',
              style: dqText(size: 12, color: const Color(0xFF8BD4A8), spacing: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBullet({
    required IconData icon,
    required String ja,
    required String en,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: dqGold, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ja, style: dqText(size: 14, color: dqInk)),
              const SizedBox(height: 3),
              Text(
                en,
                style: dqText(size: 11, color: dqGoldDeep, spacing: 0.3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Checkbox ────────────────────────────────────────────────────────────────

  Widget _buildCheckbox() {
    return GestureDetector(
      onTap: () => setState(() => _agreed = !_agreed),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _agreed
                  ? dqGold
                  : dqBox,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _agreed ? dqGold : dqBorder,
                width: 2,
              ),
            ),
            child: _agreed
                ? const Icon(Icons.check, color: Color(0xFF2A1C00), size: 20)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '内容を確認し、上記に同意します（保護者の方がチェックしてください）',
              style: dqText(size: 14, color: dqInk),
            ),
          ),
        ],
      ),
    );
  }

  // ── Consent button ──────────────────────────────────────────────────────────

  Widget _buildConsentButton() {
    return DqButton(
      label: '同意して はじめる  /  Agree & Start',
      onTap: _agreed ? widget.onConsent : null,
    );
  }

  // ── Decline link ────────────────────────────────────────────────────────────

  Widget _buildDeclineLink(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () => Navigator.maybePop(context),
        child: Text(
          '同意しない / Decline — 戻る',
          style: dqText(size: 13, color: dqGoldDeep),
        ),
      ),
    );
  }
}
