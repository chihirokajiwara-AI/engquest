import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/parent_dashboard/parent_login_screen.dart';

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
      expect(find.text('ログイン'), findsWidgets); // tab + form
      expect(find.text('新規登録'), findsOneWidget);
    });

    testWidgets('login tab shows email and password fields', (tester) async {
      await tester.pumpWidget(buildTestApp());

      expect(find.text('メールアドレス'), findsOneWidget);
      expect(find.text('パスワード'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'ログイン'), findsOneWidget);
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
      expect(find.widgetWithText(ElevatedButton, 'アカウント作成'), findsOneWidget);
    });

    testWidgets('login shows error when fields are empty', (tester) async {
      await tester.pumpWidget(buildTestApp());

      // Tap login button without entering anything
      await tester.tap(find.widgetWithText(ElevatedButton, 'ログイン'));
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

      await tester.tap(find.widgetWithText(ElevatedButton, 'アカウント作成'));
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

      await tester.tap(find.widgetWithText(ElevatedButton, 'アカウント作成'));
      await tester.pump();

      expect(find.text('パスワードが一致しません'), findsOneWidget);
    });

    testWidgets('back button is present', (tester) async {
      await tester.pumpWidget(buildTestApp());

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });
  });
}
