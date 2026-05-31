import 'package:flutter/material.dart';

/// ENG Quest — Privacy Policy Screen
///
/// Displays the app's privacy policy in a scrollable view.
/// Accessible from onboarding consent gate, settings, and store listing URL.
///
/// Policy is embedded as a constant string to avoid external fetch dependencies.
/// The same text should be hosted at the privacy policy URL for store listings.
class PrivacyPolicyScreen extends StatelessWidget {
  /// If true, shows a simple close button instead of back navigation.
  final bool showCloseButton;

  const PrivacyPolicyScreen({super.key, this.showCloseButton = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text(
          'プライバシーポリシー',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: showCloseButton
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: _PrivacyPolicyContent(),
      ),
    );
  }
}

class _PrivacyPolicyContent extends StatelessWidget {
  const _PrivacyPolicyContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(
          title: 'ENG Quest プライバシーポリシー',
          body: '最終更新日: 2026年5月31日\n\n'
              'EDILAB（以下「当社」）は、ENG Quest（以下「本アプリ」）をご利用いただく'
              'お子様と保護者の皆様のプライバシーを保護することをお約束いたします。\n\n'
              '本アプリは、児童オンラインプライバシー保護法（COPPA）および'
              '個人情報保護法に準拠して設計されています。',
        ),
        _Section(
          title: '1. 収集する情報',
          body: '本アプリは個人を特定できる情報（PII）を収集しません。\n\n'
              '• 氏名、メールアドレス、電話番号は収集しません\n'
              '• 写真、位置情報、連絡先にはアクセスしません\n'
              '• 匿名認証を使用し、Firebase UIDのみで利用者を識別します\n\n'
              '本アプリが保存するデータ:\n'
              '• 年齢（学習コンテンツの適正化のため、端末にのみ保存）\n'
              '• 学習レベル（CEFR判定結果）\n'
              '• アバター選択\n'
              '• 学習進捗（習得単語数、連続学習日数など）\n\n'
              'これらのデータは個人を特定するために使用されることはありません。',
        ),
        _Section(
          title: '2. マイクの使用',
          body: '本アプリは発音練習機能においてマイクを使用します。\n\n'
              '• 音声データはリアルタイムで処理され、端末外に送信されません\n'
              '• iOS版ではApple Speech（端末内処理）を使用します\n'
              '• 音声の録音・保存は行いません',
        ),
        _Section(
          title: '3. 分析データ',
          body: '本アプリはFirebase Analyticsを使用してアプリの改善に役立てています。\n\n'
              '• 収集するデータ: 学習セッション時間、回答正答率、機能使用状況\n'
              '• 広告目的のデータ収集は行いません\n'
              '• 広告のパーソナライズは無効化されています\n'
              '• 第三者への個人データの提供は行いません',
        ),
        _Section(
          title: '4. データの保存と保護',
          body: '• 学習データはGoogle Firebaseに安全に保存されます\n'
              '• データはFirebaseセキュリティルールにより、'
              'ユーザー本人のみがアクセスできるよう保護されています\n'
              '• 端末上のデータはアプリ削除時に消去されます',
        ),
        _Section(
          title: '5. 保護者の権利',
          body: '保護者は以下の権利を有します:\n\n'
              '• お子様のデータの確認を要求する権利\n'
              '• お子様のデータの削除を要求する権利\n'
              '• データ収集への同意を撤回する権利\n\n'
              'これらの権利を行使される場合は、下記のお問い合わせ先までご連絡ください。',
        ),
        _Section(
          title: '6. 広告',
          body: '本アプリには広告は表示されません。'
              '第三者の広告ネットワークは一切使用していません。',
        ),
        _Section(
          title: '7. アプリ内購入',
          body: '本アプリでの購入はすべて保護者のアカウントを通じて行われます。'
              'お子様が直接購入を行うことはできません。',
        ),
        _Section(
          title: '8. ポリシーの変更',
          body: '本ポリシーを変更する場合は、アプリ内での通知および'
              '本ページの更新により、事前にお知らせいたします。',
        ),
        _Section(
          title: '9. お問い合わせ',
          body: 'プライバシーに関するお問い合わせ:\n\n'
              'EDILAB\n'
              'メール: privacy@edilab.co\n'
              'ウェブサイト: https://edilab.co',
        ),
        SizedBox(height: 40),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;

  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
