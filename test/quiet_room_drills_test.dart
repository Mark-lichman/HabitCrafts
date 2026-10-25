// Widget tests for the drills screen: a counter cell keeps its legend color hidden
// until it is tapped, because the color gives away whether the reading is regular.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:habit_craft/components/pages/quiet_room_grammar/jp_study_kit.dart';
import 'package:habit_craft/components/pages/quiet_room_grammar/quiet_room_drills_widget.dart';
import 'package:habit_craft/flutter_flow/quiet_room.dart';

import 'jp_screen_harness.dart';

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
    final marks = {for (final c in cells) c['row'] as String: c['mark'] as String};
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
}
