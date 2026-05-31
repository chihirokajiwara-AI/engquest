import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/legal/parental_consent_gate.dart';

void main() {
  group('ParentalConsentGate', () {
    testWidgets('renders consent form initially', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ParentalConsentGate(onConsented: () {}),
        ),
      );

      expect(find.textContaining('保護者の方へ'), findsOneWidget);
      expect(find.textContaining('ENG Questへようこそ'), findsOneWidget);
      expect(find.textContaining('プライバシーポリシー'), findsWidgets);
    });

    testWidgets('continue button is disabled until checkbox is checked',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ParentalConsentGate(onConsented: () {}),
        ),
      );

      // Find the continue button
      final continueButton = find.text('つぎへ');
      expect(continueButton, findsOneWidget);

      // Button should be disabled (ElevatedButton with null onPressed)
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'つぎへ'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('checking checkbox enables continue button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ParentalConsentGate(onConsented: () {}),
        ),
      );

      // Tap the checkbox
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      // Button should now be enabled
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'つぎへ'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('tapping continue shows math challenge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ParentalConsentGate(onConsented: () {}),
        ),
      );

      // Check the checkbox
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      // Tap continue
      await tester.tap(find.widgetWithText(ElevatedButton, 'つぎへ'));
      await tester.pump();

      // Should now show math challenge
      expect(find.textContaining('保護者確認'), findsOneWidget);
      expect(find.textContaining('= ?'), findsOneWidget);
      expect(find.text('かくにん'), findsOneWidget);
    });

    testWidgets('wrong answer shows error message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ParentalConsentGate(onConsented: () {}),
        ),
      );

      // Check checkbox and continue
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'つぎへ'));
      await tester.pump();

      // Enter wrong answer
      await tester.enterText(find.byType(TextField), '0');
      await tester.tap(find.text('かくにん'));
      await tester.pump();

      expect(find.textContaining('こたえがちがいます'), findsOneWidget);
    });

    testWidgets('correct answer calls onConsented', (tester) async {
      bool consented = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ParentalConsentGate(onConsented: () => consented = true),
        ),
      );

      // Check checkbox and continue
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'つぎへ'));
      await tester.pump();

      // Find the math problem text to extract the correct answer
      final challengeText = find.textContaining('= ?');
      final text = tester.widget<Text>(challengeText).data!;
      // Parse "A + B = ?" to get A and B
      final match = RegExp(r'(\d+) \+ (\d+)').firstMatch(text);
      expect(match, isNotNull);
      final a = int.parse(match!.group(1)!);
      final b = int.parse(match.group(2)!);

      // Enter correct answer
      await tester.enterText(find.byType(TextField), '${a + b}');
      await tester.tap(find.text('かくにん'));
      await tester.pump();

      expect(consented, isTrue);
    });

    testWidgets('back button returns to consent form from challenge',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ParentalConsentGate(onConsented: () {}),
        ),
      );

      // Check checkbox and continue to challenge
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'つぎへ'));
      await tester.pump();

      expect(find.textContaining('保護者確認'), findsOneWidget);

      // Tap back
      await tester.tap(find.text('← もどる'));
      await tester.pump();

      // Should be back at consent form
      expect(find.textContaining('保護者の方へ'), findsOneWidget);
    });

    testWidgets('privacy policy link navigates to privacy screen',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ParentalConsentGate(onConsented: () {}),
        ),
      );

      // Tap privacy policy link
      await tester.tap(find.text('プライバシーポリシーを読む →'));
      await tester.pumpAndSettle();

      // Should navigate to privacy policy screen
      expect(find.text('ENG Quest プライバシーポリシー'), findsOneWidget);
    });
  });
}
