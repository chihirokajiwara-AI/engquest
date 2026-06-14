// Perf guard (CEO 1355 cold-boot, 2026-06-14): web/index.html must preload the
// bundled JP serif so the browser fetches it in parallel with the engine instead
// of serially after FontManifest.json (~4 s in), removing the post-engine tofu
// flash. This is a single easy-to-lose <link> — lock it so a future index.html
// edit (or a `flutter create` regen) can't silently drop the optimization.
//
// dart:io is fine here: tests run on the Dart VM, and this only reads a repo file
// at test time — it never ships to web (the dart:io ban is for lib/).
@TestOn('vm')
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('web/index.html font preload (perf)', () {
    final html = File('web/index.html').readAsStringSync();

    test('preloads NotoSerifJP at the real Flutter-web asset URL', () {
      // The double-assets/ path is Flutter web's real runtime URL for a pubspec
      // asset under assets/ (verified 200 + 2.2 MB on the live build). A wrong
      // path would double-fetch, so pin the exact URL.
      expect(
        html.contains('assets/assets/fonts/NotoSerifJP.ttf'),
        isTrue,
        reason:
            'JP serif preload <link> missing or wrong path — cold-boot tofu '
            'flash regression (see CEO 1355 perf)',
      );
    });

    test('uses rel=preload as=font with crossorigin (else it double-fetches)',
        () {
      final preloadLine = html.split('\n').firstWhere(
          (l) => l.contains('NotoSerifJP.ttf') && l.contains('rel="preload"'),
          orElse: () => '');
      expect(preloadLine, isNotEmpty,
          reason: 'the NotoSerifJP <link> must be rel="preload"');
      expect(preloadLine.contains('as="font"'), isTrue,
          reason: 'font preload needs as="font"');
      expect(preloadLine.contains('crossorigin'), isTrue,
          reason: 'font preloads fetch in CORS mode even same-origin — without '
              'crossorigin the browser ignores the hint and double-fetches');
    });
  });
}
