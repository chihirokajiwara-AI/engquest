// COPPA privacy guard (children's app — anonymous auth, no PII collection).
//
// Verified 2026-06-14: analytics sends only non-PII aggregates (word_id,
// cefr_level, grade, accuracy, latency_ms, session_duration_sec, words_practiced,
// ab_group, …); setUserId uses the anonymous Firebase uid; setUserProperty has no
// call sites; no Firestore write contains an email (parent email lives only in
// Firebase Auth). This gate locks that: a future change that names a PII-shaped
// telemetry key, or logs an email/name literal through analytics, fails CI so a
// child-PII leak into Firebase Analytics can never ship silently.
//
// Tests may read the filesystem; lib/ may not (web). This scans lib/ as text.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Telemetry KEY names (param/event/user-property identifiers) that would
  // indicate PII collection. Two classes:
  //  • SUBSTRING tokens — unambiguous PII markers with no legitimate non-PII use,
  //    matched anywhere (so 'child_email' / 'parent_email' are caught even though
  //    an underscore defeats \b).
  //  • NAME tokens — boundary/prefix-anchored, because bare 'name' legitimately
  //    appears in non-PII keys like 'step_name' / 'event_name' (must NOT flag).
  final piiSubstring = RegExp(
    r'(email|e_mail|phone|password|passwd|\bssn\b|birth|street|postal|'
    r'zipcode|zip_code|geoloc|geo_loc|latlng|lat_lng|\bgps\b)',
    caseSensitive: false,
  );
  final piiNameKey = RegExp(
    r'(first_?name|last_?name|full_?name|real_?name|child_?name|'
    r'parent_?name|user_?name|username)',
    caseSensitive: false,
  );
  bool isPiiKey(String s) => piiSubstring.hasMatch(s) || piiNameKey.hasMatch(s);
  // A literal email address embedded in a telemetry call.
  final emailLiteral = RegExp(r'''['"][\w.+-]+@[\w-]+\.[\w.-]+['"]''');

  List<File> dartFiles(String dir) => Directory(dir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('analytics telemetry keys name no PII field', () {
    // The canonical leak surface: the analytics module defines every event /
    // param / user-property key string. None may name a PII field.
    final offenders = <String>[];
    for (final f in dartFiles('lib/core/analytics')) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue; // skip comments
        // Only inspect string literals (the actual keys sent to Firebase).
        for (final m in RegExp('''['"]([^'"]+)['"]''').allMatches(line)) {
          final literal = m.group(1)!;
          if (isPiiKey(literal)) {
            offenders.add('${f.path}:${i + 1}: "$literal"');
          }
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'A telemetry key names a PII field (COPPA risk):\n'
            '${offenders.join('\n')}');
  });

  test('no email literal is passed through an analytics call in lib/', () {
    // Catches a direct PII log: logEvent/setUserId/setUserProperty(... "x@y.z").
    final analyticsCall = RegExp(r'(logEvent|setUserId|setUserProperty)\s*\(');
    final offenders = <String>[];
    for (final f in dartFiles('lib')) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (analyticsCall.hasMatch(lines[i]) &&
            emailLiteral.hasMatch(lines[i])) {
          offenders.add('${f.path}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty,
        reason:
            'An email literal is passed to an analytics call (COPPA leak):\n'
            '${offenders.join('\n')}');
  });
}
