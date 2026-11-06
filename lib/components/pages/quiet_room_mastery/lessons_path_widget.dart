// HAND-WRITTEN. Not FlutterFlow output, so S3 has nothing to adopt.
//
// The lesson path (plan 2026-11-02, Task 26, End states 1 and 9). One vertical list in place
// of the screens' number strips:
//   * 第26課 to 第50課, each row with its title, what it holds ("4 grammar points · 48 words")
//     and the counts over its items ([lessonCountsLabel]) where the strips showed nothing
//     or a Done mark. Each count is of the items' own states (PIN-1), never the lesson number;
//   * the current lesson as the one loud row: the last lesson the grammar screen opened
//     (`kLastGrammarLessonKey`), else the first lesson on the path with an item not yet
//     Mastered, else 第26課 ([currentLessonOf]);
//   * a Words-only section for 第2課 to 第25課: word sheets and no grammar. A lesson with no
//     sheet keeps its row and says so.
// A tap opens the lesson page (lesson_page_widget.dart). The path reads the record again
// when the page returns, so its counts follow the answers given there.
//
// [lessonPathOf] is the pure read the path shows. The hub's "Grammar lessons" and
// "Vocabulary" rows open the path by route name (`nav.dart`).

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/flutter_flow/quiet_room.dart';
import '../quiet_room_grammar/jp_study_kit.dart';
import 'attempt.dart' show ItemKind;
import 'item_catalog.dart';
import 'jp_store.dart';
import 'jp_store_sqlite.dart' show sharedJpStore;
import 'lesson_page_widget.dart';
import 'local_day.dart';
import 'mastery_rule.dart';
import 'review_page.dart' show qrLoadingOr;
import 'seed_confirm_widget.dart' show kLastGrammarLessonKey;
import 'session_widget.dart' show SessionProbeBuilder;
import 'topic_index.dart';
import 'topic_page_widget.dart' show TopicPill;

/// The grammar lessons of the path: Mari's checklist, 第26課 to 第50課.
const int kPathFirstGrammarLesson = 26;
const int kPathLastGrammarLesson = 50;

/// The Words-only section: 第2課 to 第25課.
const int kPathFirstWordsLesson = 2;
const int kPathLastWordsLesson = 25;

/// The path's title.
const String kLessonsTitle = 'Lessons';

/// The heading over 第26課 to 第50課.
const String kPathGrammarHeading = 'Grammar lessons';

/// The heading over 第2課 to 第25課.
const String kWordsOnlyHeading = 'Words only';

/// The line under the Words-only heading.
const String kWordsOnlyLine = 'Word sheets with no grammar.';

/// The loud row's label.
const String kCurrentLessonLabel = 'CURRENT LESSON';

/// "4 grammar points · 48 words": what the lesson holds. A lesson with no word sheet says so.
String lessonHoldsLine(int points, int words) {
  final p = points == 1 ? '1 grammar point' : '$points grammar points';
  final w = words == 0 ? null : (words == 1 ? '1 word' : '$words words');
  if (points == 0) return w ?? 'No word sheet';
  return '$p · ${w ?? 'no word sheet'}';
}

/// One row of the path.
class LessonPathRow {
  const LessonPathRow({
    required this.lesson,
    required this.title,
    required this.points,
    required this.words,
    required this.counts,
    required this.pill,
  });

  final int lesson;

  /// The lesson's own title from the grammar file; null for a words-only lesson.
  final String? title;
  final int points;
  final int words;

  /// Over the grammar points and the words together.
  final TopicCounts counts;
  final MasteryStatus pill;

  bool get isEmpty => points + words == 0;
  String get holds => lessonHoldsLine(points, words);

  /// The counts, or nothing for a lesson that holds no items.
  String? get countsLine => isEmpty ? null : lessonCountsLabel(counts);
}

/// What the path shows.
class LessonPath {
  const LessonPath(
      {required this.grammar, required this.wordsOnly, required this.current});

  /// 第26課 to 第50課, in lesson order.
  final List<LessonPathRow> grammar;

  /// 第2課 to 第25課, in lesson order.
  final List<LessonPathRow> wordsOnly;

  /// The loud row's lesson.
  final int current;
}

/// The current lesson: [lastLesson] when it is on the path's grammar lessons, else the first
/// of them with an item not yet Mastered, else the first of them.
int currentLessonOf(List<LessonPathRow> grammar, int? lastLesson) {
  if (lastLesson != null && grammar.any((r) => r.lesson == lastLesson)) {
    return lastLesson;
  }
  for (final r in grammar) {
    if (!r.isEmpty && r.counts.mastered < r.counts.total) return r.lesson;
  }
  return grammar.isEmpty ? kPathFirstGrammarLesson : grammar.first.lesson;
}

/// The path over [index] and the grammar file [grammar]. [lastLesson] is the last lesson the
/// grammar screen opened. Pure.
LessonPath lessonPathOf(TopicIndex index, Map<String, dynamic> grammar,
    {int? lastLesson}) {
  final titles = <int, String>{};
  for (final l in (grammar['grammar'] as List? ?? const [])) {
    final m = l as Map;
    final title = m['title'] as String?;
    if (m['lesson'] is int && title != null && title.isNotEmpty) {
      titles[m['lesson'] as int] = title;
    }
  }
  final points = <int, List<String>>{};
  final words = <int, List<String>>{};
  for (final i in index.catalog.items) {
    final lesson = i.lesson;
    if (lesson == null) continue;
    if (i.kind == ItemKind.grammar) (points[lesson] ??= []).add(i.id);
    if (i.kind == ItemKind.word) (words[lesson] ??= []).add(i.id);
  }
  LessonPathRow row(int lesson) {
    final p = points[lesson] ?? const <String>[];
    final w = words[lesson] ?? const <String>[];
    final ids = [...p, ...w];
    return LessonPathRow(
      lesson: lesson,
      title: titles[lesson],
      points: p.length,
      words: w.length,
      counts: index.topic('lesson.$lesson', '第$lesson課', ids).counts,
      pill: rollUp([for (final id in ids) index.statusOf(id)]),
    );
  }

  final grammarRows = [
    for (var l = kPathFirstGrammarLesson; l <= kPathLastGrammarLesson; l++)
      row(l)
  ];
  return LessonPath(
    grammar: List.unmodifiable(grammarRows),
    wordsOnly: List.unmodifiable([
      for (var l = kPathFirstWordsLesson; l <= kPathLastWordsLesson; l++) row(l)
    ]),
    current: currentLessonOf(grammarRows, lastLesson),
  );
}

class LessonsPathWidget extends StatefulWidget {
  const LessonsPathWidget({
    super.key,
    this.store,
    this.catalog,
    this.grammar,
    this.clock = const SystemClock(),
    this.probeBuilder,
  });

  static String routeName = 'quietRoomLessons';
  static String routePath = '/quietRoomLessons';

  /// Null uses the app's one shared store (`sharedJpStore`).
  final JpStore? store;

  /// Null loads the shipped catalog.
  final ItemCatalog? catalog;

  /// Null loads the shipped grammar file.
  final Map<String, dynamic>? grammar;
  final Clock clock;

  /// Passed to the lesson page for its review.
  final SessionProbeBuilder? probeBuilder;

  @override
  State<LessonsPathWidget> createState() => _LessonsPathWidgetState();
}

class _LessonsPathWidgetState extends State<LessonsPathWidget> {
  JpStore? _store;
  ItemCatalog? _catalog;
  LessonPath? _path;
  Object? _error;

  /// Bumped per load, so only the latest load lands.
  int _loads = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final load = ++_loads;
    try {
      final store = _store ??= widget.store ?? await sharedJpStore();
      final catalog = _catalog ??= widget.catalog ?? await ItemCatalog.load();
      final grammar = widget.grammar ?? await JpGrammarData.load();
      final index = await TopicIndex.load(
          store: store,
          catalog: catalog,
          grammar: grammar,
          today: widget.clock.today());
      final last =
          (await SharedPreferences.getInstance()).getInt(kLastGrammarLessonKey);
      final path = lessonPathOf(index, grammar, lastLesson: last);
      if (mounted && load == _loads) {
        setState(() {
          _path = path;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && load == _loads) setState(() => _error = e);
    }
  }

  /// The lesson page: by route name under the app's router when no store was injected, else
  /// as a plain page over the same store and clock.
  Future<void> _open(int lesson) async {
    if (widget.store == null && GoRouter.maybeOf(context) != null) {
      await context.pushNamed(LessonPageWidget.routeName,
          queryParameters: {'lesson': '$lesson'});
    } else {
      await openLessonPage(context, lesson,
          store: widget.store,
          catalog: widget.catalog,
          grammar: widget.grammar,
          clock: widget.clock,
          probeBuilder: widget.probeBuilder);
    }
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final path = _path;
    if (path == null) {
      return QrStudyScaffold(
          child: qrLoadingOr(context, _error, 'Could not open the lessons:'));
    }
    final t = QuietRoomTokens.of(context);
    Widget heading(String text) => Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 4),
          child: Text(text,
              style: qrText(t,
                  size: 13, weight: FontWeight.w600, color: t.inkStrong)),
        );
    final rows = <Widget Function()>[
      () => Text(kLessonsTitle, style: qrTitle(t, size: 28)),
      () => heading(kPathGrammarHeading),
      for (final r in path.grammar)
        r.lesson == path.current
            ? () => _CurrentLessonRow(row: r, onTap: () => _open(r.lesson))
            : () => _PathRow(row: r, onTap: () => _open(r.lesson)),
      () => heading(kWordsOnlyHeading),
      () =>
          Text(kWordsOnlyLine, style: qrText(t, size: 13.5, color: t.inkMuted)),
      for (final r in path.wordsOnly)
        () => _PathRow(row: r, onTap: () => _open(r.lesson)),
    ];
    return QrStudyScaffold(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        itemCount: rows.length,
        itemBuilder: (_, i) => rows[i](),
      ),
    );
  }
}

/// A quiet row: 第N課, the title, what it holds, its counts and its pill.
class _PathRow extends StatelessWidget {
  const _PathRow({required this.row, required this.onTap});

  final LessonPathRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = QuietRoomTokens.of(context);
    final counts = row.countsLine;
    return InkWell(
      key: ValueKey('path-${row.lesson}'),
      onTap: onTap,
      child: Container(
        constraints:
            const BoxConstraints(minHeight: QuietRoomMetrics.targetMin),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration:
            BoxDecoration(border: Border(bottom: BorderSide(color: t.border))),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    [
                      '第${row.lesson}課',
                      if (row.title != null) row.title!,
                    ].join('  '),
                    style: qrText(t,
                        size: 16, weight: FontWeight.w600, color: t.inkStrong)),
                const SizedBox(height: 2),
                Text(row.holds, style: qrText(t, size: 13, color: t.inkMuted)),
                if (counts != null)
                  Text(counts, style: qrText(t, size: 13, color: t.ink)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (!row.isEmpty) TopicPill(status: row.pill),
        ]),
      ),
    );
  }
}

/// The loud row: the current lesson on the hero fill.
class _CurrentLessonRow extends StatelessWidget {
  const _CurrentLessonRow({required this.row, required this.onTap});

  final LessonPathRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = QuietRoomTokens.of(context);
    final counts = row.countsLine;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('path-current'),
          borderRadius: BorderRadius.circular(QuietRoomMetrics.radiusMd),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: t.heroFill,
              borderRadius: BorderRadius.circular(QuietRoomMetrics.radiusMd),
            ),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(kCurrentLessonLabel,
                    style: qrText(t,
                            size: 11,
                            weight: FontWeight.w600,
                            color: t.heroInkMuted)
                        .copyWith(letterSpacing: 11 * 0.08)),
                const SizedBox(height: 8),
                Text('第${row.lesson}課',
                    style: qrTitle(t, size: 28).copyWith(color: t.heroInk)),
                if (row.title != null) ...[
                  const SizedBox(height: 4),
                  Text(row.title!,
                      style: qrText(t, size: 15, color: t.heroInk)),
                ],
                const SizedBox(height: 14),
                Text(row.holds,
                    style: qrText(t, size: 13, color: t.heroInkMuted)),
                Row(children: [
                  if (counts != null)
                    Expanded(
                      child: Text(counts,
                          style: qrText(t, size: 13, color: t.heroInk)),
                    )
                  else
                    const Spacer(),
                  Icon(Icons.arrow_forward, size: 20, color: t.heroInk),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
