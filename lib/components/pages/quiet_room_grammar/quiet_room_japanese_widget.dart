// HAND-WRITTEN. Not FlutterFlow output, so S3 has nothing to adopt.
//
// The start screen of this build: Japanese study, no login. Mark asked for a
// single-user build (2026-10-24), so there is no account and nothing here reads
// Firestore. Everything comes from the bundled lesson files.
//
// Quiet Room: one loud object. The hero is the grammar lesson to continue, because
// grammar is where the practice is needed most. Everything else is a quiet card.
//
// Before it builds, the screen resolves the launch (`onLaunch`, relaunch.dart, D9, PIN-9):
//   * firstLaunch: the seed confirmation (seed_confirm_widget.dart), then this hub;
//   * welcomeBack: the Welcome back screen (welcome_back_widget.dart), then the session;
//   * today, resume and done: this hub, with the Today card above the search and the hero.
// The Today card names the plan's sections with their counts, the minutes line, and Start or
// Resume; on a finished day it shows the end state. The old hero and rows stay below it
// until the home becomes Today (plan 2026-11-02, Phase 7).
//
// The hub is the app's home, so the OS keeps it warm overnight. The launch is resolved
// again when the app resumes on a later local day than the one it resolved, and when a
// screen the hub opened returns on a later day: without that, a finished day's end card
// would stay up the next morning with no Start, and a return after a break would skip
// Welcome back. A resume behind a pushed screen waits for that screen to return, so a
// session under way across the 04:00 day change keeps its plan and tomorrow's is built
// after it.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/quiet_room.dart';
import '/components/pages/quiet_room_lesson/quiet_room_lesson_widget.dart';
import '/components/pages/quiet_room_mastery/item_catalog.dart';
import '/components/pages/quiet_room_mastery/jp_store.dart';
import '/components/pages/quiet_room_mastery/jp_store_sqlite.dart'
    show sharedJpStore;
import '/components/pages/quiet_room_mastery/local_day.dart';
import '/components/pages/quiet_room_mastery/mastery_debug_widget.dart';
import '/components/pages/quiet_room_mastery/plan_builder.dart';
import '/components/pages/quiet_room_mastery/relaunch.dart';
import '/components/pages/quiet_room_mastery/review_page.dart';
import '/components/pages/quiet_room_mastery/seed_confirm_widget.dart';
import '/components/pages/quiet_room_mastery/session_widget.dart'
    show sectionLabel;
import '/components/pages/quiet_room_mastery/welcome_back_widget.dart';
import 'jp_study_kit.dart';
import 'quiet_room_drills_widget.dart';
import 'quiet_room_grammar_widget.dart';

/// The Today card's queue line: each non-empty section with its count, in session order,
/// then the stretch when the plan offers it, "Repair 3 · Due 42 · Keep-sharp 10 · New 8 ·
/// +4 stretch". Empty when the plan holds nothing.
String todaySectionsLine(DayPlan plan) {
  final counts = plan.counts;
  return [
    for (final s in PlanSection.values)
      if ((counts[s] ?? 0) > 0) '${sectionLabel(s)} ${counts[s]}',
    if (plan.stretchOffer && plan.stretchEntries.isNotEmpty)
      '+${plan.stretchEntries.length} stretch',
  ].join(' · ');
}

/// The Today card's minutes line: the target and the ceiling, or less when the plan is short.
String todayMinutesLine(DayPlan plan) {
  final target = plan.targetSeconds ~/ 60;
  final ceiling = plan.ceilingSeconds ~/ 60;
  if (plan.plannedSeconds >= plan.targetSeconds) {
    return '$target to $ceiling minutes';
  }
  final minutes = (plan.plannedSeconds + 59) ~/ 60;
  return 'About ${minutes < 1 ? 1 : minutes} min, under the $target-minute target';
}

class QuietRoomJapaneseWidget extends StatefulWidget {
  const QuietRoomJapaneseWidget({
    super.key,
    this.store,
    this.catalog,
    this.clock = const SystemClock(),
  });

  /// Null uses the app's one shared store (`sharedJpStore`).
  final JpStore? store;

  /// Null loads the shipped catalog.
  final ItemCatalog? catalog;
  final Clock clock;

  static String routeName = 'quietRoomJapanese';
  static String routePath = '/quietRoomJapanese';

  /// The lesson the hero card continues. Written by the grammar screen.
  static const lastLessonKey = kLastGrammarLessonKey;

  @override
  State<QuietRoomJapaneseWidget> createState() =>
      _QuietRoomJapaneseWidgetState();
}

class _QuietRoomJapaneseWidgetState extends State<QuietRoomJapaneseWidget>
    with WidgetsBindingObserver {
  int? _last;
  String _query = '';
  String? _use;
  final _searchBox = TextEditingController();

  JpStore? _store;
  ItemCatalog? _catalog;
  Launch? _launch;
  Object? _launchError;

  /// "Not now" on Welcome back: the hub for the rest of this visit.
  bool _pastWelcome = false;

  /// Only the latest launch resolution lands (a return from the session or a resume on a
  /// new day can overlap one).
  int _launchRun = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _readLast();
    _relaunch();
  }

  /// A warm app resumed on a later local day resolves the launch again, so the hub never
  /// keeps yesterday's card. Only resumed counts: inactive and hidden come with a
  /// permission dialog or the notification shade, and paused shows nothing.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Behind a pushed screen the hub waits: `_open` and `_startSession` resolve the
    // launch again when that screen returns, after the session's answers are in.
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    _relaunchIfNewDay();
  }

  /// Resolves the launch again when the local day moved past the one it resolved. Welcome
  /// back may show again on the new day, so "Not now" is forgotten with the old day.
  void _relaunchIfNewDay() {
    final launch = _launch;
    if (launch == null || localDay(widget.clock.now()) == launch.day) return;
    _pastWelcome = false;
    _relaunch();
  }

  /// Resolves today's launch. Writes only today's `DayRecord`, through `onLaunch`.
  Future<void> _relaunch() async {
    final run = ++_launchRun;
    try {
      final store = _store ??= widget.store ?? await sharedJpStore();
      final catalog = _catalog ??= widget.catalog ?? await ItemCatalog.load();
      final launch = await onLaunch(widget.clock.now(), store, catalog);
      if (mounted && run == _launchRun) {
        setState(() {
          _launch = launch;
          _launchError = null;
        });
      }
    } catch (e) {
      if (mounted && run == _launchRun) setState(() => _launchError = e);
    }
  }

  Future<void> _startSession() async {
    await openReviewSession(context,
        store: _store, catalog: _catalog, clock: widget.clock);
    if (!mounted) return;
    _pastWelcome = true;
    await _relaunch();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchBox.dispose();
    super.dispose();
  }

  /// Puts [query] in the search box, as if typed, and clears the use filter.
  /// The cursor goes to the end: the `text` setter alone would leave the
  /// selection at -1, so the next typed character could land at the start.
  void _searchFor(String query) {
    _searchBox.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    setState(() {
      _query = query.trim();
      _use = null;
    });
  }

  Future<void> _readLast() async {
    final p = await SharedPreferences.getInstance();
    if (mounted)
      setState(() => _last = p.getInt(QuietRoomJapaneseWidget.lastLessonKey));
  }

  Future<void> _open(String route,
      [Map<String, dynamic> params = const {}]) async {
    await context.pushNamed(route, queryParameters: params);
    if (!mounted) return;
    _readLast(); // the grammar screen may have moved on
    _relaunchIfNewDay(); // and the day may have, while that screen was up
  }

  @override
  Widget build(BuildContext context) {
    final launch = _launch;
    if (launch == null && _launchError == null) {
      return QrStudyScaffold(
          showBack: false, child: qrLoadingOr(context, null, ''));
    }
    if (launch?.decision == LaunchDecision.firstLaunch) {
      return SeedConfirmWidget(
        store: _store,
        catalog: _catalog,
        clock: widget.clock,
        onSeeded: _relaunch,
      );
    }
    if (launch?.decision == LaunchDecision.welcomeBack && !_pastWelcome) {
      return WelcomeBackWidget(
        key: ValueKey('welcome-${launch!.day}'),
        launch: launch,
        store: _store,
        catalog: _catalog,
        clock: widget.clock,
        onStart: _startSession,
        onLater: () => setState(() => _pastWelcome = true),
      );
    }
    return QrStudyScaffold(
      showBack: false,
      child: QrLoad(builder: (context, doc) {
        final t = QuietRoomTokens.of(context);
        final grammar = (doc['grammar'] as List).cast<Map<String, dynamic>>();
        final lesson = grammar.firstWhere((g) => g['lesson'] == _last,
            orElse: () => grammar.first);
        final points = (lesson['points'] as List).length;
        final verbs = (doc['conjugation']['verbs'] as List).length;
        final pairs = (doc['pairs'] as List).length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
          children: [
            Text('日本語', style: qrTitle(t, size: 30)),
            const SizedBox(height: 5),
            Text('Five minutes of grammar, then one drill.',
                style: qrText(t, color: t.inkMuted)),
            const SizedBox(height: 16),
            _todayCard(t),
            const SizedBox(height: 16),
            _search(t),
            const SizedBox(height: 10),
            _useStrip(t, doc),
            const SizedBox(height: 16),
            if (_query.isNotEmpty || _use != null)
              ..._results(t, doc)
            else ...[
              _hero(t, lesson, points),
              const SizedBox(height: 22),
              _row(t, 'Grammar lessons', 'Mari\'s checklist · 第26課 to 第50課',
                  () => _open(QuietRoomGrammarWidget.routeName)),
              _row(
                  t,
                  'Conjugation',
                  '$verbs verbs · 12 forms',
                  () => _open(QuietRoomDrillsWidget.routeName,
                      {'mode': 'conjugation'})),
              _row(
                  t,
                  'Verb pairs',
                  '$pairs pairs · が and を',
                  () => _open(
                      QuietRoomDrillsWidget.routeName, {'mode': 'pairs'})),
              _row(
                  t,
                  'Numbers and counters',
                  'Counters, dates, months, lengths of time',
                  () => _open(
                      QuietRoomDrillsWidget.routeName, {'mode': 'reference'})),
              _row(t, 'Vocabulary', 'Minna no Nihongo · 620 words',
                  () => _open(QuietRoomLessonWidget.routeName)),
              _studyRecordLink(t),
            ],
          ],
        );
      }),
    );
  }

  // ───────────── finding: search and sort by use, over the extraction catalog ─────────────
  //
  // The catalog (pipeline/jp/catalog.py) gives every item a type and its uses at
  // extraction time, so this screen never guesses what a piece of content is. Each
  // data file has an entry too (type source_file), and every entry lists the data
  // files it came from (`from`), so searching a file's name finds the file and its items.

  Widget _search(QuietRoomTokens t) => TextField(
        controller: _searchBox,
        onChanged: (v) => setState(() => _query = v.trim()),
        style: qrText(t, size: 15),
        cursorColor: t.brand600,
        decoration: InputDecoration(
          hintText: 'Search everything: advice, ので, 本, open',
          hintStyle: qrText(t, size: 15, color: t.inkSubtle),
          prefixIcon: Icon(Icons.search, size: 20, color: t.inkMuted),
          filled: true,
          fillColor: t.surface,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: t.border, width: 1),
            borderRadius: BorderRadius.circular(QuietRoomMetrics.radiusSm),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
                color: t.borderFocus, width: QuietRoomMetrics.strokeFocus),
            borderRadius: BorderRadius.circular(QuietRoomMetrics.radiusSm),
          ),
        ),
      );

  /// What do you want to say? One row of uses. Tapping one sorts everything by it.
  Widget _useStrip(QuietRoomTokens t, Map<String, dynamic> doc) {
    final uses =
        ((doc['uses'] as List?) ?? const []).cast<Map<String, dynamic>>();
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: uses.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, i) => QrPill(
          label: uses[i]['label'] as String,
          on: _use == uses[i]['id'],
          solid: false,
          onTap: () => setState(() =>
              _use = _use == uses[i]['id'] ? null : uses[i]['id'] as String),
        ),
      ),
    );
  }

  List<Widget> _results(QuietRoomTokens t, Map<String, dynamic> doc) {
    final entries =
        ((doc['catalog'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final types =
        ((doc['types'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final typeOrder = {
      for (var i = 0; i < types.length; i++) types[i]['id']: i
    };
    final typeName = {for (final x in types) x['id']: x['label'] as String};
    final useName = {
      for (final u
          in ((doc['uses'] as List?) ?? const []).cast<Map<String, dynamic>>())
        u['id']: u['label'] as String
    };
    final q = _query.toLowerCase();
    bool hit(Map<String, dynamic> e) {
      if (_use != null && !(e['uses'] as List).contains(_use)) return false;
      if (q.isEmpty) return true;
      final hay = [
        e['title'],
        e['summary'],
        typeName[e['type']],
        ...(e['search'] as List? ?? const []),
        ...(e['from'] as List? ?? const []),
        for (final u in (e['uses'] as List)) useName[u],
      ];
      return hay.any((h) => (h ?? '').toString().toLowerCase().contains(q));
    }

    final found = entries.where(hit).toList()
      ..sort((a, b) {
        final byType =
            (typeOrder[a['type']] ?? 99).compareTo(typeOrder[b['type']] ?? 99);
        return byType != 0
            ? byType
            : ((a['lesson'] ?? 0) as int).compareTo((b['lesson'] ?? 0) as int);
      });
    if (found.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Center(
              child: Text('Nothing matches that.',
                  style: qrText(t, color: t.inkMuted))),
        ),
      ];
    }
    return [
      Text('${found.length} found',
          style: qrText(t, size: 12.5, color: t.inkMuted)),
      const SizedBox(height: 8),
      for (final e in found)
        Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: QrCard(
            onTap: () => _openEntry(e),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        [
                          typeName[e['type']] ?? e['type'],
                          if (e['lesson'] != null) '第${e['lesson']}課'
                        ].join(' · '),
                        style: qrText(t,
                            size: 11.5,
                            weight: FontWeight.w600,
                            color: t.sage700),
                      ),
                      const SizedBox(height: 3),
                      Text(e['title'] as String,
                          style: qrText(t,
                              size: 15.5,
                              weight: FontWeight.w600,
                              color: t.inkStrong)),
                      if ((e['summary'] as String? ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(e['summary'] as String,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: qrText(t, size: 12.5, color: t.inkMuted)),
                      ],
                    ]),
              ),
              Icon(Icons.chevron_right, size: 18, color: t.brand600),
            ]),
          ),
        ),
    ];
  }

  void _openEntry(Map<String, dynamic> e) {
    final o = (e['open'] as Map).cast<String, dynamic>();
    switch (o['screen']) {
      case 'grammar':
        _open(QuietRoomGrammarWidget.routeName, {
          if (o['lesson'] != null)
            'lesson': serializeParam(o['lesson'], ParamType.int),
          if (o['query'] != null) 'query': o['query'],
        });
      case 'reference':
        _open(QuietRoomDrillsWidget.routeName,
            {'mode': 'reference', 'table': o['table']});
      case 'pairs':
        _open(QuietRoomDrillsWidget.routeName, {'mode': 'pairs'});
      case 'conjugation':
        _open(QuietRoomDrillsWidget.routeName,
            {'mode': 'conjugation', 'form': o['form']});
      case 'vocabulary':
        _open(QuietRoomLessonWidget.routeName,
            {'lesson': serializeParam(o['lesson'], ParamType.int)});
      case 'search': // a data file: show everything that came from it
        _searchFor(o['query'] as String);
    }
  }

  Widget _hero(QuietRoomTokens t, Map<String, dynamic> lesson, int points) {
    final title = lesson['title'] as String? ?? '';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(QuietRoomMetrics.radiusMd),
        onTap: () => _open(QuietRoomGrammarWidget.routeName,
            {'lesson': serializeParam(lesson['lesson'], ParamType.int)}),
        child: Container(
          decoration: BoxDecoration(
            color: t.heroFill,
            borderRadius: BorderRadius.circular(QuietRoomMetrics.radiusMd),
          ),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_last == null ? 'START HERE' : 'CONTINUE',
                  style: qrText(t,
                          size: 11,
                          weight: FontWeight.w600,
                          color: t.heroInkMuted)
                      .copyWith(letterSpacing: 11 * 0.08)),
              const SizedBox(height: 8),
              Text('第${lesson['lesson']}課',
                  style: qrTitle(t, size: 28).copyWith(color: t.heroInk)),
              if (title.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(title, style: qrText(t, size: 15, color: t.heroInk)),
              ],
              const SizedBox(height: 14),
              Row(children: [
                Text('$points grammar points',
                    style: qrText(t, size: 13, color: t.heroInkMuted)),
                const Spacer(),
                Icon(Icons.arrow_forward, size: 20, color: t.heroInk),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  /// The Today card (Task 20): the day's queue and Start or Resume, or the end state.
  Widget _todayCard(QuietRoomTokens t) {
    final launch = _launch;
    final label = Text('TODAY',
        style: qrText(t, size: 11, weight: FontWeight.w600, color: t.sage700)
            .copyWith(letterSpacing: 11 * 0.08));
    if (launch == null || launch.plan == null) {
      return QrCard(
        key: const ValueKey('today-card'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          label,
          const SizedBox(height: 6),
          Text("Could not load today's plan: $_launchError",
              style: qrText(t, color: t.clay600)),
        ]),
      );
    }
    final plan = launch.plan!;
    final done = launch.decision == LaunchDecision.done;
    final position = launch.record?.position ?? 0;
    final queue = todaySectionsLine(plan);
    return QrCard(
      key: const ValueKey('today-card'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        label,
        const SizedBox(height: 6),
        if (done) ...[
          Text(kDoneForToday, style: qrTitle(t, size: 22)),
          const SizedBox(height: 4),
          Text(kDoneComeBack, style: qrText(t, color: t.inkMuted)),
        ] else ...[
          Text(queue.isEmpty ? 'Nothing is due today.' : queue,
              style: qrText(t,
                  size: 15.5, weight: FontWeight.w600, color: t.inkStrong)),
          if (queue.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(todayMinutesLine(plan),
                style: qrText(t, size: 13, color: t.inkMuted)),
            if (position > 0) ...[
              const SizedBox(height: 2),
              Text('$position of ${plan.entries.length} answered',
                  style: qrText(t, size: 13, color: t.inkMuted)),
            ],
            const SizedBox(height: 12),
            QrLoudButton(
                label: position > 0 ? 'Resume' : 'Start',
                onPressed: _startSession),
          ],
        ],
      ]),
    );
  }

  /// The quiet way to the study record debug page (Task 13): a plain text link, last.
  Widget _studyRecordLink(QuietRoomTokens t) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Center(
          child: TextButton(
            onPressed: () => _open(MasteryDebugWidget.routeName),
            child: Text('Study record',
                style: qrText(t, size: 12.5, color: t.inkSubtle)),
          ),
        ),
      );

  Widget _row(
          QuietRoomTokens t, String title, String sub, VoidCallback onTap) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: QrCard(
          onTap: onTap,
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: qrText(t,
                            size: 15.5,
                            weight: FontWeight.w600,
                            color: t.inkStrong)),
                    const SizedBox(height: 3),
                    Text(sub, style: qrText(t, size: 12.5, color: t.inkMuted)),
                  ]),
            ),
            Icon(Icons.chevron_right, size: 18, color: t.brand600),
          ]),
        ),
      );
}
