// Shared set-up for the Japanese study screen tests. Not a test file itself (no
// `_test` suffix), so `flutter test` only runs it through the files that import it.
//
// Every screen reads the real assets/lessons/jp_grammar.json through JpGrammarData,
// so the tests check the shipped data, not a fixture that can drift from it.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:habit_craft/components/pages/quiet_room_grammar/jp_study_kit.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/attempt.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_memory.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_sqlite.dart'
    show debugSetSharedJpStore;
import 'package:habit_craft/components/pages/quiet_room_mastery/mastery_rule.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/scheduler.dart';

/// The app lesson file, read straight from disk to derive what each test expects.
Map<String, dynamic> readLessonFile() =>
    json.decode(File('assets/lessons/jp_grammar.json').readAsStringSync())
        as Map<String, dynamic>;

/// Pumps [screen] in a bare MaterialApp, by default tall enough that a lesson's cards are built.
///
/// The asset load runs under `runAsync`: a large `loadString` decodes on another
/// isolate, which the test's fake clock never advances. That cached future belongs to
/// the real zone, so the screen's FutureBuilder hears it complete only after a real
/// event-loop turn. Hence the second `runAsync` before the final pumps.
///
/// A screen that writes answers and has no store of its own uses the shared one, which
/// on the phone is SQLite. A test cannot open that, so each pump shares a fresh memory
/// store instead.
///
/// [prefs] seeds `SharedPreferences` before the screen builds. [size] is the view: tall by
/// default, a phone for the tests that a screen scrolls to an idea.
Future<void> pumpStudyScreen(WidgetTester tester, Widget screen,
    {Map<String, Object> prefs = const {},
    Size size = const Size(1200, 12000)}) async {
  SharedPreferences.setMockInitialValues(prefs);
  debugSetSharedJpStore(JpStoreMemory());
  addTearDown(() => debugSetSharedJpStore(null));
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.runAsync(JpGrammarData.load);
  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump();
  await tester.pump();
}

/// Holds every HTTP request of this test file open forever, so a Google Fonts fetch never
/// fails inside a test. The test binding answers every request with a 400, and google_fonts
/// rethrows that as an uncaught error into whichever test is running when a `runAsync` lets
/// the answer arrive. Held open, the font stays on its fallback and nothing is thrown.
///
/// Call it from `setUpAll`, before the first screen builds: google_fonts makes its one
/// client on its first fetch, and that client keeps the overrides current at that time.
void holdHttpRequests() => HttpOverrides.global = _HeldHttpOverrides();

class _HeldHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _HeldHttpClient();
}

class _HeldHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) =>
      Completer<HttpClientRequest>().future;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// A memory store whose attempt write throws on every call until [failures] runs out: the
/// seam for the lost-write tests (S4). Every read still answers, so the recorder reaches the
/// write itself before it fails.
class ThrowingJpStore extends JpStoreMemory {
  ThrowingJpStore({this.failures = -1});

  /// Writes left to fail; a negative count fails every write.
  int failures;

  /// The ids whose write was refused, in order.
  final List<String> refused = [];

  @override
  Future<Attempt> appendAttempt(Attempt attempt,
      {SrsState? srs, MasteryState? mastery}) {
    if (failures != 0) {
      if (failures > 0) failures--;
      refused.add(attempt.itemId);
      throw StateError('jp store: disk full');
    }
    return super.appendAttempt(attempt, srs: srs, mastery: mastery);
  }
}

/// Routes [FlutterError.onError] to [reports] until [stop], so a reported failure is read
/// by the test instead of failing it.
///
/// Call [stop] right after the action under test and before the first `expect`: an expect
/// that fails while the handler is overridden trips the test binding's own check
/// (`_pendingExceptionDetails != null`) and the runner stalls instead of reporting.
/// Tear-down restores the handler for a test that never reaches [stop].
class ReportCapture {
  ReportCapture() : _prior = FlutterError.onError {
    FlutterError.onError = reports.add;
    addTearDown(stop);
  }

  final List<FlutterErrorDetails> reports = [];
  final FlutterExceptionHandler? _prior;
  bool _stopped = false;

  /// Puts the handler back and returns what was reported while it was overridden.
  List<FlutterErrorDetails> stop() {
    if (!_stopped) {
      _stopped = true;
      FlutterError.onError = _prior;
    }
    return reports;
  }
}

/// A phone-sized view: an idea far down a screen is out of it unless the screen scrolls there.
const Size kPhoneView = Size(420, 900);

/// Whether [finder]'s widget lies inside the view, top to bottom.
bool inView(WidgetTester tester, Finder finder) {
  final r = tester.getRect(finder);
  final h = tester.view.physicalSize.height / tester.view.devicePixelRatio;
  return r.top >= 0 && r.bottom <= h;
}
