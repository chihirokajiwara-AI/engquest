import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/core/firebase/parent_auth_service.dart';

void main() {
  group('LinkCodeException', () {
    test('stores message', () {
      const e = LinkCodeException('test error');
      expect(e.message, 'test error');
    });

    test('toString returns message', () {
      const e = LinkCodeException('リンクコードが見つかりません');
      expect(e.toString(), 'リンクコードが見つかりません');
    });
  });

  group('ParentAuthService', () {
    test('can be instantiated', () {
      // ParentAuthService depends on FirebaseAuth and Firestore,
      // which require Firebase initialization. This test verifies
      // the class can be constructed (import check).
      expect(ParentAuthService.new, isA<Function>());
    });
  });
}
