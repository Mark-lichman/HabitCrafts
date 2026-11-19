// The study record debug page (Task 13, A2): the summary it reads off the store, the page
// itself with its Rebuild from log, Export and Import actions, the quiet "Study record" link at
// the bottom of Today, the Japanese home, and the route the app registers for it.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_craft/components/pages/quiet_room_grammar/quiet_room_japanese_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/attempt.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/fsrs.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/item_catalog.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_memory.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_sqlite.dart'
    show debugSetSharedJpStore, sharedJpStore;
import 'package:habit_craft/components/pages/quiet_room_mastery/local_day.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/mastery_debug_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/mastery_rule.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/seed.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/session_widget.dart'
    show kReviewSessionPrefix;
import 'package:habit_craft/components/pages/quiet_room_mastery/study_export.dart';
import 'package:habit_craft/flutter_flow/nav/nav.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'jp_screen_harness.dart';

Map<String, dynamic> _read(String path) =>
    json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;

final catalog = ItemCatalog.fromDocs(_read('assets/lessons/jp_grammar.json'),
    _read('assets/lessons/jp_lessons.json'));
const scheduler = FsrsScheduler();

/// Local day 100, at noon local time.
const int today = 100;
DateTime noonOf(int day) => dateOfDay(day).add(const Duration(hours: 12));

ItemDef firstOf(ItemKind kind) => catalog.ofKind(kind).first;

/// An answer on [item]'s first scored probe on local [day], [minute] minutes past noon.
Attempt answer(ItemDef item, int day, Grade grade,
    {int minute = 0,
    int durationMs = 0,
    String session = 's1',
    Source source = Source.review}) {
  final p = item.scoredProbes.first;
  return Attempt(
    itemId: item.id,
    probeId: p.id,
    template: p.template,
    production: p.production,
    selfGraded: p.selfGraded,
    atUtc: noonOf(day).add(Duration(minutes: minute)).toUtc(),
    localDay: day,
    grade: grade,
    rating: fsrsRatingFor(grade),
    wasDue: true,
    source: source,
    durationMs: durationMs,
    sessionId: session,
  );
}

Future<void> record(JpStore store, Attempt a) =>
    store.recordAnswer(a, item: catalog.byId(a.itemId), scheduler: scheduler);

class FakeFiles implements StudyRecordFiles {
  FakeFiles({this.toOpen, this.saves = true});

  String? toOpen;

  /// False cancels the save dialog.
  final bool saves;
  String? savedName;
  String? savedText;

  @override
  Future<bool> save(String fileName, String text) async {
    if (!saves) return false;
    savedName = fileName;
    savedText = text;
    return true;
  }

  @override
  Future<String?> open() async => toOpen;
}

/// The device picker, answering pickFiles with [result]: null is a cancel, a file with no
/// bytes is one the platform could not read. saveFile answers [savePath], null for a cancel,
/// and records what it was handed.
class FakePicker extends FilePicker with MockPlatformInterfaceMixin {
  FakePicker(this.result, {this.savePath});

  final FilePickerResult? result;
  final String? savePath;
  String? savedFileName;
  Uint8List? savedBytes;

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    savedFileName = fileName;
    savedBytes = bytes;
    return savePath;
  }

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async =>
      result;
}

/// A store whose attempt read fails, for the page's load-error branch.
class BrokenStore extends JpStoreMemory {
  @override
  Future<List<Attempt>> attempts({String? itemId}) async =>
      throw StateError('the attempts table is unreadable');
}

/// A store whose seed read fails: the summary shows no seed count, so it must not read one.
class SeedlessStore extends JpStoreMemory {
  @override
  Future<List<SeedEvent>> seeds() async =>
      throw StateError('summarizeRecord read the seed rows');
}

/// A Shaky [item] with one regain clear per day of [days]; no due day, so its row shows only
/// the count.
MasteryState shakyWith(ItemDef item, List<int> days) {
  final p = item.scoredProbes.first;
  return MasteryState.initial(item.id).copyWith(
    status: MasteryStatus.shaky,
    clears: [
      for (final d in days)
        ClearRef(
            day: d,
            template: p.template,
            production: p.production,
            probeId: p.id),
    ],
  );
}

Future<void> pumpDebug(WidgetTester tester, JpStore store,
    {StudyRecordFiles? files}) async {
  tester.view.physicalSize = const Size(1200, 20000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: MasteryDebugWidget(
      store: store,
      catalog: catalog,
      clock: FixedClock(noonOf(today)),
      files: files ?? FakeFiles(),
    ),
  ));
  await settle(tester);
}

/// Lets the page's store reads finish: they are real futures, so they need real turns.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
}

void main() {
  setUpAll(holdHttpRequests);

  group('summarizeRecord', () {
    test('sorts every catalog item into its state with its next due day',
        () async {
      final store = JpStoreMemory();
      final word = firstOf(ItemKind.word);
      final particle = firstOf(ItemKind.particle);
      await record(store, answer(word, today - 1, Grade.clear));
      await store.appendSeed(particle.id, today + 3, atUtc: noonOf(today));

      final s = await summarizeRecord(store, catalog, today: today);

      final all = s.byStatus.values.expand((r) => r).toList();
      expect(all.length, catalog.items.length,
          reason: 'every catalog item is listed once');
      final learning = s.byStatus[MasteryStatus.learning]!;
      expect(learning.map((r) => r.item.id), [word.id]);
      expect(learning.single.clears, 1);
      expect(learning.single.dueDay, (await store.srs(word.id))!.dueDay);
      final seeded = s.byStatus[MasteryStatus.neu]!
          .firstWhere((r) => r.item.id == particle.id);
      expect(seeded.dueDay, today + 3,
          reason: 'a seeded item shows its seeded due day');
      expect(s.byStatus[MasteryStatus.neu]!.first.item.id, particle.id,
          reason: 'within a state, the soonest due comes first');
      expect(s.attemptCount, 1);
    });

    test('the next 14 days of load start today and count overdue apart',
        () async {
      final store = JpStoreMemory();
      final items = catalog.ofKind(ItemKind.word);
      await store.appendSeeds([
        SeedEvent(itemId: items[0].id, dueDay: today - 2, atUtc: noonOf(0)),
        SeedEvent(itemId: items[1].id, dueDay: today, atUtc: noonOf(0)),
        SeedEvent(itemId: items[2].id, dueDay: today, atUtc: noonOf(0)),
        SeedEvent(itemId: items[3].id, dueDay: today + 13, atUtc: noonOf(0)),
        SeedEvent(itemId: items[4].id, dueDay: today + 14, atUtc: noonOf(0)),
      ]);

      final s = await summarizeRecord(store, catalog, today: today);

      expect(s.load14.length, 14);
      expect(s.load14.first, 2);
      expect(s.load14.last, 1);
      expect(s.load14.reduce((a, b) => a + b), 3,
          reason: 'day 14 lies past the window');
      expect(s.overdue, 1);
    });

    test('a kind shows its median answer time only from 50 samples', () async {
      final store = JpStoreMemory();
      final word = firstOf(ItemKind.word);
      final grammar = firstOf(ItemKind.grammar);
      // 49 timed word answers, then the 50th; grammar stays at 49. An untimed answer and a
      // Say-it answer are not samples.
      for (var i = 0; i < 49; i++) {
        await store.appendAttempt(
            answer(word, 1, Grade.clear, minute: i, durationMs: 1000 + i));
        await store.appendAttempt(
            answer(grammar, 1, Grade.clear, minute: i, durationMs: 9000));
      }
      await store.appendAttempt(answer(word, 1, Grade.clear, minute: 60));
      await store.appendAttempt(answer(grammar, 1, Grade.clear,
          minute: 61, durationMs: 9000, source: Source.sayIt));

      var s = await summarizeRecord(store, catalog, today: today);
      expect(s.answerTimes[ItemKind.word]!.samples, 49);
      expect(s.answerTimes[ItemKind.word]!.medianMs, isNull);
      expect(s.answerTimes[ItemKind.grammar]!.medianMs, isNull);

      await store.appendAttempt(
          answer(word, 1, Grade.clear, minute: 62, durationMs: 1049));
      s = await summarizeRecord(store, catalog, today: today);
      expect(s.answerTimes[ItemKind.word]!.samples, kAnswerTimeMinSamples);
      // 1000..1049: the median of 50 is the mean of 1024 and 1025.
      expect(s.answerTimes[ItemKind.word]!.medianMs, 1024.5);
      expect(s.answerTimes[ItemKind.grammar]!.medianMs, isNull);
    });

    test('session length runs from the first answer start to the last answer',
        () async {
      final store = JpStoreMemory();
      final word = firstOf(ItemKind.word);
      // Three Review sessions: 10, 14 and 30 minutes; a migrated Say-it history is no session.
      await store.appendAttempt(answer(word, 1, Grade.clear,
          minute: 0, durationMs: 60000, session: '${kReviewSessionPrefix}a'));
      await store.appendAttempt(answer(word, 1, Grade.clear,
          minute: 9, durationMs: 5000, session: '${kReviewSessionPrefix}a'));
      await store.appendAttempt(answer(word, 2, Grade.clear,
          minute: 0, session: '${kReviewSessionPrefix}b'));
      await store.appendAttempt(answer(word, 2, Grade.clear,
          minute: 14, session: '${kReviewSessionPrefix}b'));
      await store.appendAttempt(answer(word, 30, Grade.clear,
          minute: 0, session: '${kReviewSessionPrefix}c'));
      await store.appendAttempt(answer(word, 30, Grade.clear,
          minute: 30, session: '${kReviewSessionPrefix}c'));
      await store.appendAttempt(answer(word, 3, Grade.clear,
          minute: 0, session: kV2MigrationSession, source: Source.sayIt));
      await store.appendAttempt(answer(word, 3, Grade.clear,
          minute: 300, session: kV2MigrationSession, source: Source.sayIt));

      final s = await summarizeRecord(store, catalog, today: today);

      expect(s.sessionCount, 3);
      expect(s.medianSessionMinutes, 14);
      expect(s.firstDaysSessionCount, 2,
          reason: 'session c starts 29 days after the first');
      expect(s.firstDaysMedianSessionMinutes, 12);
    });

    test(
        'session length counts only Review sessions: a practice or drill session leaves '
        'the median unchanged (ASK-10)', () async {
      final store = JpStoreMemory();
      final word = firstOf(ItemKind.word);
      // Two Review sessions of 10 and 14 minutes: the median is 12.
      await store.appendAttempt(answer(word, 1, Grade.clear,
          minute: 0, session: '${kReviewSessionPrefix}a'));
      await store.appendAttempt(answer(word, 1, Grade.clear,
          minute: 10, session: '${kReviewSessionPrefix}a'));
      await store.appendAttempt(answer(word, 2, Grade.clear,
          minute: 0, session: '${kReviewSessionPrefix}b'));
      await store.appendAttempt(answer(word, 2, Grade.clear,
          minute: 14, session: '${kReviewSessionPrefix}b'));
      final before = await summarizeRecord(store, catalog, today: today);
      expect(before.sessionCount, 2);
      expect(before.medianSessionMinutes, 12);

      // A long Practice now sitting and a drill sitting are no Review session.
      await store.appendAttempt(answer(word, 3, Grade.clear,
          minute: 0, session: 'practice-1', source: Source.early));
      await store.appendAttempt(answer(word, 3, Grade.clear,
          minute: 90, session: 'practice-1', source: Source.early));
      await store.appendAttempt(
          answer(word, 4, Grade.clear, minute: 0, session: 'drill-1'));
      await store.appendAttempt(
          answer(word, 4, Grade.clear, minute: 60, session: 'drill-1'));
      final after = await summarizeRecord(store, catalog, today: today);
      expect(after.sessionCount, 2);
      expect(after.medianSessionMinutes, 12);
      expect(after.firstDaysSessionCount, 2);
      expect(after.firstDaysMedianSessionMinutes, 12);
      expect(after.attemptCount, 8, reason: 'the answers are still counted');
    });

    test('an empty record has no medians', () async {
      final s = await summarizeRecord(JpStoreMemory(), catalog, today: today);
      expect(s.attemptCount, 0);
      expect(s.sessionCount, 0);
      expect(s.medianSessionMinutes, isNull);
      expect(s.byStatus[MasteryStatus.neu]!.length, catalog.items.length);
    });

    test('reads no seed rows, since the page shows no seed count', () async {
      final s = await summarizeRecord(SeedlessStore(), catalog, today: today);
      expect(s.attemptCount, 0);
    });
  });

  group('PickerStudyRecordFiles.open', () {
    const files = PickerStudyRecordFiles();

    test('a cancelled picker is null', () async {
      FilePicker.platform = FakePicker(null);
      expect(await files.open(), isNull);
    });

    test('a chosen file with no bytes throws, never a cancel', () async {
      FilePicker.platform = FakePicker(
          FilePickerResult([PlatformFile(name: 'record.jsonl', size: 0)]));
      await expectLater(files.open, throwsStateError);
    });

    test('a chosen file with bytes is its text', () async {
      final bytes = utf8.encode('{"a":1}');
      FilePicker.platform = FakePicker(FilePickerResult([
        PlatformFile(name: 'record.jsonl', size: bytes.length, bytes: bytes)
      ]));
      expect(await files.open(), '{"a":1}');
    });
  });

  // These run on the VM, so kIsWeb is false and the picker's answer decides. On web
  // saveFile always answers null after starting the download, so there save is always true.
  group('PickerStudyRecordFiles.save', () {
    const files = PickerStudyRecordFiles();

    test('a cancelled save dialog is false', () async {
      final picker = FakePicker(null);
      FilePicker.platform = picker;
      expect(await files.save('record.jsonl', '{"a":1}'), isFalse);
    });

    test('a chosen path is true and hands the picker the name and the text',
        () async {
      final picker = FakePicker(null, savePath: '/tmp/record.jsonl');
      FilePicker.platform = picker;
      expect(await files.save('record.jsonl', '{"a":1}'), isTrue);
      expect(picker.savedFileName, 'record.jsonl');
      expect(String.fromCharCodes(picker.savedBytes!), '{"a":1}');
    });
  });

  group('the shared store', () {
    test('sharedJpStore drops a failed open so the next call retries it',
        () async {
      debugSetSharedJpStore(null);
      addTearDown(() => debugSetSharedJpStore(null));
      Future<JpStore> failing() async =>
          throw StateError('the database file is locked');
      final store = JpStoreMemory();
      Future<JpStore> working() async => store;

      await expectLater(sharedJpStore(open: failing), throwsStateError);
      expect(await sharedJpStore(open: working), same(store),
          reason: 'the rejected open was not kept');
      expect(await sharedJpStore(open: failing), same(store),
          reason: 'a store that opened is kept for the app run');
    });

    testWidgets('with no store injected the page reads the shared store',
        (tester) async {
      final shared = JpStoreMemory();
      debugSetSharedJpStore(shared);
      addTearDown(() => debugSetSharedJpStore(null));
      final word = firstOf(ItemKind.word);
      await tester.runAsync(
          () => record(shared, answer(word, today, Grade.clear, minute: -5)));
      tester.view.physicalSize = const Size(1200, 20000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: MasteryDebugWidget(
          catalog: catalog,
          clock: FixedClock(noonOf(today)),
          files: FakeFiles(),
        ),
      ));
      await settle(tester);
      expect(find.text('1 attempt'), findsOneWidget);
    });
  });

  group('the page', () {
    testWidgets('lists the counts, the load, the answer times and the states',
        (tester) async {
      final store = JpStoreMemory();
      final word = firstOf(ItemKind.word);
      await tester.runAsync(
          () => record(store, answer(word, today, Grade.clear, minute: -5)));
      await pumpDebug(tester, store);

      expect(find.text('Study record'), findsOneWidget);
      expect(find.text('1 attempt'), findsOneWidget);
      expect(find.text('Next 14 days'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Words'), findsOneWidget);
      expect(find.text('0 of $kAnswerTimeMinSamples samples'), findsWidgets);
      expect(find.text('Session length'), findsOneWidget);
      expect(find.text('Learning · 1'), findsOneWidget);
      expect(find.text('New · ${catalog.items.length - 1}'), findsOneWidget);
      expect(find.text('Mastered · 0'), findsOneWidget);
      expect(find.text('Shaky · 0'), findsOneWidget);
      final due = (await tester.runAsync(() => store.srs(word.id)))!.dueDay;
      expect(find.text(word.title), findsOneWidget);
      expect(find.text('1 of $kClearsToMaster · due ${dueLabel(due, today)}'),
          findsOneWidget);
      for (final action in ['Rebuild from log', 'Export', 'Import']) {
        expect(find.text(action), findsOneWidget);
      }
    });

    testWidgets('a Shaky row shows a bare clear count with no denominator',
        (tester) async {
      final store = JpStoreMemory();
      final words = catalog.ofKind(ItemKind.word);
      // Two clears two days apart: still Shaky, since the regain gap is longer than that.
      final two = shakyWith(words[0], [today - 3, today - 1]);
      expect(
          two.clears.last.day - two.clears.first.day, lessThan(kRegainGapDays));
      final one = shakyWith(words[1], [today - 1]);
      await tester.runAsync(() async {
        await store.putMastery(two);
        await store.putMastery(one);
      });
      await pumpDebug(tester, store);

      expect(find.text('Shaky · 2'), findsOneWidget);
      expect(find.text('2 clears toward regaining'), findsOneWidget);
      expect(find.text('1 clear toward regaining'), findsOneWidget);
      expect(find.textContaining('of $kRegainClears'), findsNothing,
          reason: 'no row promises a regain the gap clause still blocks');
    });

    testWidgets('Rebuild from log replays the log over a stale cache',
        (tester) async {
      final store = JpStoreMemory();
      final word = firstOf(ItemKind.word);
      await tester.runAsync(() async {
        await record(store, answer(word, today, Grade.clear, minute: -5));
        // A stale cache: the mastery table says Mastered, the log says one clear.
        await store.putMastery(MasteryState.initial(word.id)
            .copyWith(status: MasteryStatus.mastered));
      });
      await pumpDebug(tester, store);
      expect(find.text('Mastered · 1'), findsOneWidget);

      await tester.tap(find.text('Rebuild from log'));
      await settle(tester);

      expect(find.text('Rebuilt from 1 attempt and 0 seeds.'), findsOneWidget);
      expect(find.text('Mastered · 0'), findsOneWidget);
      expect(find.text('Learning · 1'), findsOneWidget);
      final m = await tester.runAsync(() => store.mastery(word.id));
      expect(m!.status, MasteryStatus.learning);
    });

    testWidgets('Export saves the log as a readable export file',
        (tester) async {
      final store = JpStoreMemory();
      final word = firstOf(ItemKind.word);
      await tester.runAsync(
          () => record(store, answer(word, today, Grade.clear, minute: -5)));
      final files = FakeFiles();
      await pumpDebug(tester, store, files: files);

      await tester.tap(find.text('Export'));
      await settle(tester);

      expect(
          files.savedName,
          'jp-study-record-${dateOfDay(today).year}-'
          '${dateOfDay(today).month.toString().padLeft(2, '0')}-'
          '${dateOfDay(today).day.toString().padLeft(2, '0')}.jsonl');
      final log = decodeStudyExport(files.savedText!);
      expect(log.attempts.single.itemId, word.id);
      expect(find.text('Exported 1 attempt and 0 seeds.'), findsOneWidget);
    });

    testWidgets('a cancelled Export says so and saves nothing', (tester) async {
      final store = JpStoreMemory();
      final word = firstOf(ItemKind.word);
      await tester.runAsync(
          () => record(store, answer(word, today, Grade.clear, minute: -5)));
      final files = FakeFiles(saves: false);
      await pumpDebug(tester, store, files: files);

      await tester.tap(find.text('Export'));
      await settle(tester);

      expect(find.text('Export cancelled.'), findsOneWidget);
      expect(files.savedText, isNull);
    });

    testWidgets('a cancelled Import after Replace changes nothing',
        (tester) async {
      final store = JpStoreMemory();
      final word = firstOf(ItemKind.word);
      await tester.runAsync(
          () => record(store, answer(word, today, Grade.clear, minute: -5)));
      await pumpDebug(tester, store, files: FakeFiles(toOpen: null));

      await tester.tap(find.text('Import'));
      await settle(tester);
      await tester.tap(find.text('Replace'));
      await settle(tester);

      expect(find.text('Import cancelled.'), findsOneWidget);
      expect((await tester.runAsync(() => store.attempts()))!.length, 1);
      expect(find.text('1 attempt'), findsOneWidget);
    });

    testWidgets('a store that cannot be read shows the load error',
        (tester) async {
      await pumpDebug(tester, BrokenStore());

      expect(find.text('Could not read the study record.'), findsOneWidget);
      expect(find.text('Study record'), findsNothing);
    });

    testWidgets('Import asks first, then replaces the record with the file',
        (tester) async {
      final source = JpStoreMemory();
      final words = catalog.ofKind(ItemKind.word);
      late String text;
      await tester.runAsync(() async {
        await record(source, answer(words[1], today, Grade.clear, minute: -9));
        await record(source, answer(words[2], today, Grade.clear, minute: -5));
        text = await exportStudy(source, exportedAt: noonOf(today));
      });
      final store = JpStoreMemory();
      await tester.runAsync(() =>
          record(store, answer(words[0], today, Grade.clear, minute: -5)));
      await pumpDebug(tester, store, files: FakeFiles(toOpen: text));

      await tester.tap(find.text('Import'));
      await settle(tester);
      expect(find.text('Replace the study record?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect((await tester.runAsync(() => store.attempts()))!.length, 1,
          reason: 'Cancel changes nothing');

      await tester.tap(find.text('Import'));
      await settle(tester);
      await tester.tap(find.text('Replace'));
      await settle(tester);

      final after = (await tester.runAsync(() => store.attempts()))!;
      expect(after.map((a) => a.itemId), [words[1].id, words[2].id]);
      expect(find.text('Imported 2 attempts and 0 seeds.'), findsOneWidget);
      expect(find.text('2 attempts'), findsOneWidget);
      expect(find.text('Learning · 2'), findsOneWidget);
    });

    testWidgets('an unreadable import says so and changes nothing',
        (tester) async {
      final store = JpStoreMemory();
      final word = firstOf(ItemKind.word);
      await tester.runAsync(
          () => record(store, answer(word, today, Grade.clear, minute: -5)));
      await pumpDebug(tester, store, files: FakeFiles(toOpen: 'not an export'));

      await tester.tap(find.text('Import'));
      await settle(tester);
      await tester.tap(find.text('Replace'));
      await settle(tester);

      expect(find.textContaining('Could not import'), findsOneWidget);
      expect((await tester.runAsync(() => store.attempts()))!.length, 1);
    });
  });

  group('reaching the page', () {
    // The hub resolves the launch before it builds (Task 20), so it gets a store whose seed
    // already ran and the catalog from disk: an unseeded store opens the seed confirmation.
    Future<QuietRoomJapaneseWidget> seededHub() async {
      final store = JpStoreMemory();
      await seedFromLessons(today, store, catalog, nowUtc: noonOf(today));
      return QuietRoomJapaneseWidget(
          store: store, catalog: catalog, clock: FixedClock(noonOf(today)));
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump();
      }
    }

    testWidgets('Today ends with a quiet Study record link that opens it',
        (tester) async {
      final hub = await seededHub();
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, __) => hub),
        GoRoute(
          name: MasteryDebugWidget.routeName,
          path: MasteryDebugWidget.routePath,
          builder: (_, __) => const Text('the study record page'),
        ),
      ]);
      addTearDown(router.dispose);
      await pumpStudyScreen(tester, MaterialApp.router(routerConfig: router));
      await settle(tester);

      final link = find.text('Study record');
      expect(link, findsOneWidget);
      // At the bottom: below the session card and the 14 dots.
      expect(
          tester.getTopLeft(link).dy,
          greaterThan(
              tester.getTopLeft(find.byKey(const ValueKey('home-dots'))).dy));

      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(find.text('the study record page'), findsOneWidget);
    });

    testWidgets('the link sits on Today only, not on the Lessons tab',
        (tester) async {
      await pumpStudyScreen(tester, await seededHub());
      await settle(tester);
      expect(find.text('Study record'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tab-lessons')));
      await settle(tester);
      expect(find.text('Study record'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('tab-today')));
      await settle(tester);
      expect(find.text('Study record'), findsOneWidget);
    });

    test('the app router registers the page by name', () {
      final router = createRouter(AppStateNotifier.instance);
      addTearDown(router.dispose);
      expect(router.namedLocation(MasteryDebugWidget.routeName),
          MasteryDebugWidget.routePath);
    });
  });
}
