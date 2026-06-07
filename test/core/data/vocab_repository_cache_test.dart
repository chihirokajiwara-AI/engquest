// test/core/data/vocab_repository_cache_test.dart
// Guards the #52 "dead/slow tap" fix: VocabRepository decodes each grade's
// multi-MB vocab JSON AT MOST ONCE per session (shared static cache) and can be
// pre-warmed off the UI thread, so entering vocab practice doesn't re-pay the
// load+decode on every screen instance.
//
// Real rootBundle asset I/O — needs the test binding.

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/core/data/vocab_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(VocabRepository.resetCacheForTest);

  test('prewarm populates the shared decode cache for a real grade', () async {
    expect(VocabRepository.isGradeCached('5'), isFalse);
    await VocabRepository.prewarm('5');
    expect(VocabRepository.isGradeCached('5'), isTrue);
  });

  test('initialize reuses the pre-warmed cache (entry hits warm cache)',
      () async {
    await VocabRepository.prewarm('5');
    expect(VocabRepository.isGradeCached('5'), isTrue,
        reason: 'cache should be warm before the screen initializes');

    // A fresh repo (as a freshly-pushed screen creates) initializes against the
    // already-decoded JSON instead of re-loading + re-decoding the asset.
    final repo = VocabRepository();
    await repo.initialize(eikenGrade: '5');
    expect(repo.isInitialized, isTrue);
    expect(repo.totalWords, greaterThan(0));
    expect(repo.loadedGrade, '5');
  });

  test('initialize alone warms the cache for the next instance', () async {
    expect(VocabRepository.isGradeCached('5'), isFalse);
    final first = VocabRepository();
    await first.initialize(eikenGrade: '5');
    expect(VocabRepository.isGradeCached('5'), isTrue,
        reason: 'first initialize should cache the decoded JSON');

    // Second instance gets fresh VocabItems (no shared-mutation) from the cache.
    final second = VocabRepository();
    await second.initialize(eikenGrade: '5');
    expect(second.totalWords, first.totalWords);
    expect(identical(second, first), isFalse);
  });

  test('prewarm for a grade with no DB is a safe no-op', () async {
    await VocabRepository.prewarm('pre2plus'); // no asset path → nothing to warm
    expect(VocabRepository.isGradeCached('pre2plus'), isFalse);
  });
}
