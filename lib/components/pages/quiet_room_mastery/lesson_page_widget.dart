// HAND-WRITTEN. Not FlutterFlow output, so S3 has nothing to adopt.
//
// The lesson page (plan 2026-11-02, Task 25, End states 1 and 9). One page per 第N課:
//   * its title: 第N課 and, where the grammar file has one, the lesson's own title;
//   * the counts over its items, "0 mastered · 3 learning · 2 new" ([lessonCountsLabel]): a
//     count of each item's own state (PIN-1), never a percentage and never the lesson number;
//   * its grammar points, each with its state pill and n of 4 and its next review;
//   * its words, each with its state, where the lesson has a word sheet, and a plain "no word
//     sheet" line where it has none;
//   * the Say-it counts over its grammar points, which never count toward Mastered (D4);
//   * Review these, the one loud action: a [PracticeSessionWidget] over the lesson's due items
//     only, soonest due first. Each is due, so each answer is a review under the drills' due
//     rule (D23); it never writes the day's session record. Off when nothing is due;
//   * Read the whole lesson: the existing grammar screen (`QuietRoomGrammarWidget`) opened on
//     the lesson. Only where the lesson has grammar, since the grammar screen holds no words.
//
// [lessonPageOf] is the pure read the page shows. The page reads one snapshot of the record
// (`TopicIndex.load` plus the attempt log) and reads it again when the learner comes back from
// the review, an item page or the grammar screen.
//
// [openLessonPage] opens the page as a plain route; the lesson path (Task 26) reaches it.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '/flutter_flow/quiet_room.dart';
import '../quiet_room_grammar/jp_study_kit.dart';
import '../quiet_room_grammar/quiet_room_grammar_widget.dart';
import 'attempt.dart';
import 'item_catalog.dart';
import 'item_detail_widget.dart' show PracticeSessionWidget, kSayItNeverCounts;
import 'jp_store.dart';
import 'jp_store_sqlite.dart' show sharedJpStore;
import 'local_day.dart';
import 'probe_widgets.dart' show ProbeStatePill;
import 'review_page.dart' show QrLoudButton, qrLoadingOr;
import 'session_widget.dart' show SessionProbeBuilder;
import 'topic_index.dart';
import 'topic_page_widget.dart'
    show TopicListRow, TopicPill, nextReviewLine, openItemPage;

/// The loud action of the page.
const String kReviewThese = 'Review these';

/// The quiet action that opens the grammar screen on the lesson.
const String kReadWholeLesson = 'Read the whole lesson';

/// The heading over the lesson's grammar points.
const String kGrammarHeading = 'Grammar';

/// The heading over the lesson's words.
const String kWordsHeading = 'Words';

/// The line in place of the words of a lesson with no word sheet.
const String kNoWordSheetLine = 'No word sheet for this lesson.';

/// The line under Review these when none of the lesson's items is due.
const String kNothingDueLine = 'Nothing in this lesson is due today.';

/// The line under Review these when [n] of the lesson's items are due.
String dueTodayLine(int n) =>
    n == 1 ? '1 item due today' : '$n items due today';

/// The Say-it heading: tries that were scored, and the clear ones.
String sayItLine(int tries, int clear) =>
    'Say it: $tries ${tries == 1 ? 'try' : 'tries'} · $clear clear';

/// "0 mastered · 3 learning · 2 new": mastered always, each other state only when an item has
/// it; never a percentage.
String lessonCountsLabel(TopicCounts c) => [
      '${c.mastered} mastered',
      if (c.shaky > 0) '${c.shaky} shaky',
      if (c.learning > 0) '${c.learning} learning',
      if (c.neu > 0) '${c.neu} new',
    ].join(' · ');

/// What the lesson page shows.
class LessonPage {
  const LessonPage({
    required this.lesson,
    required this.title,
    required this.grammarIds,
    required this.wordIds,
    required this.counts,
    required this.dueIds,
    required this.sayItTries,
    required this.sayItClear,
  });

  final int lesson;

  /// The lesson's own title from the grammar file; null for a lesson with no grammar.
  final String? title;

  /// Catalog order.
  final List<String> grammarIds;
  final List<String> wordIds;

  /// Over the grammar points and the words together.
  final TopicCounts counts;

  /// The items due today or before, soonest due first, then grammar before words.
  final List<String> dueIds;
  final int sayItTries;
  final int sayItClear;

  bool get hasGrammar => grammarIds.isNotEmpty;
  bool get hasWordSheet => wordIds.isNotEmpty;
}

/// The page of 第[lesson]課 over [index] and the attempt log [attempts]. Pure.
LessonPage lessonPageOf(int lesson, TopicIndex index,
    Map<String, dynamic> grammar, List<Attempt> attempts) {
  final catalog = index.catalog;
  final grammarIds = [
    for (final i in catalog.items)
      if (i.kind == ItemKind.grammar && i.lesson == lesson) i.id
  ];
  final wordIds = [
    for (final i in catalog.items)
      if (i.kind == ItemKind.word && i.lesson == lesson) i.id
  ];
  final all = [...grammarIds, ...wordIds];
  final counts = index.topic('lesson.$lesson', '第$lesson課', all).counts;

  final due = <(String, int, int)>[];
  for (var i = 0; i < all.length; i++) {
    final day = index.nextDue(all[i]);
    if (day != null && day <= index.today) due.add((all[i], day, i));
  }
  due.sort((a, b) {
    final byDay = a.$2.compareTo(b.$2);
    return byDay != 0 ? byDay : a.$3.compareTo(b.$3);
  });

  final points = grammarIds.toSet();
  var tries = 0, clear = 0;
  for (final a in attempts) {
    if (a.source != Source.sayIt || !points.contains(a.itemId)) continue;
    if (a.grade != Grade.unscored) tries++;
    if (a.grade == Grade.clear) clear++;
  }

  String? title;
  for (final l in (grammar['grammar'] as List? ?? const [])) {
    final m = l as Map;
    if (m['lesson'] == lesson) title = m['title'] as String?;
  }

  return LessonPage(
    lesson: lesson,
    title: (title == null || title.isEmpty) ? null : title,
    grammarIds: List.unmodifiable(grammarIds),
    wordIds: List.unmodifiable(wordIds),
    counts: counts,
    dueIds: [for (final d in due) d.$1],
    sayItTries: tries,
    sayItClear: clear,
  );
}

/// Opens the page of 第[lesson]課, and completes when it closes.
Future<void> openLessonPage(BuildContext context, int lesson,
    {JpStore? store,
    ItemCatalog? catalog,
    Map<String, dynamic>? grammar,
    Clock clock = const SystemClock(),
    SessionProbeBuilder? probeBuilder}) {
  return Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => LessonPageWidget(
      lesson: lesson,
      store: store,
      catalog: catalog,
      grammar: grammar,
      clock: clock,
      probeBuilder: probeBuilder,
    ),
  ));
}

class LessonPageWidget extends StatefulWidget {
  const LessonPageWidget({
    super.key,
    required this.lesson,
    this.store,
    this.catalog,
    this.grammar,
    this.clock = const SystemClock(),
    this.probeBuilder,
  });

  static String routeName = 'quietRoomLessonPage';
  static String routePath = '/quietRoomLessonPage';

  /// The N of 第N課.
  final int lesson;

  /// Null uses the app's one shared store (`sharedJpStore`).
  final JpStore? store;

  /// Null loads the shipped catalog.
  final ItemCatalog? catalog;

  /// Null loads the shipped grammar file.
  final Map<String, dynamic>? grammar;
  final Clock clock;

  /// Null loads the session's standard probe builder for the review.
  final SessionProbeBuilder? probeBuilder;

  @override
  State<LessonPageWidget> createState() => _LessonPageWidgetState();
}

class _LessonPageWidgetState extends State<LessonPageWidget> {
  JpStore? _store;
  ItemCatalog? _catalog;
  TopicIndex? _index;
  LessonPage? _page;
  Object? _error;

  /// Bumped per load, so a load for a lesson no longer shown is dropped.
  int _loads = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(LessonPageWidget old) {
    super.didUpdateWidget(old);
    if (old.lesson != widget.lesson ||
        old.store != widget.store ||
        old.catalog != widget.catalog) {
      _store = null;
      _catalog = null;
      _index = null;
      _page = null;
      _error = null;
      _load();
    }
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
      final page =
          lessonPageOf(widget.lesson, index, grammar, await store.attempts());
      if (mounted && load == _loads) {
        setState(() {
          _index = index;
          _page = page;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && load == _loads) setState(() => _error = e);
    }
  }

  Future<void> _review() async {
    final page = _page;
    if (page == null || page.dueIds.isEmpty) return;
    final catalog = _catalog!;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => QrStudyScaffold(
        child: PracticeSessionWidget(
          items: [for (final id in page.dueIds) catalog.byId(id)!],
          store: _store!,
          catalog: catalog,
          clock: widget.clock,
          probeBuilder: widget.probeBuilder,
        ),
      ),
    ));
    if (mounted) await _load();
  }

  /// The grammar screen on the lesson: by route name under the app's router when no store was
  /// injected, else as a plain page over the same store and clock.
  Future<void> _readWholeLesson() async {
    final lesson = widget.lesson;
    if (widget.store == null && GoRouter.maybeOf(context) != null) {
      await context.pushNamed(QuietRoomGrammarWidget.routeName,
          queryParameters: {'lesson': '$lesson'});
    } else {
      final catalog = _catalog!;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => QuietRoomGrammarWidget(
          initialLesson: lesson,
          store: widget.store,
          itemLookup: catalog.byId,
          clock: widget.clock,
        ),
      ));
    }
    if (mounted) await _load();
  }

  Future<void> _openItem(String itemId) async {
    await openItemPage(context, itemId,
        store: widget.store,
        catalog: widget.catalog,
        clock: widget.clock,
        probeBuilder: widget.probeBuilder);
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final index = _index, page = _page;
    if (index == null || page == null) {
      return QrStudyScaffold(
          child: qrLoadingOr(context, _error, 'Could not open the lesson:'));
    }
    final t = QuietRoomTokens.of(context);
    final catalog = _catalog!;
    Widget heading(String text) => Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 4),
          child: Text(text,
              style: qrText(t,
                  size: 13, weight: FontWeight.w600, color: t.inkStrong)),
        );
    Widget note(String text) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(text, style: qrText(t, size: 13.5, color: t.inkMuted)),
        );
    Widget itemRow(String id) => TopicListRow(
          key: ValueKey('item-$id'),
          title: catalog.byId(id)!.title,
          line: nextReviewLine(index.nextDue(id), index.today),
          pill: ProbeStatePill(state: index.stateOf(id)),
          onTap: () => _openItem(id),
        );
    final rows = <Widget Function()>[
      () => Text('第${page.lesson}課', style: qrTitle(t, size: 28)),
      if (page.title != null)
        () => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(page.title!,
                  style: qrText(t, size: 15, color: t.inkStrong)),
            ),
      () => Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(children: [
              TopicPill(
                  status: rollUp([
                for (final id in [...page.grammarIds, ...page.wordIds])
                  index.statusOf(id)
              ])),
              const SizedBox(width: 10),
              Expanded(
                child: Text(lessonCountsLabel(page.counts),
                    style: qrText(t, size: 14, color: t.ink)),
              ),
            ]),
          ),
      () => Padding(
            padding: const EdgeInsets.only(top: 18),
            child: QrLoudButton(
                label: kReviewThese,
                onPressed: page.dueIds.isEmpty ? null : _review),
          ),
      () => note(page.dueIds.isEmpty
          ? kNothingDueLine
          : dueTodayLine(page.dueIds.length)),
      // Hidden on a words-only lesson (the default seed keeps 2 to 25 words-only, Task 26):
      // the grammar screen holds no words, so the button would open an empty page.
      if (page.hasGrammar)
        () => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                height: QuietRoomMetrics.targetMin,
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _readWholeLesson,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: t.borderControl),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(QuietRoomMetrics.radiusSm)),
                  ),
                  child: Text(kReadWholeLesson,
                      style: qrText(t,
                          size: 15, weight: FontWeight.w600, color: t.ink)),
                ),
              ),
            ),
      if (page.hasGrammar) ...[
        () => heading(kGrammarHeading),
        for (final id in page.grammarIds) () => itemRow(id),
        () => heading(sayItLine(page.sayItTries, page.sayItClear)),
        () => note(kSayItNeverCounts),
      ],
      () => heading(kWordsHeading),
      if (!page.hasWordSheet) () => note(kNoWordSheetLine),
      for (final id in page.wordIds) () => itemRow(id),
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
