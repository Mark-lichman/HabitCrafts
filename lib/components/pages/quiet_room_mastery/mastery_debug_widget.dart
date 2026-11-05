// HAND-WRITTEN. Not FlutterFlow output, so S3 has nothing to adopt.
//
// The study record debug page (Task 13, A2). A plain read of the store, for Mark and for tuning:
//   * every catalog item under its state (New, Learning with n of 4, Mastered, Shaky) with its
//     next due day, soonest first;
//   * the load of the next 14 days, today first, and the overdue count apart;
//   * the attempt count;
//   * the median answer time per item kind, shown only once the kind has
//     [kAnswerTimeMinSamples] timed answers (A2: the per-kind cost estimates in the plan builder
//     are retuned by hand from these medians);
//   * the median session length, over every session and over the first 14 days of sessions
//     (End state 16);
//   * Rebuild from log (JpStore.rebuild), Export and Import (study_export.dart).
// Each item row opens the item page (item_detail_widget.dart).
// Reached from the quiet "Study record" link at the bottom of the Japanese hub.
//
// The counts are computed here from the store, never restated anywhere else (de-mirror).

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '/flutter_flow/quiet_room.dart';
import '../quiet_room_grammar/jp_study_kit.dart';
import 'attempt.dart';
import 'fsrs.dart';
import 'item_catalog.dart';
import 'item_detail_widget.dart' show openItemDetail;
import 'jp_store.dart';
import 'jp_store_sqlite.dart' show sharedJpStore;
import 'local_day.dart';
import 'mastery_rule.dart';
import 'scheduler.dart';
import 'study_export.dart';

/// Timed answers a kind needs before the page shows its median (A2).
const int kAnswerTimeMinSamples = 50;

/// The days the load strip and the early-session median cover.
const int kDebugWindowDays = 14;

/// A local day past every due day, for [JpStore.dueOnOrBefore]. It fits in 32 bits: on web a
/// shift past 31 bits is 0, so a wider bound would read no due days at all.
const int _kFarFutureDay = 0x7fffffff;

/// One catalog item as the page lists it.
class RecordRow {
  const RecordRow(
      {required this.item,
      required this.status,
      required this.clears,
      this.dueDay});

  final ItemDef item;
  final MasteryStatus status;

  /// [MasteryState.clearCount]: n of 4 while Learning, the regain clears while Shaky.
  final int clears;

  /// The FSRS due day, else the seeded due day; null for an item with neither.
  final int? dueDay;
}

/// Timed answers of one kind and their median, once there are enough.
class AnswerTime {
  const AnswerTime({required this.samples, this.medianMs});

  final int samples;

  /// Null below [kAnswerTimeMinSamples].
  final double? medianMs;
}

/// What the page shows, read off the store in one pass. Seed counts are not here: the action
/// messages take theirs from [JpStore.exportLog], and nothing else on the page shows one.
class RecordSummary {
  const RecordSummary({
    required this.byStatus,
    required this.load14,
    required this.overdue,
    required this.attemptCount,
    required this.answerTimes,
    required this.sessionCount,
    required this.medianSessionMinutes,
    required this.firstDaysSessionCount,
    required this.firstDaysMedianSessionMinutes,
  });

  final Map<MasteryStatus, List<RecordRow>> byStatus;

  /// Items due on each of the next [kDebugWindowDays] days, today first.
  final List<int> load14;

  /// Items due before today.
  final int overdue;
  final int attemptCount;
  final Map<ItemKind, AnswerTime> answerTimes;
  final int sessionCount;
  final double? medianSessionMinutes;

  /// Sessions that started within [kDebugWindowDays] days of the first session.
  final int firstDaysSessionCount;
  final double? firstDaysMedianSessionMinutes;
}

double? _median(List<num> values) {
  if (values.isEmpty) return null;
  final v = [...values]..sort();
  final mid = v.length ~/ 2;
  return v.length.isOdd ? v[mid].toDouble() : (v[mid - 1] + v[mid]) / 2;
}

/// Reads the page's numbers from [store] for local day [today].
///
/// A session is the attempts that share a session id, the imported v2 Say-it history aside. It
/// runs from the start of its first answer (the answer's time less its duration) to its last
/// answer. An answer time sample is an attempt with a duration, Say-it aside (it is not a
/// queued probe).
Future<RecordSummary> summarizeRecord(JpStore store, ItemCatalog catalog,
    {required int today}) async {
  final mastery = await store.allMastery();
  final due = await store.dueOnOrBefore(_kFarFutureDay);
  final dueDay = {for (final d in due) d.itemId: d.dueDay};
  final load = await store.loadByDay();
  final attempts = await store.attempts();

  final byStatus = {for (final s in MasteryStatus.values) s: <RecordRow>[]};
  for (final item in catalog.items) {
    final m = mastery[item.id];
    final status = m?.status ?? MasteryStatus.neu;
    byStatus[status]!.add(RecordRow(
        item: item,
        status: status,
        clears: m?.clearCount ?? 0,
        dueDay: dueDay[item.id]));
  }
  for (final rows in byStatus.values) {
    // A stable sort: soonest due first, unscheduled last, catalog order within a day.
    final order = {for (var i = 0; i < rows.length; i++) rows[i].item.id: i};
    rows.sort((a, b) {
      final da = a.dueDay, db = b.dueDay;
      if (da != db) {
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      }
      return order[a.item.id]!.compareTo(order[b.item.id]!);
    });
  }

  final load14 = [
    for (var d = today; d < today + kDebugWindowDays; d++) load[d] ?? 0
  ];
  final overdue = load.entries
      .where((e) => e.key < today)
      .fold<int>(0, (n, e) => n + e.value);

  final timed = <ItemKind, List<int>>{
    for (final k in ItemKind.values) k: <int>[]
  };
  final sessions = <String, ({DateTime start, DateTime end, int day})>{};
  for (final a in attempts) {
    final kind = catalog.byId(a.itemId)?.kind;
    if (kind != null && a.durationMs > 0 && a.source != Source.sayIt) {
      timed[kind]!.add(a.durationMs);
    }
    if (a.sessionId == kV2MigrationSession) continue;
    final start = a.atUtc.subtract(Duration(milliseconds: a.durationMs));
    final s = sessions[a.sessionId];
    sessions[a.sessionId] = s == null
        ? (start: start, end: a.atUtc, day: a.localDay)
        : (
            start: start.isBefore(s.start) ? start : s.start,
            end: a.atUtc.isAfter(s.end) ? a.atUtc : s.end,
            day: a.localDay < s.day ? a.localDay : s.day,
          );
  }
  final answerTimes = {
    for (final e in timed.entries)
      e.key: AnswerTime(
          samples: e.value.length,
          medianMs: e.value.length >= kAnswerTimeMinSamples
              ? _median(e.value)
              : null),
  };
  double minutes(({DateTime start, DateTime end, int day}) s) =>
      s.end.difference(s.start).inMilliseconds / 60000;
  final all = sessions.values.toList();
  final firstDay = all.isEmpty
      ? null
      : all.map((s) => s.day).reduce((a, b) => a < b ? a : b);
  final early = firstDay == null
      ? const <({DateTime start, DateTime end, int day})>[]
      : all.where((s) => s.day < firstDay + kDebugWindowDays).toList();

  return RecordSummary(
    byStatus: byStatus,
    load14: load14,
    overdue: overdue,
    attemptCount: attempts.length,
    answerTimes: answerTimes,
    sessionCount: all.length,
    medianSessionMinutes: _median(all.map(minutes).toList()),
    firstDaysSessionCount: early.length,
    firstDaysMedianSessionMinutes: _median(early.map(minutes).toList()),
  );
}

/// A due day as the page shows it: today, tomorrow, or the date.
String dueLabel(int day, int today) {
  if (day == today) return 'today';
  if (day == today + 1) return 'tomorrow';
  final when = DateFormat('EEE d MMM').format(dateOfDay(day));
  return day < today ? '$when (overdue)' : when;
}

String _plural(int n, String one) => '$n $one${n == 1 ? '' : 's'}';

String _counts(int attempts, int seeds) =>
    '${_plural(attempts, 'attempt')} and ${_plural(seeds, 'seed')}';

const Map<MasteryStatus, String> _statusName = {
  MasteryStatus.learning: 'Learning',
  MasteryStatus.shaky: 'Shaky',
  MasteryStatus.mastered: 'Mastered',
  MasteryStatus.neu: 'New',
};

const Map<ItemKind, String> _kindName = {
  ItemKind.word: 'Words',
  ItemKind.grammar: 'Grammar points',
  ItemKind.particle: 'Particles',
  ItemKind.conjugation: 'Conjugation',
  ItemKind.pair: 'Verb pairs',
  ItemKind.tableRow: 'Table rows',
};

/// Where Export writes and Import reads. A seam for the test.
abstract class StudyRecordFiles {
  /// Saves [text] as [fileName]; false when the learner cancels. The web picker cannot report
  /// a cancel (see [PickerStudyRecordFiles.save]), so on web a cancel still reads as saved.
  Future<bool> save(String fileName, String text);

  /// The chosen file's text; null only when the learner cancels. A chosen file that cannot
  /// be read throws, so the page reports a read failure and never calls it a cancel.
  Future<String?> open();
}

/// The device's save and open dialogs (file_picker).
class PickerStudyRecordFiles implements StudyRecordFiles {
  const PickerStudyRecordFiles();

  @override
  Future<bool> save(String fileName, String text) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export the study record',
      fileName: fileName,
      bytes: utf8.encode(text),
    );
    // On web saveFile starts the browser download and then always returns null, so a cancel
    // is not visible here. The web store is in memory (`sharedJpStore`), so that export holds
    // only this app run's answers.
    return kIsWeb || path != null;
  }

  @override
  Future<String?> open() async {
    final picked = await FilePicker.platform
        .pickFiles(dialogTitle: 'Import a study record', withData: true);
    if (picked == null) return null;
    // withData asked for the bytes; null here means the chosen file could not be read.
    final bytes = picked.files.single.bytes;
    if (bytes == null) throw StateError('the chosen file could not be read');
    return utf8.decode(bytes);
  }
}

class MasteryDebugWidget extends StatefulWidget {
  const MasteryDebugWidget({
    super.key,
    this.store,
    this.catalog,
    this.clock = const SystemClock(),
    this.scheduler = const FsrsScheduler(),
    this.files = const PickerStudyRecordFiles(),
  });

  static String routeName = 'quietRoomStudyRecord';
  static String routePath = '/quietRoomStudyRecord';

  /// Null reads the app's one shared store (`sharedJpStore`), the one the screens write to.
  final JpStore? store;

  /// Null loads the shipped catalog.
  final ItemCatalog? catalog;
  final Clock clock;
  final Scheduler scheduler;
  final StudyRecordFiles files;

  @override
  State<MasteryDebugWidget> createState() => _MasteryDebugWidgetState();
}

class _MasteryDebugWidgetState extends State<MasteryDebugWidget> {
  JpStore? _store;
  ItemCatalog? _catalog;
  RecordSummary? _summary;
  Object? _loadError;
  String? _message;
  bool _messageIsError = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  int get _today => widget.clock.today();

  Future<void> _load() async {
    try {
      final store = _store ??= widget.store ?? await sharedJpStore();
      final catalog = _catalog ??= widget.catalog ?? await ItemCatalog.load();
      final summary = await summarizeRecord(store, catalog, today: _today);
      if (mounted) setState(() => _summary = summary);
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  Future<void> _run(Future<String> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final message = await action();
      _messageIsError = false;
      _message = message;
    } catch (e) {
      _messageIsError = true;
      _message = e is FormatException
          ? 'Could not import that file: ${e.message}'
          : 'Could not finish: $e';
    }
    await _load();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _rebuild() => _run(() async {
        final catalog = _catalog!;
        await _store!.rebuild(catalog.byId, widget.scheduler);
        final log = await _store!.exportLog();
        return 'Rebuilt from ${_counts(log.attempts.length, log.seeds.length)}.';
      });

  Future<void> _export() => _run(() async {
        final now = widget.clock.now();
        final log = await _store!.exportLog();
        final text = encodeStudyExport(log, exportedAt: now);
        final name =
            'jp-study-record-${DateFormat('yyyy-MM-dd').format(dateOfDay(_today))}.jsonl';
        final saved = await widget.files.save(name, text);
        if (!saved) return 'Export cancelled.';
        return 'Exported ${_counts(log.attempts.length, log.seeds.length)}.';
      });

  Future<void> _import() async {
    final t = QuietRoomTokens.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Replace the study record?', style: qrTitle(t, size: 20)),
        content: Text(
            'Import replaces every attempt on this device with the file\'s, '
            'then rebuilds every state from it.',
            style: qrText(t)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Replace')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      final text = await widget.files.open();
      if (text == null) return 'Import cancelled.';
      await importStudy(_store!, text,
          lookup: _catalog!.byId, scheduler: widget.scheduler);
      final log = await _store!.exportLog();
      return 'Imported ${_counts(log.attempts.length, log.seeds.length)}.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = QuietRoomTokens.of(context);
    final s = _summary;
    Widget body;
    if (_loadError != null) {
      body = Center(
          child: Text('Could not read the study record.',
              style: qrText(t, color: t.clay600)));
    } else if (s == null) {
      body = Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(t.inkSubtle)),
        ),
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        children: [
          Text('Study record', style: qrTitle(t, size: 28)),
          const SizedBox(height: 5),
          Text(_plural(s.attemptCount, 'attempt'),
              style: qrText(t, color: t.inkMuted)),
          const SizedBox(height: 14),
          Wrap(spacing: 7, runSpacing: 7, children: [
            QrPill(
                label: 'Rebuild from log',
                on: false,
                solid: false,
                onTap: _rebuild),
            QrPill(label: 'Export', on: false, solid: false, onTap: _export),
            QrPill(label: 'Import', on: false, solid: false, onTap: _import),
          ]),
          if (_message != null) ...[
            const SizedBox(height: 10),
            Text(_message!,
                style: qrText(t,
                    size: 13, color: _messageIsError ? t.clay600 : t.sage700)),
          ],
          _heading(t, 'Next 14 days'),
          if (s.overdue > 0) _line(t, 'Overdue', '${s.overdue}'),
          for (var i = 0; i < s.load14.length; i++)
            _line(
                t,
                i == 0
                    ? 'Today'
                    : i == 1
                        ? 'Tomorrow'
                        : DateFormat('EEE d MMM').format(dateOfDay(_today + i)),
                '${s.load14[i]}'),
          _heading(t, 'Answer time'),
          for (final k in ItemKind.values)
            _line(
                t,
                _kindName[k]!,
                s.answerTimes[k]!.medianMs == null
                    ? '${s.answerTimes[k]!.samples} of $kAnswerTimeMinSamples samples'
                    : '${(s.answerTimes[k]!.medianMs! / 1000).toStringAsFixed(1)} s '
                        'median of ${s.answerTimes[k]!.samples}'),
          _heading(t, 'Session length'),
          _line(t, 'All sessions',
              _sessionText(s.medianSessionMinutes, s.sessionCount)),
          _line(
              t,
              'First 14 days',
              _sessionText(
                  s.firstDaysMedianSessionMinutes, s.firstDaysSessionCount)),
          for (final status in _statusName.keys) ...[
            _heading(
                t, '${_statusName[status]} · ${s.byStatus[status]!.length}'),
            for (final row in s.byStatus[status]!) _item(t, row),
          ],
        ],
      );
    }
    return QrStudyScaffold(
      child: AbsorbPointer(absorbing: _busy, child: body),
    );
  }

  String _sessionText(double? median, int count) => median == null
      ? 'No sessions yet'
      : '${median.toStringAsFixed(1)} min median of ${_plural(count, 'session')}';

  Widget _heading(QuietRoomTokens t, String text) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 6),
        child: Text(text,
            style: qrText(t,
                size: 13, weight: FontWeight.w600, color: t.inkStrong)),
      );

  Widget _line(QuietRoomTokens t, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(label, style: qrText(t, size: 13))),
          Text(value, style: qrText(t, size: 13, color: t.inkMuted)),
        ]),
      );

  Widget _item(QuietRoomTokens t, RecordRow row) {
    final due =
        row.dueDay == null ? null : 'due ${dueLabel(row.dueDay!, _today)}';
    final detail = [
      if (row.status == MasteryStatus.learning)
        '${row.clears} of $kClearsToMaster',
      // A bare count: regaining also needs the kRegainGapDays gap (mastery_rule.dart), so
      // an 'n of kRegainClears' denominator would promise what the gap clause still blocks.
      if (row.status == MasteryStatus.shaky)
        '${_plural(row.clears, 'clear')} toward regaining',
      if (due != null) due,
    ].join(' · ');
    return InkWell(
      key: ValueKey('record-item-${row.item.id}'),
      onTap: () => _openItem(row.item.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Text(row.item.title,
                  style: qrText(t, size: 13, color: t.inkStrong))),
          if (detail.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child:
                  Text(detail, style: qrText(t, size: 12.5, color: t.inkMuted)),
            ),
        ]),
      ),
    );
  }

  /// Opens the item page over [itemId], then reads the record again: a Practice now answer
  /// there may have moved the item.
  Future<void> _openItem(String itemId) async {
    await openItemDetail(context, itemId,
        store: _store, catalog: _catalog, clock: widget.clock);
    if (mounted) await _load();
  }
}
