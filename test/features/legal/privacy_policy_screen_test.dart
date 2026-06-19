import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/legal/privacy_policy_screen.dart';

void main() {
  group('PrivacyPolicyScreen', () {
    testWidgets('renders title and sections', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PrivacyPolicyScreen()),
      );

      expect(find.text('プライバシーポリシー'), findsOneWidget);
      expect(find.text('コトバ探偵 プライバシーポリシー'), findsOneWidget);
      expect(find.text('1. 収集する情報'), findsOneWidget);
      expect(find.text('2. マイクの使用'), findsOneWidget);
      expect(find.text('6. 広告'), findsOneWidget);
      expect(find.text('9. お問い合わせ'), findsOneWidget);
    });

    testWidgets('shows close button when showCloseButton is true',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PrivacyPolicyScreen(showCloseButton: true),
        ),
      );

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('shows back button when showCloseButton is false',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PrivacyPolicyScreen(),
                  ),
                ),
                child: const Text('Go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      // Default back button (no close icon)
      expect(find.byIcon(Icons.close), findsNothing);
    });
  });
}
