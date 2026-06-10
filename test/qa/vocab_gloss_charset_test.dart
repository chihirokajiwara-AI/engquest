// test/qa/vocab_gloss_charset_test.dart
// #97 — Vocab gloss charset guard (文字化け / foreign-script corruption).
//
// Every vocab item's `jpTranslation` is shown to the child as Japanese — as the
// answer's meaning AND (since #97) as the gloss of each wrong choice in the
// 大問1 reveal. A gloss containing characters the bundled subset font does not
// carry renders as silent tofu (□): no error, no 404 — only a manual glyph check
// or a human catches it. This guard found `candid` → "솔직な" (Korean 솔직 + な)
// silently shipped in the 準1級 bank.
//
// It asserts every jpTranslation contains ONLY characters from the Japanese
// writing system + the ASCII/fullwidth punctuation actually used in the data
// (surveyed: kanji, hiragana, katakana, JP punctuation, fullwidth forms, ASCII).
// Anything else — Hangul, Cyrillic, other foreign scripts — fails the gate.
//
// SCOPE (honest): this is a FOREIGN-SCRIPT corruption tripwire, not a font-
// coverage proof. It allows the whole CJK-Unified block, which is wider than the
// bundled subset, so a valid-block kanji the subset happens to lack would pass
// here yet still tofu. Full subset coverage is verified out-of-band with
// fontTools (0 gloss chars missing as of #97); wiring that into CI is follow-up.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

bool _isAllowed(int o) {
  return (o >= 0x3040 && o <= 0x309F) || // hiragana
      (o >= 0x30A0 && o <= 0x30FF) || // katakana
      (o >= 0x4E00 && o <= 0x9FFF) || // CJK unified (kanji)
      (o >= 0x3000 && o <= 0x303F) || // CJK symbols & punctuation （、。「」…）
      (o >= 0xFF00 && o <= 0xFFEF) || // fullwidth forms （ＡＢ１２！）
      o < 0x80; // ASCII (latin glosses, digits, punctuation, spaces)
}

void main() {
  test(
      'every vocab jpTranslation uses only Japanese/ASCII glyphs (#97 no-tofu)',
      () {
    final dir = Directory('assets/data');
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => RegExp(r'eiken.*_vocab\.json$').hasMatch(f.path))
        .toList();
    expect(files, isNotEmpty, reason: 'vocab banks must be present');

    final offenders = <String>[];
    var checked = 0;
    for (final f in files) {
      final data = jsonDecode(f.readAsStringSync());
      final words = (data is Map && data['words'] is List)
          ? data['words'] as List
          : (data as List);
      for (final w in words) {
        final gloss = (w['jpTranslation'] as String?) ?? '';
        checked++;
        for (final rune in gloss.runes) {
          if (!_isAllowed(rune)) {
            offenders.add(
                '${f.path.split('/').last} ${w['id']} (${w['word']}): '
                '"$gloss" has U+${rune.toRadixString(16).toUpperCase().padLeft(4, '0')}');
            break;
          }
        }
      }
    }
    expect(checked, greaterThan(5000), reason: 'sanity: most banks loaded');
    expect(offenders, isEmpty,
        reason: 'foreign-script / non-Japanese glyphs in glosses → tofu:\n'
            '${offenders.take(20).join('\n')}');
  });
}
