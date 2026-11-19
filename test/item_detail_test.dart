// Tests for the item page (plan 2026-11-02, Task 24, End state 9).
//
// The page reads one item's own attempts from a memory store over the shipped catalog, with an
// injected clock. The cases: the pure `itemDetailOf` (the state from the item's own attempts,
// PIN-1; the probes seen clear; what remains to Mastered or to regain; the Say-it counts; the
// history newest first with whether each answer counted), the page's pill and n of 4, next
// review, history rows, the "no production probe yet" line where the kind has none (A8) and the
// "one question kind only" line on a one-template item (PIN-15), and Practice now, a one-item
// session written as early practice when the item is not due (PIN-14: a clear changes nothing,
// a wrong counts) and as a review when it is. A fake probe builder stands in for the probe
// widgets, as in session_widget_test.dart. The page is reached from a list: a row of the study
// record page opens it.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:habit_craft/components/pages/quiet_room_mastery/attempt.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/drill_recorder.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/fsrs.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/item_catalog.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/item_detail_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_memory.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/local_day.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/mastery_debug_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/mastery_rule.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/session_widget.dart';

import 'jp_screen_harness.dart' show holdHttpRequests;

Map<String, dynamic> _read(String path) =>
    json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;

final catalog = ItemCatalog.fromDocs(_read('assets/lessons/jp_grammar.json'),
    _read('assets/lessons/jp_lessons.json'));

ItemDef firstOf(ItemKind kind) => catalog.ofKind(kind).first;

/// A grammar point with Say-it examples and at least three scored probes.
ItemDef grammarWithSayIt() => catalog.ofKind(ItemKind.grammar).firstWhere((i) =>
    i.probes.any((p) => p.template == kSayItTemplate) && i.probeCount >= 3);

const int today = 300;

/// 10:00 local on [day].
DateTime at(int day) => dayStart(day).add(const Duration(hours: 6));

/// An answer on [item] on [day].
Attempt answer(ItemDef item, int day, Grade grade,
    {ProbeDef? probe,
    Source source = Source.review,
    bool wasDue = true,
    int? hintLevel}) {
  final p = probe ?? item.scoredProbes.first;
  return Attempt(
    itemId: item.id,
    probeId: p.id,
    template: p.template,
    production: p.production,
    selfGraded: p.selfGraded,
    atUtc: at(day).toUtc(),
    localDay: day,
    grade: grade,
    rating: fsrsRatingFor(grade),
    hintLevel: hintLevel ?? (grade == Grade.hinted ? 1 : 0),
    wasDue: wasDue,
    source: source,
    sessionId: 'test',
  );
}

Future<void> record(JpStore store, Attempt a) => store.recordAnswer(a,
    item: catalog.byId(a.itemId), scheduler: const FsrsScheduler());

/// The fake probe: the item id, four answers and a wrong with the answer already shown.
Widget fakeProbe(BuildContext context, SessionProbeRequest r) {
  final probe = r.item.scoredProbes.first;
  DrillAnswer draft(Grade g, {bool shown = false}) => DrillAnswer(
      itemId: r.item.id,
      probeId: probe.id,
      template: probe.template,
      production: probe.production,
      selfGraded: probe.selfGraded,
      grade: g,
      hintLevel: g == Grade.hinted ? 1 : 0,
      answerShown: shown);
  return Column(children: [
    Text('probe ${r.item.id}'),
    for (final g in [Grade.clear, Grade.hinted, Grade.wrong, Grade.unscored])
      TextButton(
          onPressed: () => r.onAnswer(draft(g)),
          child: Text('answer ${g.name}')),
    // A wrong whose answer was already on screen (a self-graded Missed it).
    TextButton(
        onPressed: () => r.onAnswer(draft(Grade.wrong, shown: true)),
        child: const Text('answer shown wrong')),
  ]);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
}

Future<void> tapText(WidgetTester tester, String label) async {
  final f = find.text(label);
  expect(f, findsOneWidget, reason: 'a "$label" control');
  await tester.ensureVisible(f);
  await tester.tap(f);
  await settle(tester);
}

Future<void> pumpItem(WidgetTester tester, JpStore store, ItemDef item) async {
  tester.view.physicalSize = const Size(1000, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: ItemDetailWidget(
      itemId: item.id,
      store: store,
      catalog: catalog,
      clock: FixedClock(at(today)),
      probeBuilder: fakeProbe,
    ),
  ));
  await settle(tester);
}

bool shows(String text) => find.text(text).evaluate().isNotEmpty;
bool showsPart(String text) => find.textContaining(text).evaluate().isNotEmpty;

void main() {
  setUpAll(holdHttpRequests);

  group('itemDetailOf', () {
    test('the state is a replay of the item\'s own attempts (PIN-1)', () {
      final word = firstOf(ItemKind.word);
      final attempts = [
        answer(word, today - 10, Grade.clear),
        answer(word, today - 5, Grade.clear,
            probe: word.scoredProbes.elementAt(2)),
      ];
      final d = itemDetailOf(word, attempts, dueDay: today + 3);
      expect(d.state, masteryFromAttempts(word, attempts));
      expect(d.state.status, MasteryStatus.learning);
      expect(d.state.clearCount, 2);
      expect(d.dueDay, today + 3);
    });

    test('lists the probes seen clear, Say-it and hinted answers left out', () {
      final g = grammarWithSayIt();
      final scored = g.scoredProbes.toList();
      final sayIt = g.probes.firstWhere((p) => p.template == kSayItTemplate);
      final d = itemDetailOf(g, [
        answer(g, today - 9, Grade.clear, probe: scored[0]),
        answer(g, today - 8, Grade.hinted, probe: scored[1]),
        answer(g, today - 7, Grade.clear, probe: scored[0]),
        answer(g, today - 6, Grade.clear, probe: sayIt, source: Source.sayIt),
      ]);
      expect(d.seenClear, {scored[0].id});
    });

    test('counts the Say-it tries and clears apart from the four clears', () {
      final g = grammarWithSayIt();
      final sayIt = g.probes.firstWhere((p) => p.template == kSayItTemplate);
      final d = itemDetailOf(g, [
        answer(g, today - 3, Grade.clear, probe: sayIt, source: Source.sayIt),
        answer(g, today - 2, Grade.hinted, probe: sayIt, source: Source.sayIt),
        answer(g, today - 1, Grade.clear, probe: sayIt, source: Source.sayIt),
      ]);
      expect(d.sayItTries, 3);
      expect(d.sayItClear, 2);
      expect(d.state.status, MasteryStatus.neu,
          reason: 'the Say-it track never counts (D4)');
    });

    test(
        'marks each answer counted or not, newest first: a hinted, an early clear and a '
        'second clear on one day never count (PIN-3, PIN-14)', () {
      final word = firstOf(ItemKind.word);
      final d = itemDetailOf(word, [
        answer(word, today - 9, Grade.clear),
        answer(word, today - 9, Grade.clear),
        answer(word, today - 8, Grade.hinted),
        answer(word, today - 7, Grade.clear,
            source: Source.early, wasDue: false),
        answer(word, today - 6, Grade.clear),
      ]);
      expect([for (final r in d.history) r.attempt.localDay],
          [today - 6, today - 7, today - 8, today - 9, today - 9]);
      expect([for (final r in d.history) r.counted],
          [true, false, false, false, true]);
    });

    test('says what remains to Mastered', () {
      final word = firstOf(ItemKind.word);
      final d = itemDetailOf(word, [answer(word, today - 4, Grade.clear)]);
      expect(d.remaining,
          contains('3 more clears while due, each on a different day'));
      expect(d.remaining.any((l) => l.contains('$kFinalGapDays days')), isTrue);
      expect(d.remaining, contains(kNeedSecondKindLine));
      expect(d.remaining, contains(kNeedProductionLine),
          reason: 'the first clear was the card, which is not production');
    });

    test('says how many more different sentences a grammar point still needs',
        () {
      final g = grammarWithSayIt();
      final d = itemDetailOf(g, [answer(g, today - 4, Grade.clear)]);
      expect(d.remaining, contains('clears on 2 more different sentences'));
    });

    test('says what remains to regain a Shaky item, and nothing for Mastered',
        () {
      final word = firstOf(ItemKind.word);
      final shaky = MasteryState.initial(word.id)
          .copyWith(status: MasteryStatus.shaky, clears: const [
        ClearRef(day: 1, template: 'card', production: false, probeId: 'card')
      ]);
      expect(remainingFor(word, shaky).first,
          '1 more clear while due, at least $kRegainGapDays days after the first');
      final mastered = MasteryState.initial(word.id)
          .copyWith(status: MasteryStatus.mastered);
      expect(remainingFor(word, mastered), [kMasteredRemains]);
    });
  });

  group('the item page', () {
    testWidgets(
        'shows the pill with n of 4, the next review, the probes seen clear and the history',
        (tester) async {
      final store = JpStoreMemory();
      final word = firstOf(ItemKind.word);
      final typed = word.scoredProbes.firstWhere((p) => p.template == 'typed');
      await record(store, answer(word, today - 12, Grade.clear));
      await record(store, answer(word, today - 6, Grade.hinted, probe: typed));
      await record(store, answer(word, today - 5, Grade.clear, probe: typed));
      await pumpItem(tester, store, word);

      expect(shows(word.title), isTrue);
      expect(shows('2 of 4 clears'), isTrue);
      final due = (await store.srs(word.id))!.dueDay;
      expect(shows('Next review: ${dueLabel(due, today)}'), isTrue);
      expect(shows('Seen clear: 2 of ${word.probeCount}'), isTrue);
      // Each history row: date, grade, hint level, probe, and whether it counted.
      expect(
          shows(DateFormat('EEE d MMM').format(dateOfDay(today - 5))), isTrue);
      expect(
          shows(DateFormat('EEE d MMM').format(dateOfDay(today - 12))), isTrue);
      expect(showsPart('With a hint · hint 1 · Type the reading'), isTrue);
      expect(showsPart('Clear · Type the reading'), isTrue);
      expect(showsPart('Clear · Recall card'), isTrue);
      expect(find.textContaining('counted'), findsNWidgets(3));
      expect(find.textContaining('not counted'), findsOneWidget);
      expect(shows(kPracticeNow), isTrue);
      expect(shows(kNoProductionProbeLine), isFalse);
      expect(shows(kOneTemplateLine), isFalse);
    });

    testWidgets('a New item with no schedule says it is not in the queue yet',
        (tester) async {
      final store = JpStoreMemory();
      final word = firstOf(ItemKind.word);
      await pumpItem(tester, store, word);
      expect(shows('0 of 4 clears'), isTrue);
      expect(shows(kNotQueuedLine), isTrue);
      expect(shows(kNoAnswersLine), isTrue);
    });

    testWidgets('a seeded item shows its seeded due day', (tester) async {
      final store = JpStoreMemory();
      final word = firstOf(ItemKind.word);
      await store.appendSeed(word.id, today + 2, atUtc: at(today).toUtc());
      await pumpItem(tester, store, word);
      expect(shows('Next review: ${dueLabel(today + 2, today)}'), isTrue);
    });

    testWidgets('a pair has no production probe yet (A8)', (tester) async {
      final pair = firstOf(ItemKind.pair);
      expect(pair.hasProductionProbe, isFalse);
      expect(pair.templateCount, 2);
      await pumpItem(tester, JpStoreMemory(), pair);
      expect(shows(kNoProductionProbeLine), isTrue);
      expect(shows(kOneTemplateLine), isFalse);
    });

    testWidgets(
        'a one-template item says one question kind only (PIN-15); a table row also has '
        'no production probe', (tester) async {
      final particle = firstOf(ItemKind.particle);
      expect(particle.templateCount, 1);
      await pumpItem(tester, JpStoreMemory(), particle);
      expect(shows(kOneTemplateLine), isTrue);
      expect(shows(kNoProductionProbeLine), isFalse);

      final row = firstOf(ItemKind.tableRow);
      await pumpItem(tester, JpStoreMemory(), row);
      expect(shows(kOneTemplateLine), isTrue);
      expect(shows(kNoProductionProbeLine), isTrue);
    });

    testWidgets(
        'a conjugation idea says one question kind only and still lists more different verbs',
        (tester) async {
      final conj = catalog
          .ofKind(ItemKind.conjugation)
          .firstWhere((i) => i.probeCount >= 2);
      expect(conj.templateCount, 1);
      await pumpItem(tester, JpStoreMemory(), conj);
      expect(shows(kOneTemplateLine), isTrue);
      expect(showsPart('more different verb'), isTrue);
    });

    testWidgets('a grammar point shows its Say-it counts', (tester) async {
      final store = JpStoreMemory();
      final g = grammarWithSayIt();
      final sayIt = g.probes.firstWhere((p) => p.template == kSayItTemplate);
      await record(
          store,
          answer(g, today - 2, Grade.clear,
              probe: sayIt, source: Source.sayIt));
      await record(
          store,
          answer(g, today - 1, Grade.hinted,
              probe: sayIt, source: Source.sayIt));
      await pumpItem(tester, store, g);
      expect(shows('Say it: 2 tries · 1 clear'), isTrue);
      expect(shows(kSayItNeverCounts), isTrue);
    });
  });

  group('Practice now (PIN-14)', () {
    testWidgets(
        'on an item not due, a clear is early practice: written early, nothing changes',
        (tester) async {
      final store = JpStoreMemory();
      final word = firstOf(ItemKind.word);
      await record(store, answer(word, today - 1, Grade.clear));
      final srsBefore = await store.srs(word.id);
      final masteryBefore = await store.mastery(word.id);
      expect(srsBefore!.dueDay, greaterThan(today));
      await pumpItem(tester, store, word);

      await tapText(tester, kPracticeNow);
      expect(shows('probe ${word.id}'), isTrue);
      await tapText(tester, 'answer clear');
      expect(shows(kEarlyNoChange), isTrue);

      final written = (await store.attempts(itemId: word.id)).last;
      expect(written.source, Source.early);
      expect(written.wasDue, isFalse);
      expect(written.grade, Grade.clear);
      expect(await store.srs(word.id), srsBefore);
      expect(await store.mastery(word.id), masteryBefore);
      expect(await store.day(today), isNull,
          reason: 'practice never touches the day\'s session record');

      await tapText(tester, 'Done');
      expect(shows(kPracticeNow), isTrue, reason: 'back on the item page');
      expect(shows('1 of 4 clears'), isTrue);
      expect(find.textContaining('not counted'), findsOneWidget);
    });

    testWidgets(
        'on an item not due, a wrong counts: the count resets, due tomorrow',
        (tester) async {
      final store = JpStoreMemory();
      final word = firstOf(ItemKind.word);
      await record(store, answer(word, today - 1, Grade.clear));
      await pumpItem(tester, store, word);

      await tapText(tester, kPracticeNow);
      await tapText(tester, 'answer wrong');
      // A wrong shows no result card (ASK-9): the probe stays, showing its answer, under one
      // Next. No verdict title, and never the retired 'Not this time'.
      expect(shows('probe ${word.id}'), isTrue, reason: 'the probe stays');
      expect(find.text('Next'), findsOneWidget);
      expect(shows('Wrong'), isFalse);
      expect(shows('It comes back tomorrow.'), isFalse);
      expect(find.textContaining('Not this time'), findsNothing);

      final written = (await store.attempts(itemId: word.id)).last;
      expect(written.source, Source.early);
      expect((await store.srs(word.id))!.dueDay, today + 1);
      expect((await store.mastery(word.id))!.clearCount, 0);

      // A held probe takes no second answer.
      await tester.tap(find.text('answer clear'));
      await settle(tester);
      expect((await store.attempts(itemId: word.id)).length, 2);

      await tapText(tester, 'Next');
      await tapText(tester, 'Done');
      expect(shows('0 of 4 clears'), isTrue);
      // The history labels a wrong answer Missed (ASK-9).
      expect(showsPart('Missed · early · Recall card'), isTrue);
      expect(find.textContaining('Wrong'), findsNothing);
      expect(find.textContaining('Not this time'), findsNothing);
    });

    testWidgets(
        'a wrong with the answer already on screen moves straight on, no card (ASK-9)',
        (tester) async {
      final store = JpStoreMemory();
      final word = firstOf(ItemKind.word);
      await store.appendSeed(word.id, today, atUtc: at(today - 1).toUtc());
      await pumpItem(tester, store, word);
      await tapText(tester, kPracticeNow);
      await tapText(tester, 'answer shown wrong');
      expect(shows('probe ${word.id}'), isFalse);
      expect(find.text('Next'), findsNothing);
      expect(shows('Practice done'), isTrue);
      expect((await store.attempts(itemId: word.id)).single.grade, Grade.wrong);
      await tapText(tester, 'Done');
      expect(showsPart('Missed · Recall card'), isTrue);
    });

    testWidgets(
        'a held wrong on item 1 of 2 keeps its own position in the header',
        (tester) async {
      // The topic page (Task 23) runs the session over many items. The index moves before
      // the held phase starts, so the header must count the held item, not the next one.
      final store = JpStoreMemory();
      final words = catalog.ofKind(ItemKind.word).take(2).toList();
      tester.view.physicalSize = const Size(1000, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: PracticeSessionWidget(
          items: words,
          store: store,
          catalog: catalog,
          clock: FixedClock(at(today)),
          probeBuilder: fakeProbe,
        ),
      ));
      await settle(tester);
      expect(shows('Practice · 1 of 2'), isTrue);
      expect(shows('probe ${words[0].id}'), isTrue);

      await tapText(tester, 'answer wrong');
      expect(shows('Practice · 1 of 2'), isTrue,
          reason: 'the held probe is still item 1');
      expect(shows('Practice · 2 of 2'), isFalse);
      expect(shows('probe ${words[0].id}'), isTrue);
      expect(find.text('Next'), findsOneWidget);

      await tapText(tester, 'Next');
      expect(shows('Practice · 2 of 2'), isTrue);
      expect(shows('probe ${words[1].id}'), isTrue);

      await tapText(tester, 'answer wrong');
      expect(shows('Practice · 2 of 2'), isTrue,
          reason: 'a held wrong on the last item never reads 3 of 2');
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('a New item stays New after an early clear', (tester) async {
      final store = JpStoreMemory();
      final word = firstOf(ItemKind.word);
      await pumpItem(tester, store, word);
      await tapText(tester, kPracticeNow);
      await tapText(tester, 'answer clear');
      expect(
          (await store.attempts(itemId: word.id)).single.source, Source.early);
      expect(await store.srs(word.id), isNull);
      await tapText(tester, 'Done');
      expect(shows('0 of 4 clears'), isTrue);
      expect(shows(kNotQueuedLine), isTrue);
    });

    testWidgets('on a due item, the answer is a review and its clear counts',
        (tester) async {
      final store = JpStoreMemory();
      final word = firstOf(ItemKind.word);
      await store.appendSeed(word.id, today, atUtc: at(today - 1).toUtc());
      await pumpItem(tester, store, word);
      await tapText(tester, kPracticeNow);
      await tapText(tester, 'answer clear');
      expect(shows('Clear'), isTrue);

      final written = (await store.attempts(itemId: word.id)).single;
      expect(written.source, Source.review);
      expect(written.wasDue, isTrue);
      await tapText(tester, 'Done');
      expect(shows('1 of 4 clears'), isTrue);
    });

    testWidgets('a hinted answer is right with no credit (PIN-3)',
        (tester) async {
      final store = JpStoreMemory();
      final word = firstOf(ItemKind.word);
      await store.appendSeed(word.id, today, atUtc: at(today - 1).toUtc());
      await pumpItem(tester, store, word);
      await tapText(tester, kPracticeNow);
      await tapText(tester, 'answer hinted');
      expect(shows('Right with a hint'), isTrue);
      expect(shows('No credit this time.'), isTrue);
      await tapText(tester, 'Done');
      expect(shows('0 of 4 clears'), isTrue);
    });
  });

  testWidgets('a row of the study record page opens the item page',
      (tester) async {
    final store = JpStoreMemory();
    final word = firstOf(ItemKind.word);
    await record(store, answer(word, today - 3, Grade.clear));
    tester.view.physicalSize = const Size(1200, 20000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: MasteryDebugWidget(
          store: store, catalog: catalog, clock: FixedClock(at(today))),
    ));
    await settle(tester);
    await tester.tap(find.byKey(ValueKey('record-item-${word.id}')));
    await settle(tester);
    await settle(tester);
    expect(find.byType(ItemDetailWidget), findsOneWidget);
    expect(shows('1 of 4 clears'), isTrue);
  });
}
