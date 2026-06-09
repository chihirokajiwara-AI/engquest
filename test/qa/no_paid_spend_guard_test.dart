// Billing-safety guard (CEO 2026-06-09: "追加課金だけは絶対に防げ").
//
// The live demo must make ZERO paid-API calls. This audit fails the gate if a
// change ever wires a billable path on, so it can never happen silently:
//   • a hardcoded paid API key (Google / Anthropic / Stripe / Azure) in lib/
//   • a live `TtsService.configure(...)` call (the only thing that activates the
//     pay-per-call Google TTS path — left inert by design)
//   • a direct call to a paid vendor endpoint from client code (Claude goes via
//     the backend proxy, which is gated behind a CEO-approved deploy + secret).
//
// Tests may read the filesystem; lib/ may not (web). This scans lib/ as text.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final libFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  String body(File f) => f.readAsStringSync();

  test('no hardcoded paid-API keys committed in lib/', () {
    // Google API key (AIza…), Anthropic (sk-ant-…), Stripe secret (sk_live/sk_test),
    // OpenAI (sk-…). These prefixes never legitimately appear in client source.
    final keyPatterns = <RegExp>[
      RegExp(r'AIza[0-9A-Za-z_\-]{30,}'),
      RegExp(r'sk-ant-[0-9A-Za-z_\-]{20,}'),
      RegExp(r'sk_live_[0-9A-Za-z]{20,}'),
      RegExp(r'sk_test_[0-9A-Za-z]{20,}'),
    ];
    final offenders = <String>[];
    for (final f in libFiles) {
      final src = body(f);
      for (final p in keyPatterns) {
        if (p.hasMatch(src)) offenders.add('${f.path}: ${p.pattern}');
      }
    }
    expect(offenders, isEmpty,
        reason: 'a paid-API KEY is hardcoded in client code → would enable '
            'billable calls and leak a secret:\n${offenders.join('\n')}');
  });

  test('the pay-per-call Google TTS path is never activated at runtime', () {
    // GoogleTtsConfig.apiKey must stay null in the shipped app: the ONLY thing
    // that sets it is TtsService.configure(apiKey: …). No call site = no TTS bill.
    final callSites = <String>[];
    final callRe = RegExp(r'TtsService\.configure\s*\(');
    for (final f in libFiles) {
      for (final line in body(f).split('\n')) {
        final t = line.trimLeft();
        // Skip doc/inline comments — only real call sites count.
        if (t.startsWith('//') || t.startsWith('*') || t.startsWith('///')) {
          continue;
        }
        if (callRe.hasMatch(line)) callSites.add('${f.path}: $line');
      }
    }
    expect(callSites, isEmpty,
        reason: 'TtsService.configure(...) is called → the pay-per-call Google '
            'TTS API would fire on each word. Inject the key only behind an '
            'explicit CEO-approved switch:\n${callSites.join('\n')}');
  });

  test('client code does not call paid vendor endpoints directly', () {
    // All paid AI/TTS must go through the (deploy-gated) backend proxy, never
    // straight from the client. The Google TTS *endpoint constant* is allowed to
    // exist (it is dormant behind the null key, guarded above); a DIRECT POST to
    // api.anthropic.com / openai.com / *.cognitiveservices.azure.com is not.
    final banned = <RegExp>[
      RegExp(r'api\.anthropic\.com'),
      RegExp(r'api\.openai\.com'),
      RegExp(r'cognitiveservices\.azure\.com'),
    ];
    final offenders = <String>[];
    for (final f in libFiles) {
      final src = body(f);
      for (final p in banned) {
        if (p.hasMatch(src)) offenders.add('${f.path}: ${p.pattern}');
      }
    }
    expect(offenders, isEmpty,
        reason: 'client calls a paid vendor API directly (must go via the '
            'backend proxy):\n${offenders.join('\n')}');
  });
}
