// Shared set-up for the Japanese study screen tests. Not a test file itself (no
// `_test` suffix), so `flutter test` only runs it through the files that import it.
//
// Every screen reads the real assets/lessons/jp_grammar.json through JpGrammarData,
// so the tests check the shipped data, not a fixture that can drift from it.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:habit_craft/components/pages/quiet_room_grammar/jp_study_kit.dart';

/// The app lesson file, read straight from disk to derive what each test expects.
Map<String, dynamic> readLessonFile() =>
    json.decode(File('assets/lessons/jp_grammar.json').readAsStringSync())
        as Map<String, dynamic>;

/// Pumps [screen] in a bare MaterialApp, tall enough that a lesson's cards are built.
///
/// The asset load runs under `runAsync`: a large `loadString` decodes on another
/// isolate, which the test's fake clock never advances. That cached future belongs to
/// the real zone, so the screen's FutureBuilder hears it complete only after a real
/// event-loop turn. Hence the second `runAsync` before the final pumps.
Future<void> pumpStudyScreen(WidgetTester tester, Widget screen) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(1200, 12000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.runAsync(JpGrammarData.load);
  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump();
  await tester.pump();
}
