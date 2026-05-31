// lib/features/paywall/grade_gate_screen.dart
// A-KEN Quest — Grade lock screen shown when users access premium content.
//
// Displays:
//   - Which grade they're trying to access
//   - What's included in the subscription
//   - CTA to subscribe (¥999/month)
//
// For edilab flavor, this screen is never shown (all grades free).

import 'package:flutter/material.dart';
import '../../core/config/flavor_config.dart';

class GradeGateScreen extends StatelessWidget {
  const GradeGateScreen({
    super.key,
    required this.eikenGrade,
    required this.onSubscribe,
    this.onBack,
  });

  /// The Eiken grade the user tried to access (e.g. "4", "3", "pre2").
  final String eikenGrade;

  /// Called when user taps the subscribe button.
  final VoidCallback onSubscribe;

  /// Called when user taps back. If null, Navigator.pop is used.
  final VoidCallback? onBack;

  String get _gradeDisplay {
    switch (eikenGrade) {
      case '5':
        return '英検5級';
      case '4':
        return '���検4級';
      case '3':
        return '英検3級';
      case 'pre2':
        return '英検準2級';
      case '2':
        return '英検2級';
      case 'pre1':
        return '英検準1級';
      default:
        return '英検$eikenGrade級';
    }
  }

  @override
  Widget build(BuildContext context) {
    final flavor = FlavorConfig.instance;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF263238)),
          onPressed: onBack ?? () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 1),
              // Lock icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Color(flavor.primaryColor).withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: Color(flavor.primaryColor),
                ),
              ),
              const SizedBox(height: 24),
              // Title
              Text(
                '$_gradeDisplayコンテンツ',
                style: const TextStyle(
                  color: Color(0xFF263238),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'このレベルの問題を解くには\nプレミアムプランが必要です',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Features list
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _featureRow(Icons.auto_stories, '全英検レベル対応（5級〜準1級）'),
                    const SizedBox(height: 12),
                    _featureRow(Icons.psychology, 'AIスペースドリピティション'),
                    const SizedBox(height: 12),
                    _featureRow(Icons.record_voice_over, '発音練習＆AI会話'),
                    const SizedBox(height: 12),
                    _featureRow(Icons.trending_up, '保護者ダッシュボード'),
                    const SizedBox(height: 12),
                    _featureRow(Icons.all_inclusive, '広告なし・無制限アクセス'),
                  ],
                ),
              ),
              const Spacer(flex: 1),
              // Subscribe CTA
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onSubscribe,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(flavor.primaryColor),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    '月額¥999で始める',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Price context
              Text(
                '7日間無料トライアル • いつでもキャンセル可能',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              // Free tier reminder
              TextButton(
                onPressed: onBack ?? () => Navigator.of(context).pop(),
                child: Text(
                  '英検5級は無料で学習できます',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF4CAF50)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF263238),
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
