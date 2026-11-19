// The pairs drill on an asset whose pairs and verb_pair catalog rows do not line up (S4).
//
// pipeline/jp refuses such an asset before it ships, and the item catalog refuses it at
// load. The drill is the last guard: with no ids to write under, a mark must never read as
// credited. It reports the StateError once, through FlutterError.reportError, tells the
// learner on each mark, and writes nothing.
//
// Its own file: JpGrammarData caches the first load in a static, so the altered asset has
// to be served before any other screen test loads the shipped one in this isolate. The
// asset channel mock stays installed for the file, which holds this one test.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:habit_craft/components/pages/quiet_room_grammar/quiet_room_drills_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/drill_recorder.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/item_catalog.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_memory.dart';

import 'jp_screen_harness.dart';

const _grammarKey = 'assets/lessons/jp_grammar.json';

/// The shipped grammar file with one verb_pair catalog row removed, so the pairs and the
/// rows no longer line up.
Map<String, dynamic> _mismatchedGrammar() {
  final doc = readLessonFile();
  final catalog = (doc['catalog'] as List).cast<Map<String, dynamic>>();
  final last = catalog.lastWhere((c) => c['type'] == 'verb_pair');
  catalog.remove(last);
  return doc;
}

/// Serves [grammar] for the grammar asset and every other asset from the test asset
/// folder, the way flutter_test's own asset mock does (`_binding_io.dart`).
void _serveGrammar(Map<String, dynamic> grammar) {
  final encoded = utf8.encode(json.encode(grammar));
  final folder = Platform.environment['UNIT_TEST_ASSETS'];
  final prefix = 'packages/${Platform.environment['APP_NAME']}/';
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (ByteData? message) async {
    final key = utf8.decode(message!.buffer.asUint8List());
    if (key == _grammarKey) {
      return Uint8List.fromList(encoded).buffer.asByteData();
    }
    if (folder == null) return null;
    var file = File('$folder/$key');
    if (!file.existsSync() && key.startsWith(prefix)) {
      file = File('$folder/${key.substring(prefix.length)}');
    }
    if (!file.existsSync()) return null;
    return Uint8List.fromList(file.readAsBytesSync()).buffer.asByteData();
  });
}

void main() {
  testWidgets(
      'pairs on a mismatched asset: the mismatch is reported once, each mark '
      'tells the learner, the card shows its mark, and nothing is written',
      (tester) async {
    final grammar = _mismatchedGrammar();
    // The premise: the shipped asset lines up and the altered one does not.
    expect(() => pairItemIds(readLessonFile()), returnsNormally);
    expect(() => pairItemIds(grammar), throwsStateError);
    _serveGrammar(grammar);

    final capture = ReportCapture();
    final store = JpStoreMemory();
    final recorder = AttemptRecorder.on(store);
    await pumpStudyScreen(
        tester, QuietRoomDrillsWidget(mode: 'pairs', recorder: recorder));
    final pairs = (grammar['pairs'] as List).length;
    expect(find.text('を ?'), findsNWidgets(pairs),
        reason: 'the drill opened on the altered asset');

    await tester.tap(find.text('を ?').first);
    await tester.pump();
    await tester.tap(find.text('Got it'));
    await tester.pump();
    final reports = capture.stop();

    expect(reports, hasLength(1));
    expect(reports.single.exception, isA<StateError>());
    expect(reports.single.library, 'quiet room drills');
    expect(reports.single.context.toString(),
        'while mapping the verb pairs to items');
    await tester.pump();
    expect(find.text(kAnswerNotSaved), findsOneWidget);
    expect(find.text('Marked as got it.'), findsOneWidget);
    await recorder.idle;
    expect(await store.attempts(), isEmpty);

    // A second mark: the learner is told again, and the mismatch is not reported twice.
    final again = ReportCapture();
    await tester.tap(find.text('を ?').first);
    await tester.pump();
    await tester.tap(find.text('Missed it'));
    await tester.pump();
    expect(again.stop(), isEmpty);
    expect(find.text('Marked as missed.'), findsOneWidget);
    await recorder.idle;
    expect(await store.attempts(), isEmpty);
  });
}
