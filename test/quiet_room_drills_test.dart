// Widget tests for the drills screen: a counter cell keeps its legend color hidden
// until it is tapped, because the color gives away whether the reading is regular.
//
// Plan 2026-11-02, Task 11: every self-graded answer on the three drills writes one attempt
// through an injected recorder. Got it is clear and Missed it is wrong (PIN-13). The tests
// assert the item and probe ids on the written attempts, and that each resolves in the item
// catalog, so a drill and the catalog never name one probe two ways.

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
  final store = JpStoreMemory();
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
}
