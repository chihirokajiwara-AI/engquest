// test/features/exam_practice/grade_label_test.dart
//
// gradeLabelJa is the SINGLE SOURCE OF TRUTH for the child-facing 漢字 grade
// label (#19/#28). Guards against the two defects it replaced: raw keys leaking
// for the NAMED grades ("英検pre2plus級"/"英検pre1級") and spelling drift
// ("英検準2級+" vs "英検準2級プラス").

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/exam_practice/eiken_exam_config.dart';

void main() {
  const expected = {
    '5': '英検5級',
    '4': '英検4級',
    '3': '英検3級',
    'pre2': '英検準2級',
    'pre2plus': '英検準2級プラス',
    '2': '英検2級',
    'pre1': '英検準1級',
  };

  test('every grade key maps to its canonical 漢字 label', () {
    expected.forEach((grade, label) {
      expect(gradeLabelJa(grade), equals(label), reason: 'grade $grade');
    });
  });

  test('no label leaks a raw grade key (pre2plus / pre1 / pre2)', () {
    for (final grade in expected.keys) {
      final label = gradeLabelJa(grade);
      expect(label.contains('pre'), isFalse,
          reason: 'raw key leaked in "$label"');
    }
  });

  test('pre2plus is プラス, never "+" (spelling consistency)', () {
    expect(gradeLabelJa('pre2plus'), equals('英検準2級プラス'));
    expect(gradeLabelJa('pre2plus').contains('+'), isFalse);
  });
}
