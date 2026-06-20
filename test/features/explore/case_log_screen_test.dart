// 事件簿 (Case File) — post-clear replayability (rubric N12, 2026-06-14).
// Locks the bookmark-assembly logic + that the screen renders the child's OWN
// progress honestly (unsolved ナゾ lore stays hidden).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engquest/features/explore/case_log_screen.dart';
import 'package:engquest/features/explore/hotspot.dart';
import 'package:engquest/features/explore/scene_solved_store.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('assembledBookmarkLine', () {
    test('nothing cleared → all hidden (？)', () {
      final line = assembledBookmarkLine(const {});
      expect(line.contains('Once, I'), isFalse);
      expect(line.split('？').length - 1, kCaseLogGradeOrder.length,
          reason: 'every uncleared chapter shows ？');
    });

    test('all cleared → the complete assembled sentence + the name', () {
      final line = assembledBookmarkLine(kCaseLogGradeOrder.toSet());
      expect(line,
          'Once, I told a story, and the whole grey world turned to colour. — アイラ');
      expect(line.contains('？'), isFalse);
    });

    test('partial → only cleared chapters reveal their bookmark, in order', () {
      final line = assembledBookmarkLine({'5', '4'});
      expect(line.startsWith('Once, I told a story, ？'), isTrue,
          reason: 'cleared 5級+4級 reveal; the rest stay ？');
    });
  });

  group('nextChapterTitleJa (episodic forward-pull, N6/N12)', () {
    test('returns the NEXT chapter title in play order', () {
      expect(nextChapterTitleJa('5'), kTown4Scene.titleJa);
      expect(nextChapterTitleJa('pre2'), kTownPre2PlusScene.titleJa);
    });

    test('the final chapter (準1級) has no next → null (arc finale instead)', () {
      expect(nextChapterTitleJa('pre1'), isNull);
    });

    test('an unknown grade has no next → null', () {
      expect(nextChapterTitleJa('zzz'), isNull);
    });

    test('chapter order matches the 事件簿 order (no drift)', () {
      expect(kChapterGradeOrder, kCaseLogGradeOrder,
          reason: 'the scene-clear teaser and the 事件簿 must agree on order');
    });
  });

  group('isChapterCleared', () {
    final npcIdx = [
      for (var i = 0; i < kTown5Scene.hotspots.length; i++)
        if (kTown5Scene.hotspots[i].kind == HotspotKind.npc) i,
    ];

    test('false until every NPC ナゾ is solved', () {
      expect(isChapterCleared(kTown5Scene, const {}), isFalse);
      expect(isChapterCleared(kTown5Scene, {npcIdx.first}), isFalse);
      expect(isChapterCleared(kTown5Scene, npcIdx.toSet()), isTrue);
    });

    test('a found coin alone does not clear the chapter', () {
      final coinIdx =
          kTown5Scene.hotspots.indexWhere((h) => h.kind == HotspotKind.coin);
      expect(isChapterCleared(kTown5Scene, {coinIdx}), isFalse);
    });
  });

  group('CaseLogScreen', () {
    testWidgets('renders the 事件簿 with the bookmark header + chapter tiles',
        (tester) async {
      tester.view.physicalSize = const Size(440, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: CaseLogScreen()));
      await tester.pumpAndSettle();
      expect(find.text('🔖 ことばの しおり'), findsOneWidget);
      // All-uncleared on a fresh store → the sentence is hidden.
      expect(find.textContaining('Once, I'), findsNothing);
      expect(find.textContaining('みかいふう'), findsWidgets);
      // Warm first-visit state, not a bleak all-？ board.
      expect(find.textContaining('さいしょの 事件'), findsOneWidget,
          reason: 'an empty 事件簿 should invite the first case, not feel bleak');
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'a CLEARED chapter reveals its bookmark + the 解決 finale re-read',
        (tester) async {
      tester.view.physicalSize = const Size(440, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      // Clear all 5級 ナゾ.
      for (var i = 0; i < kTown5Scene.hotspots.length; i++) {
        if (kTown5Scene.hotspots[i].kind == HotspotKind.npc) {
          await SceneSolvedStore.markSolved('5', i);
        }
      }
      await tester.pumpWidget(const MaterialApp(home: CaseLogScreen()));
      await tester.pumpAndSettle();
      // 5級's bookmark word is now revealed in the assembling sentence.
      expect(find.textContaining('Once, I'), findsWidgets,
          reason: '5級 cleared → its bookmark "Once, I" reveals');
      // …and the cleared case shows the detective 解決 (case-closed) ink-stamp
      // (#186 de-DQ identity: replaced the old "✓ かいけつ" gold text + 🎉 emoji).
      // The stamp's 解決 label proves the cleared-state rendering + finale re-read.
      expect(find.textContaining('解決'), findsWidgets,
          reason: 'a cleared chapter shows the 解決 case-closed stamp (N12)');
      expect(tester.takeException(), isNull);
    });
  });
}
