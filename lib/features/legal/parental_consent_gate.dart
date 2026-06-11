import 'package:flutter/material.dart';

import '../../core/storage/preferences_service.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';

/// ENG Quest — Parental Consent Gate (COPPA compliance)
///
/// Shown before onboarding begins. Requires a parent/guardian to confirm
/// they consent to their child using the app. Includes a math challenge
/// ("parental gate") to verify it's an adult, not the child, tapping through.
///
/// Apple App Store Review Guidelines 1.3 and Google Play Families policy
/// both require a parental gate for apps targeting children under 13.
///
/// Persistence (#65 — COPPA-2026 consent audit trail):
/// - On pass: stores an ISO-8601 UTC timestamp ([PrefKeys.parentalConsentGrantedAt])
///   and the current policy version ([PrefKeys.kParentalConsentPolicyVersion]).
/// - On subsequent app launches: if stored policy version matches the current
///   version, [onConsented] is called immediately (gate skipped).
/// - Policy change: bumping [PrefKeys.kParentalConsentPolicyVersion] forces
///   re-collection of consent.
/// - Revoke: PreferencesService.clear() (data deletion, #67) clears these keys.
class ParentalConsentGate extends StatefulWidget {
  final VoidCallback onConsented;

  const ParentalConsentGate({super.key, required this.onConsented});

  @override
  State<ParentalConsentGate> createState() => _ParentalConsentGateState();
}

class _ParentalConsentGateState extends State<ParentalConsentGate> {
  bool _agreedToPolicy = false;
  bool _showingChallenge = false;

  // Parental gate: simple math problem a child wouldn't solve quickly
  late final int _a;
  late final int _b;
  late final int _correctAnswer;
  final _answerController = TextEditingController();
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _generateChallenge();
    // Check stored consent after the first frame so the widget is fully mounted
    // and the caller's onConsented can be safely invoked.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkStoredConsent());
  }

  /// If a valid stored parental consent exists for the current policy version,
  /// invoke [onConsented] immediately so the gate is transparent to the user.
  /// A policy-version mismatch falls through and shows the gate UI normally.
  Future<void> _checkStoredConsent() async {
    if (!mounted) return;
    final prefs = await PreferencesService.getInstance();
    final storedVersion =
        prefs.getString(PrefKeys.parentalConsentPolicyVersion);
    final ts = prefs.getString(PrefKeys.parentalConsentGrantedAt);
    if (storedVersion == PrefKeys.kParentalConsentPolicyVersion &&
        ts != null) {
      if (!mounted) return;
      widget.onConsented();
    }
    // Otherwise: render the gate UI normally.
  }

  /// Fires [onConsented] immediately, then persists the audit record
  /// (timestamp + policy version) in the background.  Calling the callback
  /// first keeps the UX instant and preserves existing test expectations
  /// (which do not await the storage write).
  void _grantConsent() {
    widget.onConsented();
    _persistConsentRecord();
  }

  /// Background write: ISO-8601 UTC timestamp + current policy version.
  /// Called after [onConsented] so the route transition is not delayed.
  Future<void> _persistConsentRecord() async {
    if (!mounted) return;
    final prefs = await PreferencesService.getInstance();
    final now = DateTime.now().toUtc().toIso8601String();
    await prefs.setString(PrefKeys.parentalConsentGrantedAt, now);
    await prefs.setString(PrefKeys.parentalConsentPolicyVersion,
        PrefKeys.kParentalConsentPolicyVersion);
  }

  void _generateChallenge() {
    // Use DateTime to generate deterministic-ish numbers without dart:math Random
    final now = DateTime.now();
    _a = 12 + (now.millisecond % 38); // 12–49
    _b = 10 + (now.second % 41); // 10–50
    _correctAnswer = _a + _b;
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  void _onContinue() {
    if (!_agreedToPolicy) return;
    setState(() => _showingChallenge = true);
  }

  void _onSubmitAnswer() {
    final input = int.tryParse(_answerController.text.trim());
    if (input == _correctAnswer) {
      // Fire the callback synchronously (audit write is fire-and-forget).
      _grantConsent();
    } else {
      setState(() => _errorText = 'こたえがちがいます。もう一度やってみてね。');
      _answerController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: _showingChallenge ? _buildChallenge() : _buildConsentForm(),
      ),
    );
  }

  /// Wraps fixed-height form content so it pins to the full height on tall
  /// screens (the [Spacer] pushes the primary button to the bottom) but
  /// scrolls instead of overflowing on short viewports / small devices.
  Widget _scrollableFill(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - 48).clamp(0, double.infinity),
            ),
            child: IntrinsicHeight(child: child),
          ),
        );
      },
    );
  }

  Widget _buildConsentForm() {
    return _scrollableFill(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          const Text(
            '👨‍👩‍👧 保護者の方へ',
            style: TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE0E0E0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4FC3F7).withAlpha(20),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ENG Questへようこそ',
                  style: TextStyle(
                    color: Color(0xFF263238),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'ENG Questは4〜18歳のお子様向けの英語学習RPGアプリです。\n\n'
                  'このアプリは:\n'
                  '• お名前やメールアドレスを収集しません\n'
                  '• 広告を表示しません\n'
                  '• 匿名認証を使用し、個人情報を保護します\n'
                  '• 発音練習でマイクを使用します（音声は端末内でのみ処理）',
                  style: TextStyle(
                    color: Color(0xFF607D8B),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Privacy policy link + checkbox
          GestureDetector(
            onTap: () {
              setState(() => _agreedToPolicy = !_agreedToPolicy);
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _agreedToPolicy,
                    onChanged: (v) =>
                        setState(() => _agreedToPolicy = v ?? false),
                    activeColor: const Color(0xFFFFD700),
                    checkColor: Colors.black,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: 'プライバシーポリシー',
                          style: TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 14,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        const TextSpan(
                          text: 'に同意します',
                          style: TextStyle(
                            color: Color(0xFF607D8B),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Tappable privacy policy link
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const PrivacyPolicyScreen(showCloseButton: true),
                  ),
                );
              },
              child: const Text(
                'プライバシーポリシーを読む →',
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          // Tappable terms of service link
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const TermsOfServiceScreen(showCloseButton: true),
                  ),
                );
              },
              child: const Text(
                '利用規約を読む →',
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _agreedToPolicy ? _onContinue : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
              disabledBackgroundColor: Colors.white12,
              disabledForegroundColor: Colors.white24,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'つぎへ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              Navigator.of(context).pushNamed('/parent-login');
            },
            child: const Text(
              '保護者としてログイン →',
              style: TextStyle(
                color: Color(0xFF90A4AE),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallenge() {
    return _scrollableFill(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 48),
          const Text(
            '🔒 保護者確認',
            style: TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            '保護者の方が操作していることを確認します。\n下の計算の答えを入力してください。',
            style: TextStyle(color: Color(0xFF607D8B), fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          // Math challenge
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withAlpha(40),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              '$_a + $_b = ?',
              style: const TextStyle(
                color: Color(0xFF263238),
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _answerController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF263238), fontSize: 24),
            decoration: InputDecoration(
              hintText: 'こたえ',
              hintStyle: const TextStyle(color: Color(0xFFB0BEC5)),
              errorText: _errorText,
              errorStyle: const TextStyle(color: Colors.redAccent),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFFFD700)),
              ),
            ),
            onSubmitted: (_) => _onSubmitAnswer(),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _onSubmitAnswer,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'かくにん',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => setState(() => _showingChallenge = false),
            child: const Text(
              '← もどる',
              style: TextStyle(color: Color(0xFF90A4AE), fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
