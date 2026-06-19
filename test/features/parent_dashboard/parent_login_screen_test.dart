import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/parent_dashboard/parent_login_screen.dart';

// ParentLoginScreen is now styled with the dark-navy/gold DQ canon (#947):
// DqScene root, dqBilingual header, DqButton CTAs (GestureDetector+Container),
// dark TextField with dqBox fill. Tests verify behaviour (text/error) not the
// old bright-theme widget types (no more ElevatedButton assertions).

void main() {
  group('ParentLoginScreen', () {
    Widget buildTestApp() {
      return MaterialApp(
        home: const ParentLoginScreen(),
        routes: {
          '/parent-login': (_) => const ParentLoginScreen(),
        },
      );
    }

    testWidgets('renders login and signup tabs', (tester) async {
      await tester.pumpWidget(buildTestApp());

      expect(find.text('保護者ログイン'), findsOneWidget);
      expect(find.text('ログイン'), findsWidgets); // tab + button label
      expect(find.text('新規登録'), findsOneWidget);
    });

    testWidgets('login tab shows email and password fields', (tester) async {
      await tester.pumpWidget(buildTestApp());

      expect(find.text('メールアドレス'), findsOneWidget);
      expect(find.text('パスワード'), findsOneWidget);
      // DqButton renders the label as a plain Text inside a GestureDetector.
      expect(find.text('ログイン'), findsWidgets);
    });

    testWidgets('signup tab shows email, password, and confirm fields',
        (tester) async {
      await tester.pumpWidget(buildTestApp());

      // Tap signup tab
      await tester.tap(find.text('新規登録'));
      await tester.pumpAndSettle();

      expect(find.text('メールアドレス'), findsOneWidget);
      expect(find.text('パスワード（6文字以上）'), findsOneWidget);
      expect(find.text('パスワード（確認）'), findsOneWidget);
      expect(find.text('アカウント作成'), findsOneWidget);
    });

    testWidgets('login shows error when fields are empty', (tester) async {
      await tester.pumpWidget(buildTestApp());

      // DqButton label is a plain Text widget — tap by text.
      await tester.tap(find.text('ログイン').last);
      await tester.pump();

      expect(find.text('メールアドレスとパスワードを入力してください'), findsOneWidget);
    });

    testWidgets('signup shows error when password too short', (tester) async {
      await tester.pumpWidget(buildTestApp());

      // Switch to signup tab
      await tester.tap(find.text('新規登録'));
      await tester.pumpAndSettle();

      // Enter email and short password
      final emailField = find.widgetWithText(TextField, 'メールアドレス');
      await tester.enterText(emailField, 'test@example.com');

      final passwordField = find.widgetWithText(TextField, 'パスワード（6文字以上）');
      await tester.enterText(passwordField, '123');

      final confirmField = find.widgetWithText(TextField, 'パスワード（確認）');
      await tester.enterText(confirmField, '123');

      await tester.tap(find.text('アカウント作成'));
      await tester.pump();

      expect(find.text('パスワードは6文字以上にしてください'), findsOneWidget);
    });

    testWidgets('signup shows error when passwords do not match',
        (tester) async {
      await tester.pumpWidget(buildTestApp());

      // Switch to signup tab
      await tester.tap(find.text('新規登録'));
      await tester.pumpAndSettle();

      final emailField = find.widgetWithText(TextField, 'メールアドレス');
      await tester.enterText(emailField, 'test@example.com');

      final passwordField = find.widgetWithText(TextField, 'パスワード（6文字以上）');
      await tester.enterText(passwordField, '123456');

      final confirmField = find.widgetWithText(TextField, 'パスワード（確認）');
      await tester.enterText(confirmField, '654321');

      await tester.tap(find.text('アカウント作成'));
      await tester.pump();

      expect(find.text('パスワードが一致しません'), findsOneWidget);
    });

    testWidgets('back button is present', (tester) async {
      await tester.pumpWidget(buildTestApp());

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('renders on dark-navy DQ background (no bright scaffold)',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      // DqScene renders a Scaffold with dqNight0 background — no ElevatedButton
      // with bright Colors.white12/Color(0xFFF5F7FA) fill should exist.
      expect(find.byType(ElevatedButton), findsNothing);
    });
  });
}
