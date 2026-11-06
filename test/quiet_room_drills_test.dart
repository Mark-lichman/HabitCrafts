// Widget tests for the drills screen: a counter cell keeps its legend color hidden
// until it is tapped, because the color gives away whether the reading is regular.
//
// Plan 2026-11-02, Task 11: every self-graded answer on the three drills writes one attempt
// through an injected recorder. Got it is clear and Missed it is wrong (PIN-13). The tests
// assert the item and probe ids on the written attempts, and that each resolves in the item
// catalog, so a drill and the catalog never name one probe two ways.
//
// Plan 2026-11-06, Task 1: a card opens a drill at its idea (a form, a pair's row, a table's
// row) with the "Back to practice" bar, and the open writes nothing.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:habit_craft/components/pages/quiet_room_grammar/jp_study_kit.dart';
import 'package:habit_craft/components/pages/quiet_room_grammar/quiet_room_drills_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/attempt.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/drill_recorder.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/item_catalog.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_memory.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/local_day.dart';
import 'package:habit_craft/flutter_flow/quiet_room.dart';

import 'jp_screen_harness.dart';

final _catalog = ItemCatalog.fromDocs(
    readLessonFile(),
    json.decode(File('assets/lessons/jp_lessons.json').readAsStringSync())
        as Map<String, dynamic>);

/// A drill wired to a fresh memory store through the real recorder.
class DrillRig {
  DrillRig({JpStoreMemory? store}) : store = store ?? JpStoreMemory();

  final JpStoreMemory store;
  late final recorder = AttemptRecorder.on(store, lookup: _catalog.byId);

  Future<void> open(WidgetTester tester, String mode) => pumpStudyScreen(
      tester, QuietRoomDrillsWidget(mode: mode, recorder: recorder));

  /// The attempts written so far, after the recorder's queue drains.
  Future<List<Attempt>> attempts(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    await recorder.idle;
    return store.attempts();
  }
}

/// Every written attempt names a catalog item and one of that item's probes, with the
/// probe's own template, and it is self-graded (PIN-13).
void expectInCatalog(List<Attempt> attempts) {
  for (final a in attempts) {
    final item = _catalog.byId(a.itemId);
    expect(item, isNotNull, reason: '${a.itemId} is not a catalog item');
    final probe = item!.probes.where((p) => p.id == a.probeId).firstOrNull;
    expect(probe, isNotNull,
        reason: '${a.probeId} is not a probe of ${a.itemId}');
    expect(a.template, probe!.template);
    expect(a.production, probe.production);
    expect(a.selfGraded, isTrue);
    expect(probe.selfGraded, isTrue);
    expect(a.hintLevel, 0);
    expect(a.rating, fsrsRatingFor(a.grade));
  }
}

/// The verb the conjugation card shows now: the one whose dictionary form is on screen.
Map<String, dynamic> shownVerb(Map<String, dynamic> doc) {
  final verbs = (doc['conjugation']['verbs'] as List)
      .cast<Map<String, dynamic>>()
      .where((v) => find.text(v['dictionary'] as String).evaluate().isNotEmpty)
      .toList();
  expect(verbs, hasLength(1));
  return verbs.single;
}

/// The fill of the cell box that holds [label].
Color? _cellFill(WidgetTester tester, String label) {
  final box = tester.widget<AnimatedContainer>(find.ancestor(
      of: find.text(label), matching: find.byType(AnimatedContainer)));
  return (box.decoration as BoxDecoration?)?.color;
}

void main() {
  testWidgets('counter colors stay hidden until a cell is tapped',
      (tester) async {
    final doc = readLessonFile();
    final table = (doc['reference'] as List).first as Map<String, dynamic>;
    final col = (table['columns'] as List).first as Map<String, dynamic>;
    final cells = (table['cells'] as List)
        .cast<Map<String, dynamic>>()
        .where((c) => c['col'] == col['written'])
        .toList();
    // A cell whose legend color differs from a plain cell, so hiding it is visible.
    final marked = cells.firstWhere((c) => c['mark'] != 'regular');
    final label = '${marked['row']} ${col['written']}';

    await pumpStudyScreen(tester, const QuietRoomDrillsWidget());
    final t = QuietRoomTokens.of(tester.element(find.text(label)));
    final legend = ReadingMark.fill(t, marked['mark'] as String);
    expect(legend, isNot(t.surface));

    // Before a tap: every cell is plain surface and shows no reading.
    for (final c in cells) {
      expect(_cellFill(tester, '${c['row']} ${col['written']}'), t.surface,
          reason: 'cell ${c['row']} shows its color before a tap');
    }
    expect(find.text(marked['reading'] as String), findsNothing);
    expect(find.text('?'), findsNWidgets(cells.length));

    await tester.tap(find.text(label));
    await tester.pumpAndSettle();

    // After a tap: that cell alone shows its reading and its legend color.
    expect(_cellFill(tester, label), legend);
    expect(find.text(marked['reading'] as String), findsOneWidget);
    expect(find.text('?'), findsNWidgets(cells.length - 1));
    final other = cells.firstWhere((c) => c != marked);
    expect(_cellFill(tester, '${other['row']} ${col['written']}'), t.surface);
  });

  testWidgets('Show all reveals every cell color at once', (tester) async {
    final doc = readLessonFile();
    final table = (doc['reference'] as List).first as Map<String, dynamic>;
    // The 個 column mixes sound_change and regular cells, so the fill per mark is
    // visible. The first column, つ, is all special, which would let one fill pass.
    final col = (table['columns'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((c) => c['written'] == '個');
    final cells = (table['cells'] as List)
        .cast<Map<String, dynamic>>()
        .where((c) => c['col'] == col['written'])
        .toList();
    final marks = {
      for (final c in cells) c['row'] as String: c['mark'] as String
    };
    expect(marks['1'], 'sound_change');
    expect(marks['2'], 'regular');

    await pumpStudyScreen(tester, const QuietRoomDrillsWidget());
    await tester.tap(find.text(col['written'] as String));
    await tester.pumpAndSettle();
    final t = QuietRoomTokens.of(
        tester.element(find.text('${cells.first['row']} ${col['written']}')));

    await tester.tap(find.text('Show all'));
    await tester.pumpAndSettle();

    expect(_cellFill(tester, '1 ${col['written']}'),
        ReadingMark.fill(t, 'sound_change'));
    expect(_cellFill(tester, '2 ${col['written']}'), t.surface);
    for (final c in cells) {
      expect(_cellFill(tester, '${c['row']} ${col['written']}'),
          ReadingMark.fill(t, c['mark'] as String));
    }
    expect(find.text('?'), findsNothing);
  });

  group('the drills write attempts (Task 11)', () {
    testWidgets(
        'conjugation: Got it is clear and Missed it is wrong, against '
        'conj.<form>.g<group> with the verb as the probe', (tester) async {
      final doc = readLessonFile();
      final rig = DrillRig();
      await rig.open(tester, 'conjugation');

      final first = shownVerb(doc);
      await tester.tap(find.text('Say it, then tap'));
      await tester.pump();
      expect(await rig.attempts(tester), isEmpty,
          reason: 'the reveal alone is not an answer');
      await tester.tap(find.text('Got it'));
      await tester.pump();

      final second = shownVerb(doc);
      await tester.tap(find.text('Say it, then tap'));
      await tester.pump();
      await tester.tap(find.text('Missed it'));
      await tester.pump();

      final written = await rig.attempts(tester);
      expect(written.map((a) => a.itemId), [
        'conj.te.g${first['group']}',
        'conj.te.g${second['group']}',
      ]);
      expect(written.map((a) => a.probeId),
          [first['dictionary'], second['dictionary']]);
      expect(written.map((a) => a.grade), [Grade.clear, Grade.wrong]);
      expect(written.map((a) => a.template), everyElement('conjugate'));
      expect(written.map((a) => a.production), everyElement(isTrue));
      expectInCatalog(written);
    });

    testWidgets('conjugation follows the chosen form', (tester) async {
      final doc = readLessonFile();
      final rig = DrillRig();
      await rig.open(tester, 'conjugation');
      await tester.tap(find.text('ない form'));
      await tester.pump();
      final v = shownVerb(doc);
      await tester.tap(find.text('Say it, then tap'));
      await tester.pump();
      await tester.tap(find.text('Got it'));
      await tester.pump();

      final written = await rig.attempts(tester);
      expect(written.single.itemId, 'conj.nai.g${v['group']}');
      expect(written.single.probeId, v['dictionary']);
      expectInCatalog(written);
    });

    testWidgets(
        'an answer on a due item is a review, and one on an item not yet due is '
        'early practice (PIN-14)', (tester) async {
      final doc = readLessonFile();
      final rig = DrillRig();
      await rig.open(tester, 'conjugation');
      final v = shownVerb(doc);
      final id = 'conj.te.g${v['group']}';
      // The item is seeded due today, so this answer is a review.
      await rig.store.appendSeed(id, localDay(DateTime.now()),
          atUtc: DateTime.now().toUtc());
      await tester.tap(find.text('Say it, then tap'));
      await tester.pump();
      await tester.tap(find.text('Got it'));
      await tester.pump();

      final written = await rig.attempts(tester);
      expect(written.single.wasDue, isTrue);
      expect(written.single.source, Source.review);
      expect(await rig.store.srs(id), isNotNull);

      // A clean store: the same answer is early practice and leaves no schedule.
      final fresh = DrillRig();
      await fresh.open(tester, 'conjugation');
      final w = shownVerb(doc);
      await tester.tap(find.text('Say it, then tap'));
      await tester.pump();
      await tester.tap(find.text('Got it'));
      await tester.pump();
      final early = await fresh.attempts(tester);
      expect(early.single.wasDue, isFalse);
      expect(early.single.source, Source.early);
      expect(await fresh.store.srs('conj.te.g${w['group']}'), isNull);
    });

    testWidgets(
        'pairs: one attempt per reveal and self-mark, the direction as the '
        'template', (tester) async {
      final doc = readLessonFile();
      final ids = pairItemIds(doc);
      final rig = DrillRig();
      await rig.open(tester, 'pairs');

      // Shown the intransitive verb, recall the transitive one.
      expect(find.text('Got it'), findsNothing);
      await tester.tap(find.text('を ?').first);
      await tester.pump();
      expect(await rig.attempts(tester), isEmpty,
          reason: 'the reveal alone is not an answer');
      await tester.tap(find.text('Got it'));
      await tester.pump();
      // One mark per reveal.
      expect(find.text('Got it'), findsNothing);
      expect(find.text('Marked as got it.'), findsOneWidget);

      // The other direction: shown the transitive verb, recall the intransitive one.
      await tester.tap(find.text('を → が'));
      await tester.pump();
      expect(find.text('Marked as got it.'), findsNothing);
      await tester.tap(find.text('が ?').at(1));
      await tester.pump();
      await tester.tap(find.text('Missed it'));
      await tester.pump();

      final written = await rig.attempts(tester);
      expect(written.map((a) => a.itemId), [ids[0], ids[1]]);
      expect(written.map((a) => a.probeId), ['transitive', 'intransitive']);
      expect(written.map((a) => a.template), ['transitive', 'intransitive']);
      expect(written.map((a) => a.grade), [Grade.clear, Grade.wrong]);
      expectInCatalog(written);
    });

    testWidgets(
        'tables: one attempt per revealed and marked cell, against the row with '
        'the column as the probe', (tester) async {
      final doc = readLessonFile();
      final table = (doc['reference'] as List).first as Map<String, dynamic>;
      final col = (table['columns'] as List).first as Map<String, dynamic>;
      final cells = (table['cells'] as List)
          .cast<Map<String, dynamic>>()
          .where((c) => c['col'] == col['written'])
          .toList();
      final rig = DrillRig();
      await rig.open(tester, 'reference');

      // Show all is a lookup, not an answer.
      await tester.tap(find.text('Show all'));
      await tester.pump();
      expect(find.text('Got it'), findsNothing);
      await tester.tap(find.text('Hide all'));
      await tester.pump();
      expect(await rig.attempts(tester), isEmpty);

      await tester.tap(find.text('${cells[0]['row']} ${col['written']}'));
      await tester.pump();
      expect(await rig.attempts(tester), isEmpty,
          reason: 'the reveal alone is not an answer');
      await tester.tap(find.text('Got it'));
      await tester.pump();
      expect(find.text('Got it'), findsNothing);

      await tester.tap(find.text('${cells[1]['row']} ${col['written']}'));
      await tester.pump();
      await tester.tap(find.text('Missed it'));
      await tester.pump();

      final written = await rig.attempts(tester);
      expect(written.map((a) => a.itemId), [
        'ref.${table['id']}.${cells[0]['row']}',
        'ref.${table['id']}.${cells[1]['row']}',
      ]);
      expect(written.map((a) => a.probeId), everyElement(col['written']));
      expect(written.map((a) => a.template), everyElement('cell'));
      expect(written.map((a) => a.grade), [Grade.clear, Grade.wrong]);
      expectInCatalog(written);
    });

    testWidgets(
        'a pair hidden before its mark writes nothing, and its next reveal asks '
        'for a new mark', (tester) async {
      final ids = pairItemIds(readLessonFile());
      final rig = DrillRig();
      await rig.open(tester, 'pairs');
      await tester.tap(find.text('を ?').first);
      await tester.pump();
      expect(find.text('Got it'), findsOneWidget);
      // Tap the card again, away from its buttons: hidden, no mark asked, nothing written.
      final card = find.ancestor(
          of: find.text('Missed it'), matching: find.byType(QrCard));
      await tester.tapAt(tester.getTopLeft(card) + const Offset(4, 4));
      await tester.pump();
      expect(find.text('Got it'), findsNothing);
      expect(await rig.attempts(tester), isEmpty);

      await tester.tap(find.text('を ?').first);
      await tester.pump();
      await tester.tap(find.text('Missed it'));
      await tester.pump();
      final written = await rig.attempts(tester);
      expect(written.map((a) => a.itemId), [ids[0]]);
      expect(written.single.grade, Grade.wrong);
      expect(find.text('Marked as missed.'), findsOneWidget);
    });

    testWidgets('a cell hidden again before its mark writes nothing',
        (tester) async {
      final doc = readLessonFile();
      final table = (doc['reference'] as List).first as Map<String, dynamic>;
      final col = (table['columns'] as List).first as Map<String, dynamic>;
      final cell = (table['cells'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((c) => c['col'] == col['written']);
      final label = '${cell['row']} ${col['written']}';
      final rig = DrillRig();
      await rig.open(tester, 'reference');
      await tester.tap(find.text(label));
      await tester.pump();
      expect(find.text('Got it'), findsOneWidget);
      await tester.tap(find.text(label));
      await tester.pump();
      expect(find.text('Got it'), findsNothing);
      expect(await rig.attempts(tester), isEmpty);
    });
  });

  // S4: a write that fails is never silent. The failure reaches the app's error handler
  // with the item it was for, the learner is told, and the drill still moves on, so a
  // learner never sees a mark they believe was credited while nothing was written.
  group('a lost write (S4)', () {
    /// The one report on [itemId]: its exception is the store's, and its context names
    /// the item.
    void expectReported(List<FlutterErrorDetails> reports, String itemId) {
      expect(reports, hasLength(1));
      expect(reports.single.exception, isA<StateError>());
      expect(reports.single.context.toString(), contains(itemId));
      expect(reports.single.library, 'quiet room drills');
    }

    testWidgets(
        'conjugation: the failed write is reported with its item id, the learner '
        'is told, and the next card still comes', (tester) async {
      final capture = ReportCapture();
      final doc = readLessonFile();
      final store = ThrowingJpStore();
      final rig = DrillRig(store: store);
      await rig.open(tester, 'conjugation');
      final v = shownVerb(doc);
      await tester.tap(find.text('Say it, then tap'));
      await tester.pump();
      await tester.tap(find.text('Got it'));
      await tester.pump();
      final written = await rig.attempts(tester);
      final reports = capture.stop();

      expect(written, isEmpty);
      expect(store.refused, ['conj.te.g${v['group']}']);
      expectReported(reports, 'conj.te.g${v['group']}');
      await tester.pump();
      expect(find.text(kAnswerNotSaved), findsOneWidget);
      // The drill moved on: the next verb is up and asks for its own reveal.
      expect(find.text(v['dictionary'] as String), findsNothing);
      expect(find.text('Say it, then tap'), findsOneWidget);
    });

    testWidgets(
        'pairs: the failed write is reported with its item id, the learner is '
        'told, and the card shows its mark', (tester) async {
      final capture = ReportCapture();
      final ids = pairItemIds(readLessonFile());
      final store = ThrowingJpStore();
      final rig = DrillRig(store: store);
      await rig.open(tester, 'pairs');
      await tester.tap(find.text('を ?').first);
      await tester.pump();
      await tester.tap(find.text('Missed it'));
      await tester.pump();
      final written = await rig.attempts(tester);
      final reports = capture.stop();

      expect(written, isEmpty);
      expect(store.refused, [ids[0]]);
      expectReported(reports, ids[0]);
      await tester.pump();
      expect(find.text(kAnswerNotSaved), findsOneWidget);
      expect(find.text('Marked as missed.'), findsOneWidget);
    });

    testWidgets(
        'tables: the failed write is reported with its item id, the learner is '
        'told, and the cell shows its mark', (tester) async {
      final capture = ReportCapture();
      final doc = readLessonFile();
      final table = (doc['reference'] as List).first as Map<String, dynamic>;
      final col = (table['columns'] as List).first as Map<String, dynamic>;
      final cell = (table['cells'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((c) => c['col'] == col['written']);
      final id = 'ref.${table['id']}.${cell['row']}';
      final store = ThrowingJpStore();
      final rig = DrillRig(store: store);
      await rig.open(tester, 'reference');
      await tester.tap(find.text('${cell['row']} ${col['written']}'));
      await tester.pump();
      await tester.tap(find.text('Got it'));
      await tester.pump();
      final written = await rig.attempts(tester);
      final reports = capture.stop();

      expect(written, isEmpty);
      expect(store.refused, [id]);
      expectReported(reports, id);
      await tester.pump();
      expect(find.text(kAnswerNotSaved), findsOneWidget);
      expect(find.text('Marked as got it.'), findsOneWidget);
    });

    testWidgets('a write that lands is not reported and shows no notice',
        (tester) async {
      final capture = ReportCapture();
      final rig = DrillRig();
      await rig.open(tester, 'pairs');
      await tester.tap(find.text('を ?').first);
      await tester.pump();
      await tester.tap(find.text('Got it'));
      await tester.pump();
      final written = await rig.attempts(tester);
      await tester.pump();
      final reports = capture.stop();

      expect(written, hasLength(1));
      expect(reports, isEmpty);
      expect(find.text(kAnswerNotSaved), findsNothing);
    });
  });

  group('opened at an idea from a card (plan 2026-11-06, Task 1)', () {
    /// Wide enough for the reference legend row, which overflows a 420 view (seen while
    /// writing these tests; not this task's change), and short enough that a row far down a
    /// table is out of view.
    const tableView = Size(800, 900);

    Future<void> open(WidgetTester tester, QuietRoomDrillsWidget screen,
        {Size size = kPhoneView}) async {
      await pumpStudyScreen(tester, screen, size: size);
      await tester.pump();
    }

    testWidgets('a verb pair opens at its row, outlined and in view',
        (tester) async {
      final rig = DrillRig();
      final ids = pairItemIds(readLessonFile());
      await open(
          tester,
          QuietRoomDrillsWidget(
              mode: 'pairs', pair: ids.last, recorder: rig.recorder));

      final target = find.byKey(const ValueKey('pair-target'));
      expect(target, findsOneWidget);
      expect(inView(tester, target), isTrue,
          reason: 'the last pair is scrolled into the view');
      // Opened at, not answered: nothing is revealed and nothing is written.
      expect(find.text('Got it'), findsNothing);
      expect(await rig.attempts(tester), isEmpty);
    });

    testWidgets('the plain pairs entry starts at the top with no outline',
        (tester) async {
      final last = (readLessonFile()['pairs'] as List).last as Map;
      await open(tester,
          QuietRoomDrillsWidget(mode: 'pairs', recorder: DrillRig().recorder));

      expect(find.byKey(const ValueKey('pair-target')), findsNothing);
      final verb = find.text(last['intransitive'] as String);
      expect(verb.evaluate().isEmpty || !inView(tester, verb.first), isTrue);
      expect(find.text(kBackToPractice), findsNothing);
    });

    /// A table cell drawn with the target outline: an AnimatedContainer whose border is 2
    /// wide. Every other cell's border is 1 wide.
    final outlined = find.byWidgetPredicate(
        (w) =>
            w is AnimatedContainer &&
            ((w.decoration as BoxDecoration?)?.border as Border?)?.top.width ==
                2,
        skipOffstage: false);

    testWidgets('a table row opens at its table and row, outlined and in view',
        (tester) async {
      final rig = DrillRig();
      await open(
          tester,
          QuietRoomDrillsWidget(
              mode: 'reference',
              table: 'dates',
              row: '31',
              recorder: rig.recorder),
          size: tableView);

      expect(find.text('31日'), findsOneWidget);
      expect(inView(tester, find.text('31日')), isTrue,
          reason: 'the row is scrolled into the view');
      expect(find.ancestor(of: find.text('31日'), matching: outlined),
          findsOneWidget,
          reason: 'the row\'s cell is outlined');
      expect(find.text('Missed it'), findsNothing);
      expect(await rig.attempts(tester), isEmpty);
    });

    testWidgets('the plain table entry starts at the top with no outline',
        (tester) async {
      await open(
          tester,
          QuietRoomDrillsWidget(
              mode: 'reference', table: 'dates', recorder: DrillRig().recorder),
          size: tableView);
      final cell = find.text('31日');
      expect(cell.evaluate().isEmpty || !inView(tester, cell), isTrue);
      expect(outlined, findsNothing, reason: 'no cell is outlined');
    });

    testWidgets('a conjugation opens at its form with Back to practice',
        (tester) async {
      await open(
          tester,
          QuietRoomDrillsWidget(
              mode: 'conjugation',
              form: 'nai',
              fromCard: true,
              recorder: DrillRig().recorder),
          size: const Size(1200, 12000));
      final pill =
          tester.widget<QrPill>(find.widgetWithText(QrPill, 'ない form'));
      expect(pill.on, isTrue);
      expect(find.text(kBackToPractice), findsOneWidget);
    });

    testWidgets('Back to practice returns to the card', (tester) async {
      await pumpStudyScreen(
          tester,
          Builder(
              builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => QuietRoomDrillsWidget(
                                    mode: 'pairs',
                                    pair: pairItemIds(readLessonFile()).first,
                                    fromCard: true,
                                    recorder: DrillRig().recorder))),
                        child: const Text('the card')),
                  )));
      await tester.tap(find.text('the card'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text(kBackToPractice));
      await tester.pumpAndSettle();
      expect(find.byType(QuietRoomDrillsWidget), findsNothing);
      expect(find.text('the card'), findsOneWidget);
    });

    /// The text [label] wherever the list is scrolled to: an open at a row scrolls the
    /// pills above it out of the view, and a column change keeps that scroll.
    Finder anyText(String label) => find.text(label, skipOffstage: false);

    /// Taps the pill labeled [label], scrolled into the view first.
    Future<void> tapPill(WidgetTester tester, String label) async {
      final pill = find.widgetWithText(QrPill, label, skipOffstage: false);
      await tester.ensureVisible(pill);
      await tester.pumpAndSettle();
      await tester.tap(pill);
      await tester.pumpAndSettle();
    }

    // Row '1' is a row of every table, so a guard that is missing shows as an outline
    // on the table that opened instead. Row '31' is a row of dates alone and would pass
    // these tests with the guard gone.
    testWidgets(
        'a row with no table, or with a table not in the doc, outlines nothing',
        (tester) async {
      await open(
          tester,
          QuietRoomDrillsWidget(
              mode: 'reference', row: '1', recorder: DrillRig().recorder),
          size: tableView);
      expect(find.text('1 つ'), findsOneWidget,
          reason: 'the first table opened');
      expect(outlined, findsNothing,
          reason: 'a row with no table is not an open');

      await open(
          tester,
          QuietRoomDrillsWidget(
              mode: 'reference',
              table: 'nope',
              row: '1',
              recorder: DrillRig().recorder),
          size: tableView);
      expect(find.text('1 つ'), findsOneWidget,
          reason: 'the first table opened');
      expect(outlined, findsNothing,
          reason: 'a row of a table not in the doc is not an open');
    });

    testWidgets('the same table keeps the outline and a new table drops it',
        (tester) async {
      await open(
          tester,
          QuietRoomDrillsWidget(
              mode: 'reference',
              table: 'dates',
              row: '1',
              recorder: DrillRig().recorder),
          size: tableView);
      expect(
          find.ancestor(of: anyText('1日'), matching: outlined), findsOneWidget);

      await tapPill(tester, 'Dates');
      expect(
          find.ancestor(of: anyText('1日'), matching: outlined), findsOneWidget,
          reason: 'the table that is open again keeps the row');

      await tapPill(tester, 'Months');
      expect(anyText('1 月'), findsOneWidget, reason: 'months is open');
      expect(outlined, findsNothing,
          reason: 'row 1 of months is not the row that was opened');
    });

    testWidgets('the outline follows the row across the columns of its table',
        (tester) async {
      await open(
          tester,
          QuietRoomDrillsWidget(
              mode: 'reference',
              table: 'months',
              row: '1',
              recorder: DrillRig().recorder),
          size: tableView);
      expect(find.ancestor(of: anyText('1 月'), matching: outlined),
          findsOneWidget);

      await tapPill(tester, '〜か月');
      expect(anyText('1 月'), findsNothing, reason: 'the column changed');
      expect(find.ancestor(of: anyText('1 か月'), matching: outlined),
          findsOneWidget,
          reason: 'the row stays outlined in the new column');
      expect(outlined, findsOneWidget, reason: 'one cell is outlined');
    });

    testWidgets('a pair not in the doc outlines nothing', (tester) async {
      await open(
          tester,
          QuietRoomDrillsWidget(
              mode: 'pairs', pair: 'nope', recorder: DrillRig().recorder));
      expect(find.byKey(const ValueKey('pair-target')), findsNothing);
      expect(find.text('Verb pairs'), findsOneWidget,
          reason: 'the drill opened');
    });
  });
}
