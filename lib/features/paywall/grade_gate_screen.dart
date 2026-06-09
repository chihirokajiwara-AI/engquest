// lib/features/paywall/grade_gate_screen.dart
// A-KEN Quest — Grade lock screen shown when users access premium content.
//
// Conversion-optimised redesign (2026-06):
//   - Trial as hero: large amber badge is the first thing parents see
//   - Social proof: static learner count
//   - Free vs Premium comparison table
//   - RPG emoji feature list matching app fantasy theme
//   - Gradient CTA button
//   - Trust signals below the fold
//
// Billing integration is unchanged:
//   purchaseMonthly() and restorePurchases() from BillingService (RevenueCat).
//
// For edilab flavor, this screen is never shown (all grades free).

import 'package:flutter/material.dart';
import '../../core/billing/billing_service.dart';
import '../../core/config/flavor_config.dart';
import '../exam_practice/eiken_exam_config.dart';

class GradeGateScreen extends StatefulWidget {
  const GradeGateScreen({
    super.key,
    required this.eikenGrade,
    required this.onSubscribe,
    this.onBack,
  });

  /// The Eiken grade the user tried to access (e.g. "4", "3", "pre2").
  final String eikenGrade;

  /// Called when user successfully subscribes (or restores).
  final VoidCallback onSubscribe;

  /// Called when user taps back. If null, Navigator.pop is used.
  final VoidCallback? onBack;

  @override
  State<GradeGateScreen> createState() => _GradeGateScreenState();
}

class _GradeGateScreenState extends State<GradeGateScreen> {
  final _billing = BillingService();
  bool _purchasing = false;
  String? _errorMessage;

  // Canonical label (handles pre2plus → 英検準2級プラス; was missing → raw key).
  String get _gradeDisplay => gradeLabelJa(widget.eikenGrade);

  Future<void> _handlePurchase() async {
    setState(() {
      _purchasing = true;
      _errorMessage = null;
    });

    try {
      await _billing.initialize();
      final success = await _billing.purchaseMonthly();
      if (success && mounted) {
        widget.onSubscribe();
      } else if (!success && mounted) {
        // User cancelled or error — stay on screen.
        setState(() => _purchasing = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _purchasing = false;
          _errorMessage = '購入に失敗しました。もう一度お試しください。';
        });
      }
    }
  }

  Future<void> _handleRestore() async {
    setState(() {
      _purchasing = true;
      _errorMessage = null;
    });

    try {
      await _billing.initialize();
      final success = await _billing.restorePurchases();
      if (success && mounted) {
        widget.onSubscribe();
      } else if (mounted) {
        setState(() {
          _purchasing = false;
          _errorMessage = '復元できるサブスクリプションが見つかりませんでした。';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _purchasing = false;
          _errorMessage = '復元に失敗しました。もう一度お試しください。';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final flavor = FlavorConfig.instance;
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = Color(flavor.primaryColor);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: colorScheme.onSurface,
          ),
          onPressed: widget.onBack ?? () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 8),

              // ── Hero trial badge ──────────────────────────────────────────
              _TrialHeroBadge(),

              const SizedBox(height: 20),

              // ── Title ─────────────────────────────────────────────────────
              Text(
                '$_gradeDisplayで合格しよう',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // (Removed a fabricated "3,000人以上が学習中" social-proof line —
              // flaw-hunt #118: a pre-launch product has no such count; a false
              // user count is 景表法/優良誤認 exposure and violates the honesty
              // spine. Real, verifiable social proof can return post-launch.)

              const SizedBox(height: 28),

              // ── Free vs Premium comparison ────────────────────────────────
              _ComparisonCard(primaryColor: primaryColor),

              const SizedBox(height: 28),

              // ── RPG feature list ──────────────────────────────────────────
              _FeatureListCard(primaryColor: primaryColor),

              // ── Error message ─────────────────────────────────────────────
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 32),

              // ── Primary CTA ───────────────────────────────────────────────
              _GradientCTAButton(
                primaryColor: primaryColor,
                purchasing: _purchasing,
                onTap: _handlePurchase,
              ),

              const SizedBox(height: 12),

              // ── Price clarification ────────────────────────────────────────
              Text(
                'トライアル後 月額¥999（いつでも解約可能）',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withAlpha(153),
                    ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              // ── Trust signals ─────────────────────────────────────────────
              _TrustSignalsRow(),

              const SizedBox(height: 16),

              // ── Restore purchases ─────────────────────────────────────────
              TextButton(
                onPressed: _purchasing ? null : _handleRestore,
                child: Text(
                  '以前の購入を復元',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 14,
                  ),
                ),
              ),

              // ── Free tier escape hatch ────────────────────────────────────
              TextButton(
                onPressed: widget.onBack ?? () => Navigator.of(context).pop(),
                child: Text(
                  '英検5級は無料で学習できます',
                  style: TextStyle(
                    color: colorScheme.onSurface.withAlpha(128),
                    fontSize: 14,
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

/// Hero amber badge that makes the 7-day free trial unmissable.
class _TrialHeroBadge extends StatelessWidget {
  const _TrialHeroBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFB300).withAlpha(80),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎁', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '月額（つきがく）¥999',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              // Honest disclosure (flaw-hunt #118): the impossible claim
              // 「クレジットカード登録不要」 was removed (App Store / Google Play
              // subscriptions ALWAYS require a payment method on file). Auto-renew
              // + the 特商法 最終確認画面 + any real free-trial offer are a CEO/legal
              // decision — escalated, not invented here.
              Text(
                '自動更新（じどうこうしん）・いつでも解約（かいやく）できます',
                style: TextStyle(
                  color: Colors.white.withAlpha(220),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Free vs Premium two-column comparison.
class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({required this.primaryColor});

  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(120),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withAlpha(80),
        ),
      ),
      child: Column(
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.outlineVariant.withAlpha(60),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '無料',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colorScheme.onSurface.withAlpha(153),
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Container(
                  width: 1,
                  height: 20,
                  color: colorScheme.outlineVariant.withAlpha(100),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.workspace_premium,
                          size: 14, color: primaryColor),
                      const SizedBox(width: 4),
                      Text(
                        'プレミアム',
                        style:
                            Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Comparison rows
          _comparisonRow(
            context,
            label: '対応グレード',
            freeValue: '5級のみ',
            premiumValue: '5級〜準1級',
            highlight: true,
            primaryColor: primaryColor,
          ),
          _comparisonRow(
            context,
            label: '模擬試験',
            freeValue: '✕',
            premiumValue: '✓',
            primaryColor: primaryColor,
          ),
          _comparisonRow(
            context,
            label: 'AIチューター',
            freeValue: '✕',
            premiumValue: '✓',
            primaryColor: primaryColor,
          ),
          _comparisonRow(
            context,
            label: '学習記録',
            freeValue: '✕',
            premiumValue: '✓',
            primaryColor: primaryColor,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _comparisonRow(
    BuildContext context, {
    required String label,
    required String freeValue,
    required String premiumValue,
    required Color primaryColor,
    bool highlight = false,
    bool isLast = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final dividerColor = colorScheme.outlineVariant.withAlpha(60);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: dividerColor),
          bottom: isLast
              ? BorderSide.none
              : BorderSide.none, // bottom handled by next row's top
        ),
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(15))
            : BorderRadius.zero,
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              freeValue,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withAlpha(128),
                  ),
            ),
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withAlpha(180),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              premiumValue,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: highlight ? primaryColor : Colors.green.shade600,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// RPG-themed feature list with emoji icons.
class _FeatureListCard extends StatelessWidget {
  const _FeatureListCard({required this.primaryColor});

  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'プレミアムでできること',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          _featureItem(context, '⚔️', '全級対応', '英検5級〜準1級を完全網羅'),
          const SizedBox(height: 12),
          _featureItem(context, '📚', '本番形式の模擬試験', '2024年改訂版に完全対応'),
          const SizedBox(height: 12),
          _featureItem(context, '🧙', 'AIチューター', '苦手を自動発見してサポート'),
          const SizedBox(height: 12),
          _featureItem(context, '📊', '保護者ダッシュボード', '学習進捗をひと目で確認'),
        ],
      ),
    );
  }

  Widget _featureItem(
    BuildContext context,
    String emoji,
    String title,
    String subtitle,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha(153),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Large gradient CTA button.
class _GradientCTAButton extends StatelessWidget {
  const _GradientCTAButton({
    required this.primaryColor,
    required this.purchasing,
    required this.onTap,
  });

  final Color primaryColor;
  final bool purchasing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Derive a darker shade for the gradient end.
    final hsl = HSLColor.fromColor(primaryColor);
    final darkerColor = hsl
        .withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0))
        .toColor();

    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: purchasing
              ? null
              : LinearGradient(
                  colors: [primaryColor, darkerColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: purchasing ? primaryColor.withAlpha(128) : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: purchasing
              ? null
              : [
                  BoxShadow(
                    color: primaryColor.withAlpha(90),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: purchasing ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          child: purchasing
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : const Text(
                  // Honest CTA (#118): the button charges ¥999/月 immediately
                  // (no free trial is configured in billing_config). 「無料で始める」
                  // on a button that takes money is the exact surprise-charge trap
                  // to avoid. If a real 7-day trial is wanted, configure the store
                  // intro offer + restore trial copy (CEO/legal decision).
                  '月額（つきがく）¥999 ではじめる  →',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Trust signal row: secure payment + platform badges.
class _TrustSignalsRow extends StatelessWidget {
  const _TrustSignalsRow();

  @override
  Widget build(BuildContext context) {
    final subtleColor =
        Theme.of(context).colorScheme.onSurface.withAlpha(100);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline, size: 13, color: subtleColor),
        const SizedBox(width: 4),
        Text(
          '安全な決済',
          style: TextStyle(color: subtleColor, fontSize: 11),
        ),
        const SizedBox(width: 16),
        Icon(Icons.apple, size: 13, color: subtleColor),
        const SizedBox(width: 2),
        Text(
          'App Store',
          style: TextStyle(color: subtleColor, fontSize: 11),
        ),
        const SizedBox(width: 16),
        Icon(Icons.android, size: 13, color: subtleColor),
        const SizedBox(width: 2),
        Text(
          'Google Play',
          style: TextStyle(color: subtleColor, fontSize: 11),
        ),
      ],
    );
  }
}
