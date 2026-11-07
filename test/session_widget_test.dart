// Widget tests for the Review session (plan 2026-11-02, Task 18, End state 10).
//
// The session walks a hand-built `DayPlan` over the shipped catalog on a memory store with an
// injected clock. A fake probe builder stands in for the probe widgets (tested on their own in
// probe_widgets_test.dart): it shows four buttons that hand on a clear, a hinted, a wrong or an
// unscored draft. The cases: the section order and the "Due · 1 of 2" line, the attempt written
// at answer time with the entry's `wasDue` and source (ASK-6), the no-credit card (PIN-3), the
// Clear and Mastered cards (the fourth clear, and a Shaky item's regain), a wrong with no card
// (straight on when the answer was on screen, else the probe held under one Next, with the
// real probes) and its re-ask as the last entry of its section, not due (PIN-11, operator
// ruling 2026-11-05), the skip that moves an entry to the end of its
// section once, the soft stop at the target with Stop and Keep going, the end at the ceiling
// with the rest left due (PIN-5), One more (10) inside the ceiling, the catch-up only when the
// plan offers it and only on a tap (PIN-12), the stretch only under its conditions (PIN-6),
// the 14 dots over the days whose session completed, the end card listing two mastered items
// that share a title (PIN-16), a resume (`position`) that carries the estimate (skips
// included, a skipped re-ask among them), the day's counts, the mastered-today list and a
// taken offer on instead of restarting them, and a double tap on a card's button that runs
// its action once.
//
// Review the lesson (plan 2026-11-06, Task 2, End state 1, PIN-5): under the app's router the
// link on an unanswered card pushes the item kind's lesson target, Back returns to the same
// card unanswered and marked "Lesson reviewed", and a clear after it is written hinted at hint
// level 1; wrong, hinted and unscored answers are untouched; the review covers that card only;
// the link is gone once the card is answered; opening a lesson writes no attempt; an opener
// that fails leaves the card unreviewed, so a clear after it stays clear, and a failure after
// an earlier open of the same card keeps that mark; every item kind's link, and both a taught
// and an untaught particle's, pushes its own target and query through the router and Back
// returns to its card.
//
// Spoken answers through Azure (plan 2026-11-06, Task 5, End state 4, PIN-2, PIN-10, D10):
// with the real spoken probe and a fake PronunciationService, a word's spoken card is scored
// against its hiragana; a correct score writes a spoken clear, a close writes hinted with
// `spokenClose` and leaves the hinted row as it was, an unverified score writes unscored with
// no self-mark and moves the entry back, a wrong holds the card under one Next, a close after
// Review the lesson loses its mark, and Practice now scores through the same service. The
// grade cases build the spoken card directly, so they do not pin which probe the session
// picks next (the "next card" group tests the pick). Two plumbing cases go through each
// widget's own standardProbeBuilder: an injected service reaches the probe in the session
// and in Practice now, and both leave it to its owner.
//
// Next card (plan 2026-11-06, Task 6, End state 11, D19): `nextProbe` asks the first scored
// probe whose mode has no counting clear, so a needed mode shows before the 4th clear, and
// a word's scored probes take turns once every mode has one. Through the real builder, a particle
// whose cloze is cleared shows its choose card, and one with the cloze and the choose cleared
// shows its say card, scored through the service and written with the entry's source, never
// Say-it.
//
// Sentence rotation (plan 2026-11-06, Task 9, End state 11, D11, PIN-4, ASK-5): a particle
// carries one cloze per sentence; within the needed mode a sentence with no clear comes
// first, and a sentence cleared on 2 different days moves aside. A rotate marker takes the
// scored probes in turn by attempts so far: Practice now on an item that is not due shows two
// different cards on two early answers, and a re-ask after a wrong rotates (here to a
// different card; the rotation is by attempts so far, not away from the card just missed),
// while the held card keeps the probe it was answered on. A due entry, in the session or in
// Practice now, keeps the first needed mode.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:habit_craft/components/pages/quiet_room_mastery/attempt.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/item_detail_widget.dart'
    show PracticeSessionWidget;
import 'package:habit_craft/components/pages/quiet_room_grammar/jp_study_kit.dart'
    show JpGrammarData;
import 'package:habit_craft/components/pages/quiet_room_mastery/drill_recorder.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/item_catalog.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_memory.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/lesson_page_widget.dart'
    show lessonTargetOf;
import 'package:habit_craft/components/pages/quiet_room_mastery/local_day.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/mastery_rule.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/plan_builder.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/probe_widgets.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/scheduler.dart'
    show SrsState;
import 'package:habit_craft/components/pages/quiet_room_mastery/session_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_practice/pronunciation_service.dart'
    show Judgement;

import 'jp_screen_harness.dart' show holdHttpRequests;
import 'support/fake_pronunciation.dart';

Map<String, dynamic> _read(String path) =>
    json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;

final catalog = ItemCatalog.fromDocs(_read('assets/lessons/jp_grammar.json'),
    _read('assets/lessons/jp_lessons.json'));
final words = catalog.ofKind(ItemKind.word);

const int today = 300;

/// 10:00 local on [day].
DateTime at(int day) => dayStart(day).add(const Duration(hours: 6));

QueueEntry entryOf(ItemDef item, PlanSection section,
        {int cost = 10, bool wasDue = true}) =>
    QueueEntry(
        itemId: item.id,
        kind: item.kind,
        section: section,
        costSeconds: cost,
        wasDue: wasDue,
        lesson: item.lesson);

DayPlan planOf(
  List<QueueEntry> entries, {
  int target = kTargetSeconds,
  int ceiling = kCeilingSeconds,
  bool stretchOffer = false,
  List<QueueEntry> stretchEntries = const [],
  bool catchUpOffer = false,
  List<QueueEntry> catchUpEntries = const [],
}) =>
    DayPlan(
      day: today,
      builtAtUtc: at(today).toUtc(),
      entries: entries,
      daysMissed: 0,
      backlogSeconds: 0,
      targetSeconds: target,
      ceilingSeconds: ceiling,
      gateSeconds: (target * kGateFactor).round(),
      repairSlotSeconds: kRepairSlotSeconds,
      newSkip: NewSkip.none,
      keepSharpRan: false,
      dueLeft: 0,
      stretchOffer: stretchOffer,
      stretchEntries: stretchEntries,
      catchUpOffer: catchUpOffer,
      catchUpEntries: catchUpEntries,
    );

/// The fake probe: the item id and four answers.
Widget fakeProbe(BuildContext context, SessionProbeRequest r) {
  final probe = r.item.scoredProbes.first;
  DrillAnswer draft(Grade g) => DrillAnswer(
      itemId: r.item.id,
      probeId: probe.id,
      template: probe.template,
      production: probe.production,
      selfGraded: probe.selfGraded,
      grade: g,
      hintLevel: g == Grade.hinted ? 1 : 0);
  return Column(children: [
    Text('probe ${r.item.id}'),
    for (final g in [Grade.clear, Grade.hinted, Grade.wrong, Grade.unscored])
      TextButton(
          onPressed: () => r.onAnswer(draft(g)),
          child: Text('answer ${g.name}')),
  ]);
}

class Harness {
  Harness(this.tester, this.store);

  final WidgetTester tester;
  final JpStoreMemory store;

  Future<void> settle() async {
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
  }

  Future<void> tap(String label) async {
    final f = find.text(label);
    expect(f, findsOneWidget, reason: 'a "$label" control');
    await tester.ensureVisible(f);
    await tester.tap(f);
    await settle();
  }

  /// Answers the entry on screen with [g] and taps Next on the verdict card.
  Future<void> answer(Grade g) async {
    await tap('answer ${g.name}');
    await tap('Next');
  }

  bool shows(String text) => find.text(text).evaluate().isNotEmpty;

  /// The item id of the entry on screen, or null.
  String? get onScreen {
    final f = find.textContaining('probe ');
    if (f.evaluate().isEmpty) return null;
    return (f.evaluate().first.widget as Text).data!.substring(6);
  }
}

/// An answer on [item] on [day] with [grade], under [sessionId].
Attempt attemptOf(ItemDef item, int day, Grade grade,
    {String sessionId = '${kReviewSessionPrefix}earlier'}) {
  final p = item.scoredProbes.first;
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
    hintLevel: grade == Grade.hinted ? 1 : 0,
    wasDue: true,
    source: Source.review,
    sessionId: sessionId,
  );
}

/// Pumps the session over [plan]; [position] above 0 is a resume of the stored day.
Future<Harness> pumpSession(WidgetTester tester, DayPlan plan,
    {JpStoreMemory? store, int position = 0, LessonOpener? openLesson}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final s = store ?? JpStoreMemory();
  await s
      .putDay(DayRecord(day: today, plan: plan.encode(), position: position));
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SessionWidget(
        plan: plan,
        store: s,
        clock: FixedClock(at(today)),
        catalog: catalog,
        position: position,
        probeBuilder: fakeProbe,
        openLesson: openLesson,
      ),
    ),
  ));
  final h = Harness(tester, s);
  await h.settle();
  return h;
}

void main() {
  // The plumbing cases run under `runAsync`, where a Google Fonts fetch would otherwise land
  // its failure in whichever test is running then.
  setUpAll(holdHttpRequests);

  testWidgets(
      'walks the sections in plan order with the section line, and writes each answer '
      'with the entry wasDue and source (ASK-6)', (tester) async {
    final plan = planOf([
      entryOf(words[0], PlanSection.repair),
      entryOf(words[1], PlanSection.due),
      entryOf(words[2], PlanSection.due),
      entryOf(words[3], PlanSection.keepSharp, wasDue: false),
      entryOf(words[4], PlanSection.newItems),
    ]);
    final h = await pumpSession(tester, plan);
    final seen = <String>[];
    for (final label in [
      'Repair · 1 of 1',
      'Due · 1 of 2',
      'Due · 2 of 2',
      'Keep-sharp · 1 of 1',
      'New · 1 of 1',
    ]) {
      expect(h.shows(label), isTrue, reason: label);
      seen.add(h.onScreen!);
      await h.answer(Grade.clear);
    }
    expect(seen, [for (final e in plan.entries) e.itemId]);
    expect(h.shows('Done for today'), isTrue);

    final attempts = await h.store.attempts();
    expect([for (final a in attempts) a.itemId], seen);
    expect(
        [for (final a in attempts) a.wasDue], [true, true, true, false, true]);
    expect([
      for (final a in attempts) a.source
    ], [
      Source.review,
      Source.review,
      Source.review,
      Source.keepSharp,
      Source.review,
    ]);
    // The New entry's introduction clear is the first of the four (ASK-6).
    expect((await h.store.mastery(words[4].id))!.clearCount, 1);
    final record = await h.store.day(today);
    expect(record!.completed, isTrue);
    expect(record.position, plan.entries.length);
  });

  testWidgets('each answer is in the store before its verdict card shows',
      (tester) async {
    final h = await pumpSession(
        tester,
        planOf([
          entryOf(words[0], PlanSection.due),
          entryOf(words[1], PlanSection.due),
        ]));
    await h.tap('answer clear');
    expect(h.shows('Clear'), isTrue);
    expect(await h.store.attempts(), hasLength(1));
    expect((await h.store.day(today))!.position, 1,
        reason: 'the day record moves with the answer, so a relaunch resumes');
  });

  testWidgets(
      'a hinted answer shows Right with a hint and earns no credit (PIN-3); a clear '
      'shows its new interval', (tester) async {
    final h = await pumpSession(
        tester,
        planOf([
          entryOf(words[0], PlanSection.due),
          entryOf(words[1], PlanSection.due),
        ]));
    await h.tap('answer hinted');
    expect(h.shows('Right with a hint'), isTrue);
    expect(h.shows('No credit this time.'), isTrue);
    expect(h.shows('Clear'), isFalse);
    final hinted = await h.store.mastery(words[0].id);
    expect(hinted!.clearCount, 0);
    expect((await h.store.attempts()).single.grade, Grade.hinted);
    await h.tap('Next');

    await h.tap('answer clear');
    expect(h.shows('Clear'), isTrue);
    final srs = await h.store.srs(words[1].id);
    expect(
        h.shows(
            'Next review in ${srs!.dueDay - today == 1 ? '1 day' : '${srs.dueDay - today} days'}.'),
        isTrue);
    expect((await h.store.mastery(words[1].id))!.clearCount, 1);
  });

  testWidgets(
      'the fourth clear that completes the rule shows Mastered and the end card lists it',
      (tester) async {
    // Since its choose and say cards (plan 2026-11-06, Task 6) a particle needs two templates
    // and a production clear, and a clear in each of its three modes (Task 7, PIN-7), so the
    // seeded clears hold a choose clear (see it) and a say card clear (say it) beside the
    // cloze (type it) that completes the rule. Since Task 9 it needs two sentences, so the
    // first seeded clear is on its second sentence (`cloze.1`).
    final particle = catalog.ofKind(ItemKind.particle).first;
    final probe = particle.scoredProbes.first;
    final second =
        particle.probes.firstWhere((p) => p.id == particleClozeId(1));
    final choose = particle.probes.firstWhere((p) => p.id == kParticleChooseId);
    final say = particle.probes.firstWhere((p) => p.id == sayCardId('cloze'));
    ClearRef c(int day, [ProbeDef? on]) => ClearRef(
        day: day,
        template: (on ?? probe).template,
        production: (on ?? probe).production,
        probeId: (on ?? probe).id);
    final store = JpStoreMemory();
    await store.putMastery(MasteryState(
      itemId: particle.id,
      status: MasteryStatus.learning,
      clears: [
        c(today - 70, second),
        c(today - 50, choose),
        c(today - 30, say)
      ],
      lastScoredDay: today - 30,
    ));
    final h = await pumpSession(
        tester, planOf([entryOf(particle, PlanSection.due)]),
        store: store);
    await h.tap('answer clear');
    expect(h.shows('Mastered'), isTrue);
    expect(
        h.shows('Four clears over time. It still comes back to keep it sharp.'),
        isTrue);
    expect((await store.mastery(particle.id))!.status, MasteryStatus.mastered);
    await h.tap('Next');
    expect(h.shows('Mastered today'), isTrue);
    expect(h.shows(particle.title), isTrue);
  });

  testWidgets(
      'the clear that regains a Shaky item shows Mastered without the four-clears line',
      (tester) async {
    final particle = catalog.ofKind(ItemKind.particle).first;
    final probe = particle.scoredProbes.first;
    final store = JpStoreMemory();
    // One regain clear eight days ago: this clear is the second, past the 7-day gap.
    await store.putMastery(MasteryState(
      itemId: particle.id,
      status: MasteryStatus.shaky,
      clears: [
        ClearRef(
            day: today - 8,
            template: probe.template,
            production: probe.production,
            probeId: probe.id)
      ],
      lastScoredDay: today - 8,
      shakyOn: today - 20,
    ));
    final h = await pumpSession(
        tester, planOf([entryOf(particle, PlanSection.due)]),
        store: store);
    await h.tap('answer clear');
    expect(h.shows('Mastered'), isTrue);
    expect(h.shows('Back to mastered. It still comes back to keep it sharp.'),
        isTrue);
    expect(
        h.shows('Four clears over time. It still comes back to keep it sharp.'),
        isFalse);
    expect((await store.mastery(particle.id))!.status, MasteryStatus.mastered);
    await h.tap('Next');
    expect(h.shows(particle.title), isTrue);
  });

  testWidgets(
      'the end card lists two items mastered today that share a title, one line each '
      '(PIN-16)', (tester) async {
    final byTitle = <String, List<ItemDef>>{};
    for (final w in words) {
      byTitle.putIfAbsent(w.title, () => []).add(w);
    }
    final twins = byTitle.values.firstWhere((v) => v.length > 1);
    final store = JpStoreMemory();
    for (final twin in twins.take(2)) {
      await store.putMastery(MasteryState(
          itemId: twin.id, status: MasteryStatus.mastered, masteredOn: today));
    }
    final h = await pumpSession(
        tester, planOf([entryOf(words[0], PlanSection.due)]),
        store: store);
    await h.answer(Grade.clear);
    expect(h.shows('Mastered today'), isTrue);
    expect(find.text(twins.first.title), findsNWidgets(2));
  });

  testWidgets(
      'a wrong shows no card: the probe stays under one Next, and the item is re-asked '
      'as the last entry of its section, not due (operator ruling 2026-11-05, PIN-11)',
      (tester) async {
    final rest = [
      for (final w in words.skip(1).take(4))
        entryOf(w, PlanSection.due, cost: 100)
    ];
    final fresh = entryOf(words[5], PlanSection.newItems, cost: 100);
    final plan = planOf(
        [entryOf(words[0], PlanSection.due, cost: 100), ...rest, fresh],
        target: 10000, ceiling: 20000);
    final h = await pumpSession(tester, plan);
    await h.tap('answer wrong');
    // The fake probe's draft does not say the answer was on screen, so the probe stays.
    expect(h.onScreen, words[0].id);
    expect(h.shows('Due · 1 of 5'), isTrue);
    for (final retired in [
      'Not this time',
      'Not quite',
      'It comes back in about 10 minutes, and again tomorrow.',
      'It comes back tomorrow.',
    ]) {
      expect(h.shows(retired), isFalse, reason: retired);
    }
    await h.tap('Next');
    for (var i = 0; i < rest.length; i++) {
      expect(h.onScreen, rest[i].itemId);
      await h.answer(Grade.clear);
    }
    // The re-ask is the last entry of Due, before New.
    expect(h.onScreen, words[0].id);
    expect(h.shows('Due · 6 of 6'), isTrue);
    final stored = DayPlan.decode((await h.store.day(today))!.plan)
        .section(PlanSection.due);
    expect(stored.last.itemId, words[0].id);
    expect(stored.last.reask, isTrue);
    await h.answer(Grade.clear);
    expect(h.onScreen, fresh.itemId);
    final onItem = await h.store.attempts(itemId: words[0].id);
    expect([for (final a in onItem) a.grade], [Grade.wrong, Grade.clear]);
    expect([for (final a in onItem) a.wasDue], [true, false]);
    // The wrong scheduled it Again for another day, and a not-due clear starts no run of
    // counting clears.
    expect((await h.store.srs(words[0].id))!.dueDay, greaterThan(today));
    expect((await h.store.mastery(words[0].id))!.clearCount, 0);
  });

  group('the real probes after a wrong (operator ruling 2026-11-05)', () {
    final grammar = _read('assets/lessons/jp_grammar.json');
    final particle = catalog.ofKind(ItemKind.particle).first;

    Future<Harness> pumpReal(WidgetTester tester, DayPlan plan) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final s = JpStoreMemory();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SessionWidget(
            plan: plan,
            store: s,
            clock: FixedClock(at(today)),
            catalog: catalog,
            probeBuilder: standardProbeBuilder(
                grammar: grammar, pronunciation: FakePronunciation()),
          ),
        ),
      ));
      final h = Harness(tester, s);
      await h.settle();
      return h;
    }

    testWidgets('Not yet on a word card moves straight on, with no card',
        (tester) async {
      final plan = planOf([
        entryOf(words[0], PlanSection.due),
        entryOf(words[1], PlanSection.due),
      ]);
      final h = await pumpReal(tester, plan);
      expect(h.shows(words[0].probes.first.text), isTrue,
          reason: 'the card shows the meaning');
      await h.tap('Show me');
      await h.tap('Not yet');
      // The next word's card, with no result card and no Next between.
      expect(h.shows('Due · 2 of 3'), isTrue);
      expect(h.shows(words[1].probes.first.text), isTrue);
      expect(h.shows('Next'), isFalse);
      expect(h.shows('Not quite'), isFalse);
      final onItem = await h.store.attempts(itemId: words[0].id);
      expect([for (final a in onItem) a.grade], [Grade.wrong]);
      // The re-ask is the last entry of Due.
      final stored = DayPlan.decode((await h.store.day(today))!.plan);
      expect(stored.section(PlanSection.due).last.itemId, words[0].id);
      expect(stored.section(PlanSection.due).last.reask, isTrue);
    });

    testWidgets(
        'a particle card offers its English and its meaning as the grammar hint',
        (tester) async {
      final plan = planOf([entryOf(particle, PlanSection.due)]);
      final h = await pumpReal(tester, plan);
      final row = (grammar['particles'] as List)
          .cast<Map>()
          .firstWhere((p) => p['id'] == particle.id);
      expect(h.shows(row['example_en'] as String), isFalse);
      await h.tap('Show English');
      expect(h.shows(row['example_en'] as String), isTrue);
      await h.tap('Show grammar hint');
      expect(h.shows('The missing part means: ${row['meaning']}'), isTrue);
    });

    testWidgets('Show answer shows the full answer and one Next',
        (tester) async {
      final plan = planOf([
        entryOf(particle, PlanSection.due),
        entryOf(words[1], PlanSection.due),
      ]);
      final h = await pumpReal(tester, plan);
      final probe = particle.scoredProbes.first;
      await h.tap('Show answer');
      final (before, filled, after) = fillBlank(probe.text, probe.answer);
      expect(h.shows('$before$filled$after'), isTrue,
          reason: 'the prompt with the missing part filled in');
      expect(h.shows('Next'), isTrue);
      expect(h.shows('Not this time'), isFalse);
      // Still the particle, under its line from before the re-ask, until Next.
      expect(h.shows('Due · 1 of 2'), isTrue);
      await h.tap('Next');
      expect(h.shows('Due · 2 of 3'), isTrue);
      expect(h.shows(words[1].probes.first.text), isTrue);
    });

    testWidgets('a wrong typed answer shows both answers under one Next',
        (tester) async {
      final plan = planOf([entryOf(particle, PlanSection.due)]);
      final h = await pumpReal(tester, plan);
      final probe = particle.scoredProbes.first;
      await tester.enterText(find.byType(TextField), 'を');
      await h.tap('Check');
      final (before, filled, after) = fillBlank(probe.text, probe.answer);
      expect(h.shows('Your answer: を'), isTrue);
      expect(h.shows('$before$filled$after'), isTrue);
      expect(h.shows('Next'), isTrue);
    });
  });

  group('spoken answers through Azure (plan 2026-11-06, Task 5, PIN-2)', () {
    final word = words[0];
    final spoken = word.probes.firstWhere((p) => p.template == 'spoken');

    /// The real spoken card, whatever probe the session would pick (the pick is Task 6's).
    SessionProbeBuilder spokenProbe(FakePronunciation pron) =>
        (context, r) => WordRecallProbe(
            item: r.item,
            probe: spoken,
            state: r.state,
            pronunciation: pron,
            onAnswer: r.onAnswer);

    /// One counting clear on the word's card, in the log and in the mastery state, so a
    /// widget's own standardProbeBuilder lands on `spoken` under the mode-aware pick
    /// (`nextProbe`, D19: the first scored probe whose mode has no counting clear, which reads
    /// MasteryState.clears). The pick reads the probes in order, so the say card after them
    /// (Task 6) never comes first.
    Future<JpStoreMemory> storeWithCardClear() async {
      final s = JpStoreMemory();
      final seed = attemptOf(word, today - 1, Grade.clear);
      expect(seed.template, 'card', reason: 'the seed is on the card');
      expect(word.scoredProbes.map((p) => p.template).take(2).toList(),
          ['card', 'spoken'],
          reason: 'both pick rules read the first two scored probes');
      await s.appendAttempt(seed,
          mastery: masteryAfter(MasteryState.initial(word.id), seed, word));
      final stored = await s.mastery(word.id);
      expect(stored?.clears.map((c) => c.template).toList(), ['card'],
          reason: 'the store holds the seed as a counting card clear');
      return s;
    }

    void bigView(WidgetTester tester) {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    Future<(Harness, FakePronunciation)> pumpSpoken(WidgetTester tester,
        {LessonOpener? openLesson}) async {
      bigView(tester);
      final s = JpStoreMemory();
      final pron = FakePronunciation();
      final plan = planOf([
        entryOf(word, PlanSection.due),
        entryOf(words[1], PlanSection.due),
      ]);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SessionWidget(
            plan: plan,
            store: s,
            clock: FixedClock(at(today)),
            catalog: catalog,
            probeBuilder: spokenProbe(pron),
            openLesson: openLesson,
          ),
        ),
      ));
      final h = Harness(tester, s);
      await h.settle();
      return (h, pron);
    }

    /// Loads the shipped grammar in the real zone before a widget builds its own
    /// standardProbeBuilder. The load is cached for the whole run: a copy made under the
    /// test's fake clock would belong to that test's zone, and the next test that awaits it
    /// would never hear it complete (see jp_screen_harness.dart `pumpStudyScreen`).
    Future<void> loadGrammarInRealZone(WidgetTester tester) =>
        tester.runAsync(JpGrammarData.load);

    /// Waits for the spoken card of a widget that loads the shipped grammar for its own
    /// builder.
    Future<void> waitForSayIt(WidgetTester tester, Harness h) async {
      await tester.runAsync(() async {
        for (var i = 0; i < 20 && !h.shows('Say it'); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
      });
      await h.settle();
      expect(h.shows('Say it'), isTrue, reason: 'the spoken card');
    }

    /// Says the word and lets Azure's verdict [j] land.
    Future<void> say(Harness h, FakePronunciation pron, Judgement j) async {
      await h.tap('Say it');
      expect(pron.referenceTexts.single, spoken.answer,
          reason: "scored against the word's hiragana");
      pron.answer(j);
      await h.settle();
    }

    /// The attempt the spoken answer wrote. A store seeded by [storeWithCardClear] holds a
    /// `card` clear before it, so the template check is what tells a missing write apart.
    Future<Attempt> written(Harness h) async {
      final a = (await h.store.attempts(itemId: word.id)).last;
      expect(a.template, 'spoken',
          reason: 'the spoken answer wrote an attempt');
      return a;
    }

    testWidgets('a correct score writes a spoken clear', (tester) async {
      final (h, pron) = await pumpSpoken(tester);
      await say(h, pron, Judgement.correct);
      final a = await written(h);
      expect(a.template, 'spoken');
      expect(a.probeId, 'spoken');
      expect(a.grade, Grade.clear);
      expect(a.selfGraded, isFalse);
      expect(a.spokenClose, isFalse);
      expect(a.source, Source.review);
      expect(h.shows('Clear'), isTrue);
    });

    testWidgets(
        'a close score writes hinted with the close mark, and leaves the hinted row '
        'as it was (PIN-10)', (tester) async {
      final (h, pron) = await pumpSpoken(tester);
      final before = await h.store.mastery(word.id);
      await say(h, pron, Judgement.close);
      final a = await written(h);
      expect(a.grade, Grade.hinted);
      expect(a.spokenClose, isTrue);
      expect(a.rating, kRatingHard);
      expect(h.shows('Close'), isTrue);
      expect(h.shows('No credit this time.'), isTrue);
      final after = (await h.store.mastery(word.id))!;
      expect(after.hintStreak, before?.hintStreak ?? 0,
          reason: 'a spoken close never counts toward the two-hinted reset');
      expect(after.clearCount, 0, reason: 'and earns no credit');
    });

    testWidgets(
        'an unverified score (no connection) writes unscored, with no self-mark, and '
        'the entry comes back later (D10)', (tester) async {
      final (h, pron) = await pumpSpoken(tester);
      await say(h, pron, Judgement.unverified);
      expect(h.shows('Got it'), isFalse);
      expect(h.shows('Missed it'), isFalse);
      final a = await written(h);
      expect(a.grade, Grade.unscored);
      expect(a.rating, isNull);
      expect(a.spokenClose, isFalse);
      expect(h.shows('Not counted'), isTrue);
      final stored = DayPlan.decode((await h.store.day(today))!.plan);
      expect(stored.section(PlanSection.due).last.itemId, word.id,
          reason: 'unscored moves the entry to the end of its section');
    });

    testWidgets('a wrong score holds the card with the answer under one Next',
        (tester) async {
      final (h, pron) = await pumpSpoken(tester);
      await say(h, pron, Judgement.wrong);
      final a = await written(h);
      expect(a.grade, Grade.wrong);
      expect(h.shows(spoken.answer), isTrue);
      expect(h.shows('Next'), isTrue);
    });

    testWidgets(
        'a close after Review the lesson is an ordinary hinted answer, without the '
        'close mark (PIN-5, PIN-10)', (tester) async {
      final (h, pron) =
          await pumpSpoken(tester, openLesson: (context, item) async {});
      await h.tap(kReviewTheLesson);
      expect(h.shows(kLessonReviewed), isTrue);
      await say(h, pron, Judgement.close);
      final a = await written(h);
      expect(a.grade, Grade.hinted);
      expect(a.hintLevel, 1);
      expect(a.spokenClose, isFalse);
    });

    testWidgets('Practice now scores a spoken answer through the same service',
        (tester) async {
      bigView(tester);
      final s = JpStoreMemory();
      final pron = FakePronunciation();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PracticeSessionWidget(
            items: [word],
            store: s,
            catalog: catalog,
            clock: FixedClock(at(today)),
            probeBuilder: spokenProbe(pron),
          ),
        ),
      ));
      final h = Harness(tester, s);
      await h.settle();
      await say(h, pron, Judgement.close);
      final a = await written(h);
      expect(a.template, 'spoken');
      expect(a.grade, Grade.hinted);
      expect(a.spokenClose, isTrue);
      expect(h.shows('Close'), isTrue);
    });

    testWidgets(
        'an injected service reaches the probe, and the session leaves it to its owner',
        (tester) async {
      bigView(tester);
      await loadGrammarInRealZone(tester);
      final s = await storeWithCardClear();
      final pron = FakePronunciation();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SessionWidget(
            plan: planOf([entryOf(word, PlanSection.due)]),
            store: s,
            clock: FixedClock(at(today)),
            catalog: catalog,
            pronunciation: pron,
          ),
        ),
      ));
      final h = Harness(tester, s);
      await waitForSayIt(tester, h);
      await say(h, pron, Judgement.correct);
      expect((await written(h)).grade, Grade.clear);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(pron.disposes, 0, reason: 'the caller owns an injected service');
    });

    testWidgets(
        'an injected service reaches the probe in Practice now, and practice leaves it '
        'to its owner', (tester) async {
      bigView(tester);
      await loadGrammarInRealZone(tester);
      final s = await storeWithCardClear();
      final pron = FakePronunciation();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PracticeSessionWidget(
            items: [word],
            store: s,
            catalog: catalog,
            clock: FixedClock(at(today)),
            pronunciation: pron,
          ),
        ),
      ));
      final h = Harness(tester, s);
      await waitForSayIt(tester, h);
      await say(h, pron, Judgement.correct);
      expect((await written(h)).grade, Grade.clear);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(pron.disposes, 0, reason: 'the caller owns an injected service');
    });
  });

  group('a skip (unscored)', () {
    testWidgets(
        'shows Not counted, asks the item again at the end of its section, and counts '
        'as answered', (tester) async {
      final plan = planOf([
        entryOf(words[0], PlanSection.due),
        entryOf(words[1], PlanSection.due),
        entryOf(words[2], PlanSection.due),
        entryOf(words[3], PlanSection.keepSharp, wasDue: false),
      ]);
      final h = await pumpSession(tester, plan);
      await h.tap('answer unscored');
      expect(h.shows('Not counted'), isTrue);
      expect(h.shows('It comes back later in this part.'), isTrue);
      await h.tap('Next');
      expect(h.onScreen, words[1].id);
      expect(h.shows('Due · 1 of 3'), isTrue);
      await h.answer(Grade.clear);
      await h.answer(Grade.clear);
      expect(h.onScreen, words[0].id, reason: 'the skipped item, last in Due');
      expect(h.shows('Due · 3 of 3'), isTrue);
      await h.answer(Grade.clear);
      expect(h.onScreen, words[3].id);
      await h.answer(Grade.clear);
      expect(h.shows('Done for today'), isTrue);
      // The skip is an answer on the end card; it is none of the three listed counts.
      expect(h.shows('5 answered · 4 clear · 0 with help · 0 missed'), isTrue);
      final onItem = await h.store.attempts(itemId: words[0].id);
      expect([for (final a in onItem) a.grade], [Grade.unscored, Grade.clear]);
      expect((await h.store.mastery(words[0].id))!.clearCount, 1);
    });

    testWidgets('a second skip on the same entry moves on', (tester) async {
      final h = await pumpSession(
          tester,
          planOf([
            entryOf(words[0], PlanSection.due),
            entryOf(words[1], PlanSection.due),
          ]));
      await h.answer(Grade.unscored);
      expect(h.onScreen, words[1].id);
      await h.answer(Grade.unscored);
      // Both moved once: the order is as it was.
      expect(h.onScreen, words[0].id);
      await h.answer(Grade.unscored);
      expect(h.onScreen, words[1].id, reason: 'a requeued entry stays put');
      await h.answer(Grade.unscored);
      expect(h.shows('Done for today'), isTrue);
      expect(h.shows('4 answered · 0 clear · 0 with help · 0 missed'), isTrue);
      final record = await h.store.day(today);
      expect(record!.position, 2);
      expect(
          DayPlan.decode(record.plan).entries.every((e) => e.requeued), isTrue);
    });
  });

  testWidgets(
      'the soft stop shows when the estimate reaches the target; Keep going runs on and '
      'the ceiling ends the session with the rest left due (PIN-5)',
      (tester) async {
    final entries = [
      for (final w in words.take(15)) entryOf(w, PlanSection.due, cost: 100)
    ];
    final h = await pumpSession(tester, planOf(entries));
    for (var i = 0; i < 9; i++) {
      expect(h.shows('About 15 minutes'), isFalse, reason: 'answer $i');
      await h.answer(Grade.clear);
    }
    expect(h.shows('About 15 minutes'), isTrue);
    expect(h.shows('Stop'), isTrue);
    await h.tap('Keep going');
    for (var i = 0; i < 3; i++) {
      expect(h.onScreen, entries[9 + i].itemId);
      await h.answer(Grade.clear);
    }
    // 1200 seconds spent: the next entry would pass the ceiling.
    expect(h.onScreen, isNull);
    expect(h.shows("That is today's 20 minutes"), isTrue);
    expect(h.shows('The rest is due tomorrow.'), isTrue);
    expect(h.shows('One more (10)'), isFalse,
        reason: 'One more stays inside the ceiling');
    expect(h.shows('Catch up: 10 more'), isFalse,
        reason: 'the plan does not offer the catch-up');
    expect(await h.store.attempts(), hasLength(12));
    final record = await h.store.day(today);
    expect(record!.completed, isTrue);
    expect(record.position, 12);
    // The three left were never answered, so they stay as due as they were.
    for (final e in entries.skip(12)) {
      expect(await h.store.attempts(itemId: e.itemId), isEmpty);
    }
  });

  testWidgets('Stop at the soft stop ends on the end card with One more (10)',
      (tester) async {
    final entries = [
      for (final w in words.take(25)) entryOf(w, PlanSection.due, cost: 60)
    ];
    final h = await pumpSession(tester, planOf(entries));
    for (var i = 0; i < 15; i++) {
      await h.answer(Grade.clear);
    }
    expect(h.shows('About 15 minutes'), isTrue);
    await h.tap('Stop');
    expect(h.shows('Done for today'), isTrue);
    expect(h.shows('15 answered · 15 clear · 0 with help · 0 missed'), isTrue);
    expect((await h.store.day(today))!.completed, isTrue);
    // One more runs at most 10 entries, and never past the ceiling (5 fit: 900 + 5 x 60).
    await h.tap('One more (10)');
    var more = 0;
    while (h.onScreen != null) {
      await h.answer(Grade.clear);
      more++;
    }
    expect(more, 5);
    expect(h.shows("That is today's 20 minutes"), isTrue);
    expect(h.shows('One more (10)'), isFalse);
  });

  testWidgets(
      'the catch-up shows past the ceiling only when the plan offers it, and adds '
      'nothing until tapped (PIN-12)', (tester) async {
    final entries = [
      for (final w in words.take(13)) entryOf(w, PlanSection.due, cost: 100)
    ];
    final block = [
      for (final w in words.skip(13).take(10)) entryOf(w, PlanSection.due)
    ];
    final h = await pumpSession(
        tester, planOf(entries, catchUpOffer: true, catchUpEntries: block));
    for (var i = 0; i < 9; i++) {
      await h.answer(Grade.clear);
    }
    await h.tap('Keep going');
    for (var i = 0; i < 3; i++) {
      await h.answer(Grade.clear);
    }
    expect(h.shows("That is today's 20 minutes"), isTrue);
    expect(h.shows('Catch up: 10 more'), isTrue);
    expect(await h.store.attempts(), hasLength(12));
    await h.tap('Catch up: 10 more');
    final asked = <String>[];
    while (h.onScreen != null) {
      asked.add(h.onScreen!);
      await h.answer(Grade.clear);
    }
    expect(asked, [for (final e in block) e.itemId]);
    expect(h.shows('Catch up: 10 more'), isFalse, reason: 'once only');
  });

  group('a double tap on a card runs its action once', () {
    testWidgets('on Catch up: 10 more, the whole block is still asked',
        (tester) async {
      final entries = [
        for (final w in words.take(13)) entryOf(w, PlanSection.due, cost: 100)
      ];
      final block = [
        for (final w in words.skip(13).take(10)) entryOf(w, PlanSection.due)
      ];
      final h = await pumpSession(
          tester, planOf(entries, catchUpOffer: true, catchUpEntries: block));
      for (var i = 0; i < 9; i++) {
        await h.answer(Grade.clear);
      }
      await h.tap('Keep going');
      for (var i = 0; i < 3; i++) {
        await h.answer(Grade.clear);
      }
      // Two taps inside the day write the first one starts: no frame between them.
      final f = find.text('Catch up: 10 more');
      await tester.ensureVisible(f);
      await tester.tap(f);
      await tester.tap(f);
      await h.settle();
      final asked = <String>[];
      while (h.onScreen != null) {
        asked.add(h.onScreen!);
        await h.answer(Grade.clear);
      }
      expect(asked, [for (final e in block) e.itemId]);
      expect(h.shows('Done for today'), isTrue);
    });

    testWidgets('on Next at the target, the soft stop still shows',
        (tester) async {
      final entries = [
        for (final w in words.take(10)) entryOf(w, PlanSection.due, cost: 100)
      ];
      final h = await pumpSession(tester, planOf(entries));
      for (var i = 0; i < 8; i++) {
        await h.answer(Grade.clear);
      }
      await h.tap('answer clear');
      final f = find.text('Next');
      await tester.ensureVisible(f);
      await tester.tap(f);
      await tester.tap(f);
      await h.settle();
      expect(h.onScreen, isNull, reason: 'the second tap asks no entry');
      expect(h.shows('About 15 minutes'), isTrue);
      await h.tap('Keep going');
      expect(h.onScreen, entries[9].itemId);
    });
  });

  group('the stretch offer (PIN-6)', () {
    final base = [for (final w in words.take(3)) entryOf(w, PlanSection.due)];
    final stretch = [
      for (final w in words.skip(3).take(kStretchNew))
        entryOf(w, PlanSection.newItems)
    ];

    testWidgets(
        'offered when the plan offers it and every entry is answered; tapped, it runs '
        'the four as New', (tester) async {
      final h = await pumpSession(
          tester, planOf(base, stretchOffer: true, stretchEntries: stretch));
      for (var i = 0; i < base.length; i++) {
        expect(h.shows('4 more new'), isFalse);
        await h.answer(Grade.clear);
      }
      expect(h.shows('4 more new'), isTrue);
      await h.tap('4 more new');
      final asked = <String>[];
      while (h.onScreen != null) {
        expect(h.shows('New · ${asked.length + 1} of $kStretchNew'), isTrue);
        asked.add(h.onScreen!);
        await h.answer(Grade.clear);
      }
      expect(asked, [for (final e in stretch) e.itemId]);
      expect(h.shows('4 more new'), isFalse, reason: 'once only');
      final news = await h.store.attempts();
      expect(news.skip(base.length).every((a) => a.wasDue), isTrue);
    });

    testWidgets('not offered when the plan does not offer it', (tester) async {
      final h = await pumpSession(tester, planOf(base));
      for (var i = 0; i < base.length; i++) {
        await h.answer(Grade.clear);
      }
      expect(h.shows('Done for today'), isTrue);
      expect(h.shows('4 more new'), isFalse);
    });

    testWidgets('not offered while a re-ask is still to come', (tester) async {
      final h = await pumpSession(
          tester, planOf(base, stretchOffer: true, stretchEntries: stretch));
      await h.answer(Grade.wrong);
      await h.answer(Grade.clear);
      await h.answer(Grade.clear);
      // The re-ask goes last; it is asked before any offer.
      expect(h.onScreen, base[0].itemId);
      expect(h.shows('4 more new'), isFalse);
      await h.answer(Grade.clear);
      expect(h.shows('4 more new'), isTrue);
    });

    testWidgets('not offered after Stop with entries left', (tester) async {
      final entries = [
        for (final w in words.take(12)) entryOf(w, PlanSection.due, cost: 100)
      ];
      final h = await pumpSession(
          tester, planOf(entries, stretchOffer: true, stretchEntries: stretch));
      for (var i = 0; i < 9; i++) {
        await h.answer(Grade.clear);
      }
      await h.tap('Stop');
      expect(h.shows('Done for today'), isTrue);
      expect(h.shows('4 more new'), isFalse);
    });

    testWidgets('not offered when the ceiling leaves no room for the four',
        (tester) async {
      final full = [
        for (final w in words.take(12)) entryOf(w, PlanSection.due, cost: 100)
      ];
      final h = await pumpSession(
          tester, planOf(full, stretchOffer: true, stretchEntries: stretch));
      for (var i = 0; i < 9; i++) {
        await h.answer(Grade.clear);
      }
      await h.tap('Keep going');
      for (var i = 0; i < 3; i++) {
        await h.answer(Grade.clear);
      }
      expect(h.shows('Done for today'), isTrue);
      expect(h.shows('4 more new'), isFalse);
    });
  });

  testWidgets(
      'the end card draws 14 dots over the days whose session completed',
      (tester) async {
    final store = JpStoreMemory();
    for (final d in [today - 1, today - 2, today - 5, today - 20]) {
      await store.putDay(DayRecord(day: d, plan: '{}', completed: true));
    }
    // A day planned and not finished is no dot.
    await store
        .putDay(const DayRecord(day: today - 3, plan: '{}', position: 4));
    final h = await pumpSession(
        tester, planOf([entryOf(words[0], PlanSection.due)]),
        store: store);
    await h.answer(Grade.clear);
    // Today, yesterday, two and five days ago; twenty days ago is outside the 14.
    expect(h.shows('4 of 14 days'), isTrue);
  });

  group('a resume carries the day on (PIN-5)', () {
    testWidgets(
        'at 900 seconds answered, the soft stop shows before the first resumed entry, and '
        'the ceiling still ends the session', (tester) async {
      final entries = [
        for (final w in words.take(15)) entryOf(w, PlanSection.due, cost: 100)
      ];
      final h = await pumpSession(tester, planOf(entries), position: 9);
      expect(h.onScreen, isNull, reason: 'no entry before the soft stop');
      expect(h.shows('About 15 minutes'), isTrue);
      await h.tap('Keep going');
      for (var i = 0; i < 3; i++) {
        expect(h.onScreen, entries[9 + i].itemId);
        await h.answer(Grade.clear);
      }
      // 900 before the resume and 300 since: the next entry would pass the ceiling.
      expect(h.onScreen, isNull);
      expect(h.shows("That is today's 20 minutes"), isTrue);
      expect(h.shows('The rest is due tomorrow.'), isTrue);
      expect(await h.store.attempts(), hasLength(3));
      final record = await h.store.day(today);
      expect(record!.completed, isTrue);
      expect(record.position, 12);
    });

    testWidgets(
        'a skipped entry after the position still counts toward the estimate: at 800 '
        'answered and one skip, the soft stop shows first', (tester) async {
      final entries = [
        for (final w in words.take(15)) entryOf(w, PlanSection.due, cost: 100)
      ];
      // The plan as a skip of the first entry left it: moved to the end of Due, requeued;
      // eight answered since.
      final plan = planOf([
        ...entries.skip(1),
        entries[0].copyWith(requeued: true),
      ]);
      final h = await pumpSession(tester, plan, position: 8);
      expect(h.onScreen, isNull, reason: '800 + the 100 skipped is the target');
      expect(h.shows('About 15 minutes'), isTrue);
      await h.tap('Keep going');
      for (var i = 0; i < 3; i++) {
        expect(h.onScreen, entries[9 + i].itemId);
        await h.answer(Grade.clear);
      }
      // 900 before the resume and 300 since: the next entry would pass the ceiling.
      expect(h.onScreen, isNull);
      expect(h.shows("That is today's 20 minutes"), isTrue);
      expect(await h.store.attempts(), hasLength(3));
    });

    testWidgets(
        'at 1200 seconds answered, the session ends on the ceiling card',
        (tester) async {
      final entries = [
        for (final w in words.take(13)) entryOf(w, PlanSection.due, cost: 100)
      ];
      final h = await pumpSession(tester, planOf(entries), position: 12);
      expect(h.onScreen, isNull);
      expect(h.shows("That is today's 20 minutes"), isTrue);
      expect(h.shows('The rest is due tomorrow.'), isTrue);
      expect(h.shows('One more (10)'), isFalse);
      expect(await h.store.attempts(), isEmpty);
      final record = await h.store.day(today);
      expect(record!.completed, isTrue);
      expect(record.position, 12);
    });

    testWidgets('wrong answers after a resume re-ask inside the ceiling only',
        (tester) async {
      final entries = [
        for (final w in words.take(12)) entryOf(w, PlanSection.due, cost: 100)
      ];
      final h = await pumpSession(tester, planOf(entries), position: 10);
      await h.tap('Keep going');
      // 1000 before the resume: two entries fit, and the wrong's re-ask does not.
      await h.answer(Grade.wrong);
      await h.answer(Grade.clear);
      expect(h.onScreen, isNull);
      expect(h.shows("That is today's 20 minutes"), isTrue);
      expect(await h.store.attempts(itemId: entries[10].itemId), hasLength(1));
    });

    testWidgets(
        'the end card counts the day\'s review answers and lists the items mastered today',
        (tester) async {
      final entries = [
        for (final w in words.take(10)) entryOf(w, PlanSection.due, cost: 60)
      ];
      final store = JpStoreMemory();
      // Nine review answers today before the relaunch, one from a drill screen today and
      // one review answer yesterday: only the nine count.
      for (var i = 0; i < 9; i++) {
        await store.appendAttempt(attemptOf(words[i], today,
            i == 7 ? Grade.hinted : (i == 8 ? Grade.wrong : Grade.clear)));
      }
      await store.appendAttempt(
          attemptOf(words[20], today, Grade.clear, sessionId: 'drill-1'));
      await store.appendAttempt(attemptOf(words[21], today - 1, Grade.clear));
      await store.putMastery(MasteryState(
          itemId: words[30].id,
          status: MasteryStatus.mastered,
          masteredOn: today));
      await store.putMastery(MasteryState(
          itemId: words[31].id,
          status: MasteryStatus.mastered,
          masteredOn: today - 1));
      final h =
          await pumpSession(tester, planOf(entries), store: store, position: 9);
      expect(h.onScreen, entries[9].itemId);
      await h.answer(Grade.clear);
      expect(h.shows('Done for today'), isTrue);
      expect(h.shows('10 answered · 8 clear · 1 with help · 1 missed'), isTrue);
      expect(h.shows('Mastered today'), isTrue);
      expect(h.shows(words[30].title), isTrue);
      expect(h.shows(words[31].title), isFalse);
    });

    testWidgets('a stretch already in the stored plan is not offered again',
        (tester) async {
      final base = [for (final w in words.take(3)) entryOf(w, PlanSection.due)];
      final stretch = [
        for (final w in words.skip(3).take(kStretchNew))
          entryOf(w, PlanSection.newItems)
      ];
      // The plan as `4 more new` left it: the four after the base, all answered.
      final h = await pumpSession(
          tester,
          planOf([...base, ...stretch],
              stretchOffer: true, stretchEntries: stretch),
          position: base.length + stretch.length);
      expect(h.shows('Done for today'), isTrue);
      expect(h.shows('4 more new'), isFalse);
    });

    testWidgets(
        'a catch-up block in the stored plan keeps its lifted ceiling and is not offered '
        'again', (tester) async {
      final base = [
        for (final w in words.take(13)) entryOf(w, PlanSection.due, cost: 100)
      ];
      final block = [
        for (final w in words.skip(13).take(10)) entryOf(w, PlanSection.due)
      ];
      // The plan as the tap left it: the block where the ceiling fell, three answered.
      final plan = planOf([...base.take(12), ...block, base[12]],
          catchUpOffer: true, catchUpEntries: block);
      final h = await pumpSession(tester, plan, position: 15);
      // 1230 seconds answered: the soft stop shows once on this sitting, then the block runs.
      await h.tap('Keep going');
      final asked = <String>[];
      while (h.onScreen != null) {
        asked.add(h.onScreen!);
        await h.answer(Grade.clear);
      }
      expect(asked, [for (final e in block.skip(3)) e.itemId]);
      expect(h.shows('Catch up: 10 more'), isFalse);
      // The entry past the block stays due: the lifted ceiling covers the block only.
      expect(h.shows('One more (10)'), isFalse);
      expect(await h.store.attempts(itemId: base[12].itemId), isEmpty);
    });

    testWidgets(
        'a resumed catch-up block ends after the block even with room under its ceiling',
        (tester) async {
      final base = [
        for (final w in words.take(5)) entryOf(w, PlanSection.due, cost: 100)
      ];
      final block = [
        for (final w in words.skip(5).take(10)) entryOf(w, PlanSection.due)
      ];
      // The plan finished under the ceiling, then the tap added the block; two answered.
      final h = await pumpSession(
          tester,
          planOf([...base, ...block],
              catchUpOffer: true, catchUpEntries: block),
          position: 7);
      expect(h.onScreen, block[2].itemId);
      // The wrong's re-ask lands after the block, so the block's end stops before it.
      await h.answer(Grade.wrong);
      var more = 0;
      while (h.onScreen != null) {
        await h.answer(Grade.clear);
        more++;
      }
      expect(more, 7);
      expect(h.shows('Done for today'), isTrue);
      expect(await h.store.attempts(itemId: block[2].itemId), hasLength(1));
      expect(h.shows('Catch up: 10 more'), isFalse);
      // One more runs the re-ask under the lifted ceiling and finishes the plan: the
      // catch-up, already in the plan, is still not offered again.
      await h.tap('One more (10)');
      expect(h.onScreen, block[2].itemId);
      await h.answer(Grade.clear);
      expect(h.shows('Done for today'), isTrue);
      expect(h.shows('Catch up: 10 more'), isFalse);
    });

    testWidgets(
        'a re-ask of a catch-up item in the stored plan is not part of the block: the '
        'block still ends after its own ten', (tester) async {
      final base = [
        for (final w in words.take(5)) entryOf(w, PlanSection.due, cost: 100)
      ];
      final block = [
        for (final w in words.skip(5).take(10)) entryOf(w, PlanSection.due)
      ];
      // The plan as a wrong on the third block entry left it: its re-ask after the block.
      final plan = planOf([
        ...base,
        ...block,
        block[2]
            .copyWith(section: PlanSection.repair, wasDue: false, reask: true),
      ], catchUpOffer: true, catchUpEntries: block);
      final h = await pumpSession(tester, plan, position: 8);
      var more = 0;
      while (h.onScreen != null) {
        await h.answer(Grade.clear);
        more++;
      }
      expect(more, 7, reason: 'the seven block entries left, not the re-ask');
      expect(h.shows('Done for today'), isTrue);
      expect(await h.store.attempts(itemId: block[2].itemId), isEmpty);
      expect(h.shows('One more (10)'), isTrue,
          reason: 'the re-ask is still planned and fits');
    });

    testWidgets(
        'a skipped re-ask after the position counts toward the estimate: at 800 answered '
        'and its skip, the soft stop shows first', (tester) async {
      final entries = [
        for (final w in words.take(15)) entryOf(w, PlanSection.due, cost: 100)
      ];
      QueueEntry reaskOf(QueueEntry e, {bool requeued = false}) => e.copyWith(
          section: PlanSection.repair,
          wasDue: false,
          requeued: requeued,
          reask: true);
      // The plan as the live session left it: the first two entries wrong, five more
      // answered, the first re-ask skipped (moved after the second re-ask) and the second
      // re-ask answered: eight answers at the position and one skip past it.
      final plan = planOf([
        ...entries.take(7),
        reaskOf(entries[1]),
        reaskOf(entries[0], requeued: true),
        ...entries.skip(7),
      ]);
      final h = await pumpSession(tester, plan, position: 8);
      expect(h.onScreen, isNull, reason: '800 + the 100 skipped is the target');
      expect(h.shows('About 15 minutes'), isTrue);
      await h.tap('Keep going');
      expect(h.onScreen, entries[0].itemId, reason: 'the skipped re-ask');
      for (var i = 0; i < 3; i++) {
        await h.answer(Grade.clear);
      }
      // 900 before the resume and 300 since: the next entry would pass the ceiling.
      expect(h.onScreen, isNull);
      expect(h.shows("That is today's 20 minutes"), isTrue);
      expect(await h.store.attempts(), hasLength(3));
    });

    testWidgets(
        'a skipped re-ask of a catch-up item is not counted into the spend before the tap: '
        'the lifted ceiling is the block\'s cost over the plan\'s ceiling',
        (tester) async {
      final base = [
        for (final w in words.take(12)) entryOf(w, PlanSection.due, cost: 100)
      ];
      final block = [
        for (final w in words.skip(12).take(10))
          entryOf(w, PlanSection.due, cost: 100)
      ];
      // The plan as the tap left it at the ceiling, then a wrong on the first block entry
      // whose re-ask landed inside the block, skipped once (it stays put as the only
      // re-ask) and then answered: the lift is the block's 1000, so the ceiling is 2200.
      final plan = planOf([
        ...base,
        ...block.take(7),
        block[0].copyWith(
            section: PlanSection.repair,
            wasDue: false,
            requeued: true,
            reask: true),
        ...block.skip(7),
      ], catchUpOffer: true, catchUpEntries: block);
      final h = await pumpSession(tester, plan, position: 20);
      // 1200 + 700 + the skip + the answer = 2100 spent: one block entry fits, not two.
      await h.tap('Keep going');
      expect(h.onScreen, block[7].itemId);
      await h.answer(Grade.clear);
      expect(h.onScreen, isNull);
      expect(h.shows("That is today's 20 minutes"), isTrue);
      expect(await h.store.attempts(itemId: block[8].itemId), isEmpty);
    });
  });

  test('the section line names the section and the place in it', () {
    final plan = planOf([
      entryOf(words[0], PlanSection.repair),
      for (final w in words.skip(1).take(42)) entryOf(w, PlanSection.due),
    ]);
    expect(sectionPosition(plan, 0), 'Repair · 1 of 1');
    expect(sectionPosition(plan, 12), 'Due · 12 of 42');
  });

  group('Review the lesson (plan 2026-11-06, Task 2, PIN-5)', () {
    final grammar = catalog.ofKind(ItemKind.grammar).first;

    /// The session under a router that knows every lesson target's route name. Each target is
    /// a stub page naming its route and query, with a Back that pops it.
    Future<Harness> pumpRouted(WidgetTester tester, DayPlan plan) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final s = JpStoreMemory();
      await s.putDay(DayRecord(day: today, plan: plan.encode(), position: 0));
      // Every item in the catalog, so a taught and an untaught particle both have a route.
      final names = {
        for (final kind in ItemKind.values)
          for (final item in catalog.ofKind(kind))
            lessonTargetOf(item).routeName
      };
      final router = GoRouter(routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
            body: SessionWidget(
              plan: plan,
              store: s,
              clock: FixedClock(at(today)),
              catalog: catalog,
              probeBuilder: fakeProbe,
            ),
          ),
        ),
        for (final name in names)
          GoRoute(
            path: '/stub-$name',
            name: name,
            builder: (context, state) => Scaffold(
              body: Column(children: [
                Text('lesson $name ${state.uri.queryParameters}'),
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back')),
              ]),
            ),
          ),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      final h = Harness(tester, s);
      await h.settle();
      return h;
    }

    testWidgets(
        "the link opens the kind's target, Back returns to the same unanswered card "
        'marked Lesson reviewed, and a clear after it is hinted (End state 1)',
        (tester) async {
      final plan = planOf([
        entryOf(grammar, PlanSection.due),
        entryOf(words[0], PlanSection.due),
      ]);
      final h = await pumpRouted(tester, plan);
      expect(h.onScreen, grammar.id);
      expect(find.text(kReviewTheLesson), findsOneWidget);
      expect(find.text(reviewLessonDetail(grammar)), findsOneWidget);
      expect(find.text(kLessonReviewed), findsNothing);

      await tester.tap(find.text(kReviewTheLesson));
      await tester.pumpAndSettle();
      final target = lessonTargetOf(grammar);
      expect(target.query['point'], grammar.id);
      expect(find.text('lesson ${target.routeName} ${target.query}'),
          findsOneWidget);
      expect(await h.store.attempts(), isEmpty,
          reason: 'opening a lesson writes no attempt');

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(h.onScreen, grammar.id, reason: 'the same card');
      expect(h.shows(sectionPosition(plan, 0)), isTrue);
      expect(find.text(kLessonReviewed), findsOneWidget);
      expect(await h.store.attempts(), isEmpty, reason: 'still unanswered');

      await h.tap('answer clear');
      expect(h.shows('Right with a hint'), isTrue);
      final a = (await h.store.attempts()).single;
      expect(a.itemId, grammar.id);
      expect(a.grade, Grade.hinted);
      expect(a.hintLevel, 1);
      expect(a.rating, fsrsRatingFor(Grade.hinted));
      expect(find.text(kReviewTheLesson), findsNothing,
          reason: 'an answered card has no link');

      await h.tap('Next');
      expect(h.onScreen, words[0].id);
      expect(find.text(kLessonReviewed), findsNothing,
          reason: 'a review covers its own card only');
      await h.tap('answer clear');
      expect(h.shows('Clear'), isTrue);
      expect((await h.store.attempts(itemId: words[0].id)).single.grade,
          Grade.clear);
    });

    testWidgets(
        'the link pushes the lesson target of every item kind through the router, '
        'and Back returns to the same card', (tester) async {
      // The first of each kind, plus a taught particle: the first particle has no
      // lesson, so both particle arms of lessonTargetOf go through the router.
      final items = [
        for (final kind in ItemKind.values) catalog.ofKind(kind).first,
        catalog.ofKind(ItemKind.particle).firstWhere((i) => i.lesson != null),
      ];
      for (final item in items) {
        final kind = item.kind.name;
        final h =
            await pumpRouted(tester, planOf([entryOf(item, PlanSection.due)]));
        expect(h.onScreen, item.id, reason: kind);
        expect(find.text(kLessonReviewed), findsNothing, reason: kind);

        await tester.tap(find.text(kReviewTheLesson));
        await tester.pumpAndSettle();
        final target = lessonTargetOf(item);
        expect(find.text('lesson ${target.routeName} ${target.query}'),
            findsOneWidget,
            reason: '$kind: the route and query of ${item.id}');

        await tester.tap(find.text('Back'));
        await tester.pumpAndSettle();
        expect(h.onScreen, item.id, reason: '$kind: the same card');
        expect(find.text(kLessonReviewed), findsOneWidget, reason: kind);
        expect(await h.store.attempts(), isEmpty,
            reason: '$kind: opening a lesson writes no attempt');
      }
    });

    testWidgets(
        'a failed lesson open leaves the card unreviewed and a clear stays clear',
        (tester) async {
      final h = await pumpSession(
          tester, planOf([entryOf(words[0], PlanSection.due)]),
          openLesson: (context, item) async => throw StateError('no route'));
      expect(h.onScreen, words[0].id);
      await h.tap(kReviewTheLesson);
      expect(tester.takeException(), isA<StateError>(),
          reason: 'the failure is reported, not swallowed');
      expect(find.text(kLessonReviewed), findsNothing,
          reason: 'no lesson opened, so no mark');
      expect(find.text(kReviewTheLesson), findsOneWidget,
          reason: 'the link stays for another try');

      await h.tap('answer clear');
      expect(h.shows('Clear'), isTrue);
      final a = (await h.store.attempts()).single;
      expect(a.grade, Grade.clear);
      expect(a.hintLevel, 0);
    });

    testWidgets(
        'a failed open after an earlier open of the same card keeps the mark',
        (tester) async {
      var opens = 0;
      final h = await pumpSession(
          tester, planOf([entryOf(words[0], PlanSection.due)]),
          openLesson: (context, item) async {
        if (++opens > 1) throw StateError('no route');
      });
      await h.tap(kReviewTheLesson);
      expect(find.text(kLessonReviewed), findsOneWidget);
      await h.tap(kReviewTheLesson);
      expect(tester.takeException(), isA<StateError>());
      expect(find.text(kLessonReviewed), findsOneWidget,
          reason: 'the lesson was seen once, so the mark stays');

      await h.tap('answer clear');
      expect(h.shows('Right with a hint'), isTrue);
      final a = (await h.store.attempts()).single;
      expect(a.grade, Grade.hinted);
      expect(a.hintLevel, 1);
    });

    testWidgets('wrong, hinted and unscored after a review are untouched',
        (tester) async {
      final opened = <String>[];
      final h = await pumpSession(
          tester,
          planOf([
            entryOf(words[0], PlanSection.due),
            entryOf(words[1], PlanSection.due),
            entryOf(words[2], PlanSection.due),
          ]),
          openLesson: (context, item) async => opened.add(item.id));
      Future<void> review() async {
        await h.tap(kReviewTheLesson);
        expect(find.text(kLessonReviewed), findsOneWidget);
      }

      await review();
      await h.tap('answer hinted');
      await h.tap('Next');
      await review();
      await h.tap('answer unscored');
      await h.tap('Next');
      // The skip moved words[1] to the end of the section, so words[2] is next.
      expect(h.onScreen, words[2].id);
      await review();
      await h.tap('answer wrong');
      expect(find.text(kReviewTheLesson), findsNothing,
          reason: 'a held wrong has no link');

      expect(opened, [words[0].id, words[1].id, words[2].id]);
      final byId = {for (final a in await h.store.attempts()) a.itemId: a};
      expect(byId[words[0].id]!.grade, Grade.hinted);
      expect(byId[words[0].id]!.hintLevel, 1,
          reason: 'a hint and a review are not counted twice');
      expect(byId[words[1].id]!.grade, Grade.unscored);
      expect(byId[words[1].id]!.hintLevel, 0);
      expect(byId[words[2].id]!.grade, Grade.wrong);
      expect(byId[words[2].id]!.hintLevel, 0);
    });

    testWidgets('a review after the answer changes nothing', (tester) async {
      final h = await pumpSession(
          tester, planOf([entryOf(words[0], PlanSection.due)]),
          openLesson: (context, item) async {});
      await h.tap('answer clear');
      expect(h.shows('Clear'), isTrue);
      expect(find.text(kReviewTheLesson), findsNothing,
          reason: 'the verdict card offers no review');
      expect((await h.store.attempts()).single.grade, Grade.clear);
    });

    testWidgets('with no router and no opener the card shows no dead link',
        (tester) async {
      final h = await pumpSession(
          tester, planOf([entryOf(words[0], PlanSection.due)]));
      expect(h.onScreen, words[0].id);
      expect(find.text(kReviewTheLesson), findsNothing);
    });
  });

  group('next card (plan 2026-11-06, Tasks 6 and 9, D19, D11)', () {
    final word = words[0];
    final particle = catalog.ofKind(ItemKind.particle).first;
    ProbeDef probeOf(ItemDef item, String template) =>
        item.probes.firstWhere((p) => p.template == template);

    /// A counting clear on [probe] of [item] on [day].
    ClearRef clearOn(ItemDef item, String template, int day) {
      final p = probeOf(item, template);
      return ClearRef(
          day: day,
          template: p.template,
          production: p.production,
          probeId: p.id);
    }

    MasteryState learning(ItemDef item, List<ClearRef> clears) => MasteryState(
        itemId: item.id, status: MasteryStatus.learning, clears: clears);

    test('a new item asks its first scored probe', () {
      expect(nextProbe(word, MasteryState.initial(word.id), 0).id,
          word.scoredProbes.first.id);
      expect(nextProbe(word, MasteryState.initial(word.id), 5).id,
          word.scoredProbes.first.id,
          reason: 'no mode has a clear, so the first probe of the first mode');
    });

    test('the first probe whose mode has no counting clear comes next', () {
      // The card (see it) is cleared: the spoken probe is the first spoken one.
      expect(
          nextProbe(word, learning(word, [clearOn(word, 'card', 1)]), 1)
              .template,
          'spoken');
      // See it and say it cleared: type it.
      expect(
          nextProbe(
                  word,
                  learning(word,
                      [clearOn(word, 'card', 1), clearOn(word, 'spoken', 2)]),
                  2)
              .template,
          'typed');
      // A say card clear counts as say it too (D18).
      expect(
          nextProbe(
                  word,
                  learning(word, [
                    clearOn(word, 'card', 1),
                    clearOn(word, kSayCardTemplate, 2)
                  ]),
                  2)
              .template,
          'typed');
      // A particle: type it, then see it (the choose card), then say it.
      expect(
          nextProbe(particle,
                  learning(particle, [clearOn(particle, 'cloze', 1)]), 1)
              .id,
          kParticleChooseId);
      expect(
          nextProbe(
                  particle,
                  learning(particle, [
                    clearOn(particle, 'cloze', 1),
                    clearOn(particle, 'choose', 2)
                  ]),
                  2)
              .id,
          sayCardId('cloze'));
    });

    test('the needed mode wins over the rotation when the two disagree', () {
      // See it and say it cleared at answered 0: the rotation would give the card again
      // (the first probe), so only the mode-aware pick lands on type it.
      final typed = nextProbe(
          word,
          learning(
              word, [clearOn(word, 'card', 1), clearOn(word, 'spoken', 2)]),
          0);
      expect(typed.id, 'typed');
      expect(word.scoredProbes.first.id, isNot('typed'),
          reason: 'the rotation at 0 gives a different probe');
      // A particle at answered 0: type it cleared gives the choose card, then both
      // cleared gives the say card, where the rotation would give the cloze each time.
      expect(
          nextProbe(particle,
                  learning(particle, [clearOn(particle, 'cloze', 1)]), 0)
              .id,
          kParticleChooseId);
      expect(
          nextProbe(
                  particle,
                  learning(particle, [
                    clearOn(particle, 'cloze', 1),
                    clearOn(particle, 'choose', 2)
                  ]),
                  0)
              .id,
          sayCardId('cloze'));
      expect(particle.scoredProbes.first.id, 'cloze');
    });

    test('a needed mode shows before the 4th clear', () {
      // Three see-it clears: the fourth card is never another see-it card.
      final three = learning(word, [
        clearOn(word, 'card', 1),
        clearOn(word, 'card', 2),
        clearOn(word, 'card', 3),
      ]);
      for (var answered = 0; answered < 12; answered++) {
        final p = nextProbe(word, three, answered);
        expect(modeOfTemplate(p.template), isNot(ProbeMode.recognition),
            reason: 'after $answered attempts');
      }
    });

    test("once every mode has a clear, a word's scored probes take turns", () {
      final all = learning(word, [
        clearOn(word, 'card', 1),
        clearOn(word, 'spoken', 2),
        clearOn(word, 'typed', 3),
      ]);
      final scored = word.scoredProbes.toList();
      for (var answered = 0; answered < scored.length * 2; answered++) {
        expect(nextProbe(word, all, answered).id,
            scored[answered % scored.length].id);
      }
    });

    test('an item with no scored probe is never asked', () {
      final none = ItemDef(
          id: 'none',
          kind: ItemKind.grammar,
          title: 'none',
          prereqLevel: 2,
          probes: const [
            ProbeDef(
                id: 'ex0',
                template: kSayItTemplate,
                text: 'a',
                answer: 'a',
                scored: false)
          ]);
      expect(
          () => nextProbe(none, const MasteryState.initial('none'), 0),
          throwsA(isA<StateError>().having((e) => e.message, 'message',
              contains('has no scored probe to ask'))));
    });

    // Sentence rotation (plan 2026-11-06, Task 9, D11, PIN-4).
    ClearRef on(ItemDef item, String id, int day) {
      final p = item.probes.firstWhere((x) => x.id == id);
      return ClearRef(
          day: day,
          template: p.template,
          production: p.production,
          probeId: p.id);
    }

    test('a particle carries one cloze per sentence, the first keeps its id',
        () {
      final clozes = [
        for (final p in particle.scoredProbes)
          if (p.template == 'cloze') p.id
      ];
      expect(
          clozes, [kParticleClozeId, particleClozeId(1), particleClozeId(2)]);
    });

    test('within the needed mode, a sentence with no clear comes first', () {
      // See it and say it cleared on the first sentence on two days: type it is needed, and
      // sentence 1 has no clear, so the session asks it. The pick is the same whether the
      // first sentence's clears fall on two days or one, so the 2-day move-on decides
      // nothing here; the D11 test below covers that at both boundaries.
      final moved = learning(particle, [
        clearOn(particle, 'choose', 1),
        clearOn(particle, kSayCardTemplate, 2),
      ]);
      for (var answered = 0; answered < 6; answered++) {
        expect(nextProbe(particle, moved, answered).id, particleClozeId(1),
            reason: 'after $answered attempts');
      }
      // The same two modes on one day: sentence 1 still has no clear, so it comes first.
      final oneDay = learning(particle, [
        clearOn(particle, 'choose', 1),
        clearOn(particle, kSayCardTemplate, 1),
      ]);
      expect(nextProbe(particle, oneDay, 0).id, particleClozeId(1));
    });

    test('once every mode has a clear, the next sentence with no clear comes',
        () {
      final modes = [
        on(particle, kParticleClozeId, 1),
        on(particle, kParticleChooseId, 1),
        on(particle, sayCardId(kParticleClozeId), 1),
      ];
      expect(nextProbe(particle, learning(particle, modes), 3).id,
          particleClozeId(1));
      expect(
          nextProbe(
                  particle,
                  learning(particle,
                      [...modes, on(particle, particleClozeId(1), 2)]),
                  4)
              .id,
          particleClozeId(2));
    });

    test('a sentence cleared on 2 different days moves aside (D11)', () {
      // Every mode cleared, every sentence cleared, the first on two days: the session never
      // asks the first sentence again, in any of its three cards.
      final state = learning(particle, [
        on(particle, kParticleClozeId, 1),
        on(particle, kParticleChooseId, 2),
        on(particle, sayCardId(kParticleClozeId), 2),
        on(particle, particleClozeId(1), 3),
        on(particle, particleClozeId(2), 3),
      ]);
      final seen = <String>{};
      for (var answered = 0; answered < 12; answered++) {
        final p = nextProbe(particle, state, answered);
        expect(transferKeyOf(p.id), isNot(kParticleClozeId),
            reason: 'after $answered attempts');
        seen.add(p.id);
      }
      expect(seen, {particleClozeId(1), particleClozeId(2)},
          reason: 'the two sentences left take turns');
      // On one day only, the first sentence is still in the turns.
      final oneDay = learning(particle, [
        on(particle, kParticleClozeId, 1),
        on(particle, kParticleChooseId, 1),
        on(particle, sayCardId(kParticleClozeId), 1),
        on(particle, particleClozeId(1), 3),
        on(particle, particleClozeId(2), 3),
      ]);
      expect({
        for (var answered = 0; answered < 12; answered++)
          transferKeyOf(nextProbe(particle, oneDay, answered).id)
      }, contains(kParticleClozeId));
    });

    test('a rotate marker takes the scored probes in turn by attempts so far',
        () {
      // Early practice and a re-ask after a wrong (plan 2026-11-06, ASK-5): the state the
      // D19 pick answers with the first card gives a different card per attempt.
      final scored = word.scoredProbes.toList();
      final fresh = MasteryState.initial(word.id);
      for (var answered = 0; answered < scored.length * 2; answered++) {
        expect(nextProbe(word, fresh, answered, rotate: true).id,
            scored[answered % scored.length].id);
      }
      expect(nextProbe(word, fresh, 1).id, scored.first.id,
          reason: 'with no marker the D19 pick keeps the first needed mode');
      expect(
          nextProbe(word, fresh, 1, rotate: true).id, isNot(scored.first.id));
    });

    final grammarDoc = _read('assets/lessons/jp_grammar.json');

    /// The shipped `jp_grammar.json` practice rows of the grammar point [id].
    List<Map<String, dynamic>> practiceRowsOf(String id) {
      for (final lesson in (grammarDoc['grammar'] as List).cast<Map>()) {
        for (final point in (lesson['points'] as List).cast<Map>()) {
          if (point['id'] == id) {
            return (point['practice'] as List).cast<Map<String, dynamic>>();
          }
        }
      }
      throw StateError('no grammar point $id in jp_grammar.json');
    }

    /// The shipped `jp_grammar.json` row of the particle [id].
    Map<String, dynamic> particleRowOf(String id) =>
        (grammarDoc['particles'] as List)
            .cast<Map<String, dynamic>>()
            .firstWhere((p) => p['id'] == id);

    Future<Harness> pumpPicked(WidgetTester tester, ItemDef item,
        MasteryState state, FakePronunciation pron) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final s = JpStoreMemory();
      await s.putMastery(state);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SessionWidget(
            plan: planOf([entryOf(item, PlanSection.due)]),
            store: s,
            clock: FixedClock(at(today)),
            catalog: catalog,
            probeBuilder: standardProbeBuilder(
                grammar: _read('assets/lessons/jp_grammar.json'),
                pronunciation: pron),
          ),
        ),
      ));
      final h = Harness(tester, s);
      await h.settle();
      return h;
    }

    testWidgets(
        "the session shows a particle's choose card once its cloze is cleared",
        (tester) async {
      final pron = FakePronunciation();
      final h = await pumpPicked(tester, particle,
          learning(particle, [clearOn(particle, 'cloze', today - 1)]), pron);
      final choose = probeOf(particle, 'choose');
      expect(h.shows('Choose the missing part'), isTrue);
      for (final o in choose.options) {
        expect(h.shows(o), isTrue, reason: 'the option $o');
      }
      await h.tap(choose.answer);
      final a = (await h.store.attempts(itemId: particle.id)).single;
      expect(a.probeId, kParticleChooseId);
      expect(a.template, 'choose');
      expect(a.grade, Grade.clear);
    });

    testWidgets(
        'a say card scores through the service and writes the entry source, never Say-it',
        (tester) async {
      final pron = FakePronunciation();
      final h = await pumpPicked(
          tester,
          particle,
          learning(particle, [
            clearOn(particle, 'cloze', today - 2),
            clearOn(particle, 'choose', today - 1),
          ]),
          pron);
      final say = probeOf(particle, kSayCardTemplate);
      expect(h.shows('Say the whole sentence'), isTrue);
      expect(h.shows(say.text), isTrue);
      expect(
          h.shows(particleRowOf(particle.id)['example_en'] as String), isTrue,
          reason: "the builder passes the particle's English");
      expect(h.shows(say.answer), isFalse, reason: 'the prompt only (PIN-12)');
      await h.tap('Say it');
      expect(pron.referenceTexts.single, say.answer);
      pron.answer(Judgement.correct);
      await h.settle();
      final a = (await h.store.attempts(itemId: particle.id)).single;
      expect(a.probeId, sayCardId('cloze'));
      expect(a.template, kSayCardTemplate);
      expect(a.grade, Grade.clear);
      expect(a.source, Source.review, reason: "the entry's source (D18)");
      expect(a.production, isTrue);
      final m = await h.store.mastery(particle.id);
      expect(m!.clears.map((c) => c.template).toList(),
          ['cloze', 'choose', kSayCardTemplate],
          reason: 'a say card clear counts toward Mastered');
    });

    testWidgets(
        "a grammar say card shows the English of the practice row it twins",
        (tester) async {
      // A typed and a recognition clear: say it is needed, and the pick is the first say
      // card whose sentence has no clear yet (D11, Task 9), past p0 and the choose row. Its
      // English is that practice row's, read through `transferKeyOf` in the real builder.
      final grammar = catalog.ofKind(ItemKind.grammar).first;
      final fill = probeOf(grammar, 'fill'),
          choose = probeOf(grammar, 'choose');
      final pron = FakePronunciation();
      final h = await pumpPicked(
          tester,
          grammar,
          learning(grammar, [
            clearOn(grammar, 'fill', today - 2),
            clearOn(grammar, 'choose', today - 1),
          ]),
          pron);
      final say = grammar.scoredProbes.firstWhere((p) =>
          p.template == kSayCardTemplate &&
          transferKeyOf(p.id) != fill.id &&
          transferKeyOf(p.id) != choose.id);
      final row = int.parse(transferKeyOf(say.id).substring(1));
      expect(row, greaterThan(0), reason: 'a say card past row 0');
      final rows = practiceRowsOf(grammar.id);
      expect(h.shows('Say the whole sentence'), isTrue);
      expect(h.shows(say.text), isTrue);
      expect(h.shows(rows[row]['en'] as String), isTrue,
          reason: 'row $row English, through the twin id');
      expect(h.shows(say.answer), isFalse, reason: 'the prompt only (PIN-12)');
    });

    testWidgets(
        "a particle's second cloze shows that sentence's English, not the example",
        (tester) async {
      // A recognition and a spoken clear: type it is needed, and the say clear counts for
      // sentence 0 through `transferKeyOf`, so the pick is `cloze.1` (D11, Task 9). Its
      // English is the drafted sentence's own, read by `particleEnglish` in the real builder.
      final pron = FakePronunciation();
      final h = await pumpPicked(
          tester,
          particle,
          learning(particle, [
            clearOn(particle, 'choose', today - 2),
            clearOn(particle, kSayCardTemplate, today - 1),
          ]),
          pron);
      final row = particleRowOf(particle.id);
      final sentences = (row['sentences'] as List).cast<Map>();
      final english = sentences[1]['english'] as String;
      expect(english, isNot(row['example_en']),
          reason: 'the check needs two different translations');
      await h.tap('Show English');
      expect(h.shows(english), isTrue, reason: "sentence 1's own English");
      expect(h.shows(row['example_en'] as String), isFalse,
          reason: 'not the example sentence the fallback would show');
    });

    testWidgets('a word with a see-it clear asks its spoken card next',
        (tester) async {
      final pron = FakePronunciation();
      final h = await pumpPicked(tester, word,
          learning(word, [clearOn(word, 'card', today - 1)]), pron);
      expect(h.shows('Say or type the word'), isTrue,
          reason: 'the spoken card, not the card recall again');
      expect(h.shows('Show me'), isFalse);
    });

    // Through the hosts (plan 2026-11-06, Task 9, ASK-5): a probe builder that asks the
    // session's own pick, with the marker each host passes. Every case seeds a prior
    // attempt, because at answered 0 the rotation and the D19 pick both give the first card.

    /// The fake probe on the pick: it names the card it asks and answers on it.
    Widget pickedProbe(BuildContext context, SessionProbeRequest r) {
      final probe = nextProbe(r.item, r.state, r.answered, rotate: r.rotate);
      DrillAnswer draft(Grade g) => DrillAnswer(
          itemId: r.item.id,
          probeId: probe.id,
          template: probe.template,
          production: probe.production,
          selfGraded: probe.selfGraded,
          grade: g);
      return Column(children: [
        Text('asks ${probe.id}'),
        for (final g in [Grade.clear, Grade.wrong])
          TextButton(
              onPressed: () => r.onAnswer(draft(g)),
              child: Text('answer ${g.name}')),
      ]);
    }

    String? asked() {
      final f = find.textContaining('asks ');
      if (f.evaluate().isEmpty) return null;
      return (f.evaluate().single.widget as Text).data!.substring(5);
    }

    Future<Harness> pumpWithPick(WidgetTester tester, JpStoreMemory s,
        Widget Function(JpStoreMemory s) body) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: body(s))));
      final h = Harness(tester, s);
      await h.settle();
      return h;
    }

    testWidgets('two early answers in Practice now show two different cards',
        (tester) async {
      final s = JpStoreMemory();
      // A prior attempt and no schedule: the word is not due, so practice is early.
      await s.appendAttempt(attemptOf(word, today - 1, Grade.hinted));
      final shown = <String?>[];
      for (var i = 0; i < 2; i++) {
        final h = await pumpWithPick(
            tester,
            s,
            (s) => PracticeSessionWidget(
                key: ValueKey('practice-$i'),
                items: [word],
                store: s,
                catalog: catalog,
                clock: FixedClock(at(today)),
                probeBuilder: pickedProbe));
        shown.add(asked());
        await h.tap('answer clear');
      }
      expect(shown[0], isNotNull);
      expect(shown[1], isNot(shown[0]),
          reason: 'early practice rotates by attempts so far');
      final written = (await s.attempts(itemId: word.id)).skip(1);
      expect(written.map((a) => a.probeId).toList(), shown);
      expect(written.every((a) => a.source == Source.early), isTrue);
    });

    testWidgets('a due item in Practice now keeps the first needed mode',
        (tester) async {
      final s = JpStoreMemory();
      await s.appendAttempt(attemptOf(word, today - 1, Grade.hinted));
      await s.putSrs(
          word.id,
          const SrsState(
              stability: 1.0,
              difficulty: 5.0,
              lastReviewDay: today - 1,
              dueDay: today,
              interval: 1));
      await pumpWithPick(
          tester,
          s,
          (s) => PracticeSessionWidget(
              items: [word],
              store: s,
              catalog: catalog,
              clock: FixedClock(at(today)),
              probeBuilder: pickedProbe));
      expect(asked(), word.scoredProbes.first.id,
          reason: 'a due review keeps the D19 pick, not the rotation');
    });

    testWidgets(
        'a seeded item due today in Practice now keeps the first needed mode',
        (tester) async {
      // A seed and no FSRS row (the state after `seedFromLessons`, PIN-9): the due day comes
      // from `seedDueDay`, so the item is due and the D19 pick holds (plan 2026-11-06, ASK-5).
      final s = JpStoreMemory();
      await s.appendAttempt(attemptOf(word, today - 1, Grade.hinted));
      await s.appendSeeds([
        SeedEvent(itemId: word.id, dueDay: today, atUtc: at(today).toUtc())
      ]);
      await pumpWithPick(
          tester,
          s,
          (s) => PracticeSessionWidget(
              items: [word],
              store: s,
              catalog: catalog,
              clock: FixedClock(at(today)),
              probeBuilder: pickedProbe));
      expect(asked(), word.scoredProbes.first.id,
          reason: 'a seeded due item keeps the D19 pick, not the rotation');
    });

    testWidgets('a due entry in the session still shows the first needed mode',
        (tester) async {
      final s = JpStoreMemory();
      await s.appendAttempt(attemptOf(word, today - 1, Grade.hinted));
      await pumpWithPick(
          tester,
          s,
          (s) => SessionWidget(
              plan: planOf([entryOf(word, PlanSection.due)]),
              store: s,
              clock: FixedClock(at(today)),
              catalog: catalog,
              probeBuilder: pickedProbe));
      expect(asked(), word.scoredProbes.first.id);
      expect(nextProbe(word, MasteryState.initial(word.id), 1, rotate: true).id,
          isNot(word.scoredProbes.first.id),
          reason: 'the rotation would have shown another card here');
    });

    testWidgets(
        'a re-ask after a wrong rotates to a different card here, and the held card stays',
        (tester) async {
      // The rotation is by attempts so far (plan 2026-11-06, ASK-5), not away from the card
      // just missed: with other prior attempts the rotated card can coincide with the D19
      // pick. This seeding (one prior attempt, the first card asked) keeps them apart.
      final s = JpStoreMemory();
      await s.appendAttempt(attemptOf(word, today - 1, Grade.hinted));
      final h = await pumpWithPick(
          tester,
          s,
          (s) => SessionWidget(
              plan: planOf([entryOf(word, PlanSection.due)]),
              store: s,
              clock: FixedClock(at(today)),
              catalog: catalog,
              probeBuilder: pickedProbe));
      final first = asked();
      expect(first, word.scoredProbes.first.id);
      await h.tap('answer wrong');
      // The held card is the card just answered, though the plan already moved on to the
      // re-ask (a marker read from the live entry would change it here).
      expect(h.shows('Next'), isTrue);
      expect(asked(), first, reason: 'the held card keeps its probe');
      await h.tap('Next');
      final again = asked();
      expect(again, isNotNull, reason: 'the re-ask is on screen');
      expect(again, isNot(first),
          reason: 'a re-ask rotates (plan 2026-11-06, ASK-5)');
      await h.tap('answer clear');
      final probes =
          (await s.attempts(itemId: word.id)).skip(1).map((a) => a.probeId);
      expect(probes.toList(), [first, again]);
    });
  });
}
