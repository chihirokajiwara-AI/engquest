import 'package:flutter/material.dart';

/// ENG Quest — Terms of Service Screen
///
/// Displays the app's terms of service in a scrollable view.
/// Accessible from the parental consent gate, settings, and the parent
/// dashboard's settings tab.
///
/// Terms are embedded as a constant string to avoid external fetch dependencies.
class TermsOfServiceScreen extends StatelessWidget {
  /// If true, shows a simple close button instead of back navigation.
  final bool showCloseButton;

  const TermsOfServiceScreen({super.key, this.showCloseButton = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text(
          '利用規約',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: showCloseButton
            ? IconButton(
                tooltip: 'とじる / Close',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: _TermsContent(),
      ),
    );
  }
}

class _TermsContent extends StatelessWidget {
  const _TermsContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(
          title: 'ENG Quest 利用規約',
          body: '最終更新日：2026年5月31日',
        ),
        _Section(
          title: '第1条（適用）',
          body: 'この利用規約は、ENG Quest（以下「本サービス」）の利用に関する条件を定めるものです。',
        ),
        _Section(
          title: '第2条（利用資格）',
          body: '• 本サービスは4歳以上18歳以下のお子様を対象としています\n'
              '• 18歳未満の方は、保護者の同意を得た上でご利用ください',
        ),
        _Section(
          title: '第3条（アカウント）',
          body: '• 匿名認証を使用し、個人情報の入力は不要です\n'
              '• アカウントはデバイスに紐づきます',
        ),
        _Section(
          title: '第4条（禁止事項）',
          body: '• 不適切な言葉の入力\n'
              '• 他のユーザーへの迷惑行為\n'
              '• サービスの不正利用',
        ),
        _Section(
          title: '第5条（AI対話機能）',
          body: '• NPC対話にはAI（Claude）を使用しています\n'
              '• AI の応答は教育目的に限定されています\n'
              '• 不適切な入力はフィルタリングされます',
        ),
        _Section(
          title: '第6条（知的財産権）',
          body: '本サービスのコンテンツの著作権はAesthetic Inc.に帰属します',
        ),
        _Section(
          title: '第7条（免責事項）',
          body: '• 本サービスは英語学習の補助ツールであり、学習成果を保証するものではありません\n'
              '• サービスの一時的な中断について責任を負いません',
        ),
        _Section(
          title: '第8条（料金）',
          body: '• EDILAB版：EDILABの授業料に含まれます（追加料金なし）\n'
              '• A-KEN Quest版：月額999円（税込）',
        ),
        _Section(
          title: '第9条（解約）',
          body: '• いつでも解約可能です\n'
              '• 解約月の月末までサービスをご利用いただけます',
        ),
        _Section(
          title: '第10条（規約の変更）',
          body: '• 本規約は予告なく変更される場合があります\n'
              '• 変更後のご利用をもって同意とみなします',
        ),
        _Section(
          title: '第11条（準拠法）',
          body: '本規約は日本法に準拠します',
        ),
        _Section(
          title: 'お問い合わせ',
          body: 'support@edilab.co',
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
