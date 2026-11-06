// Unit tests for AttemptRecorder's failure path (S4, Task 11). A write that fails is
// reported through FlutterError with the item it was for, record resolves null, and the
// queue after it still runs: one bad write never stalls the drill's later answers.

import 'package:flutter_test/flutter_test.dart';

import 'package:habit_craft/components/pages/quiet_room_mastery/attempt.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/drill_recorder.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_memory.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_sqlite.dart'
    show debugSetSharedJpStore;

import 'jp_screen_harness.dart';

DrillAnswer _answer(String itemId) => DrillAnswer(
    itemId: itemId,
    probeId: 'p',
    template: 'cell',
    grade: Grade.clear,
    revealed: true);

void main() {
  test('a failed write is reported with its item id and resolves null',
      () async {
    final capture = ReportCapture();
    final store = ThrowingJpStore();
    final recorder = AttemptRecorder.on(store);
    final written = await recorder.record(_answer('ref.x.a'));
    final reports = capture.stop();

    expect(written, isNull);
    expect(reports, hasLength(1));
    expect(reports.single.exception, isA<StateError>());
    expect(reports.single.stack, isNotNull);
    expect(reports.single.library, 'quiet room drills');
    expect(reports.single.context.toString(),
        'while logging the attempt on ref.x.a');
    expect(await store.attempts(), isEmpty);
  });

  test('the queue runs on after a failed write', () async {
    final capture = ReportCapture();
    final store = ThrowingJpStore(failures: 1);
    final recorder = AttemptRecorder.on(store);
    final first = recorder.record(_answer('ref.x.a'));
    final second = recorder.record(_answer('ref.x.b'));
    final firstWritten = await first;
    final secondWritten = await second;
    await recorder.idle;
    final reports = capture.stop();

    expect(firstWritten, isNull);
    expect(secondWritten?.itemId, 'ref.x.b');
    expect((await store.attempts()).map((a) => a.itemId), ['ref.x.b']);
    expect(reports.map((r) => r.context.toString()),
        ['while logging the attempt on ref.x.a']);
  });

  test('a store that cannot open is reported, and the write resolves null',
      () async {
    final capture = ReportCapture();
    final recorder = AttemptRecorder(
        store: () async => throw StateError('jp store: no file'),
        items: () async => (_) => null);
    final written = await recorder.record(_answer('ref.x.a'));
    final reports = capture.stop();

    expect(written, isNull);
    expect(reports.single.exception, isA<StateError>());
    expect(reports.single.context.toString(),
        'while logging the attempt on ref.x.a');
  });

  test('a write that lands is not reported', () async {
    final capture = ReportCapture();
    final recorder = AttemptRecorder.on(ThrowingJpStore(failures: 0));
    final written = await recorder.record(_answer('ref.x.a'));
    final reports = capture.stop();

    expect(written?.itemId, 'ref.x.a');
    expect(reports, isEmpty);
  });

  test(
      "a recorder with no store of its own writes to the app's one shared store",
      () async {
    final shared = JpStoreMemory();
    debugSetSharedJpStore(shared);
    addTearDown(() => debugSetSharedJpStore(null));
    final recorder = AttemptRecorder(items: () async => (_) => null);
    final written = await recorder.record(_answer('ref.x.a'));

    expect(written?.itemId, 'ref.x.a');
    expect((await shared.attempts()).map((a) => a.itemId), ['ref.x.a']);
  });

  // No SQLite plugin answers in a unit test, so the app's shared open fails here the way
  // it would on a phone with no usable database.
  // The test sees two reports, one per answer. It cannot tell a fresh open from a cached
  // failure, so the shared store's retry (sharedJpStore in jp_store_sqlite.dart) is not
  // claimed here.
  test('a failed shared open loses each answer with its own report', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    debugSetSharedJpStore(null);
    final capture = ReportCapture();
    final recorder = AttemptRecorder(items: () async => (_) => null);
    final first = await recorder.record(_answer('ref.x.a'));
    final second = await recorder.record(_answer('ref.x.b'));
    final reports = capture.stop();

    expect(first, isNull);
    expect(second, isNull);
    expect(reports.map((r) => r.context.toString()), [
      'while logging the attempt on ref.x.a',
      'while logging the attempt on ref.x.b',
    ]);
    expect(reports.map((r) => r.library), everyElement('quiet room drills'));
  });
}
