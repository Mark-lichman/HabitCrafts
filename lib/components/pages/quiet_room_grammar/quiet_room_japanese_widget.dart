// HAND-WRITTEN. Not FlutterFlow output, so S3 has nothing to adopt.
//
// The start screen of this build: Japanese study, no login. Mark asked for a
// single-user build (2026-10-24), so there is no account and nothing here reads
// Firestore. Everything comes from the bundled lesson files and the study record.
//
// The home is Today (plan 2026-11-02, Task 27, D20, End state 14). Quiet Room: one loud
// object, and on Today it is the session card. The screen holds:
//   * the session card: the plan's queue sections with their counts, the minutes line, and
//     Start or Resume; on a finished day, the end state;
//   * the mastered count, the kept rate over the last [kKeptRateDays] days, and the 14 dots
//     over the days whose session completed;
//   * quiet links: the conjugation, verb pair and number drills, the Discuss with Mari list
//     (discuss_list_widget.dart, plan 2026-11-06, Task 4, PIN-6) with its count, and the
//     study record page;
//   * a bottom nav of Today, Lessons (lessons_path_widget.dart) and Topics (topics_widget.dart).
// Search and the By use set live in Topics. The lesson numbers live in Lessons, so the home
// holds no number strip.
//
// The tabs switch with `go` under the app's router (`?tab=lessons`, `?tab=topics`), so the
// back stack never grows and each tab has a URL. Without a router (widget tests) the tab is
// local state.
//
// Before it builds, the screen resolves the launch (`onLaunch`, relaunch.dart, D9, PIN-9):
//   * firstLaunch: the seed confirmation (seed_confirm_widget.dart), then Today;
//   * welcomeBack: the Welcome back screen (welcome_back_widget.dart), then the session;
//   * today, resume and done: Today.
//
// The home is the app's home, so the OS keeps it warm overnight. The launch is resolved
// again when the app resumes on a later local day than the one it resolved, when a screen
// the home opened returns on a later day, and when the Today tab comes back on a later day:
// without that, a finished day's end card would stay up the next morning with no Start, and
// a return after a break would skip Welcome back. A resume behind a pushed screen waits for
// that screen to return, so a session under way across the 04:00 day change keeps its plan
// and tomorrow's is built after it.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '/flutter_flow/quiet_room.dart';
import '/components/pages/quiet_room_mastery/attempt.dart';
import '/components/pages/quiet_room_mastery/discuss_list_widget.dart';
import '/components/pages/quiet_room_mastery/item_catalog.dart';
import '/components/pages/quiet_room_mastery/jp_store.dart';
import '/components/pages/quiet_room_mastery/jp_store_sqlite.dart'
    show sharedJpStore;
import '/components/pages/quiet_room_mastery/lessons_path_widget.dart';
import '/components/pages/quiet_room_mastery/local_day.dart';
import '/components/pages/quiet_room_mastery/mastery_debug_widget.dart';
import '/components/pages/quiet_room_mastery/mastery_rule.dart';
import '/components/pages/quiet_room_mastery/plan_builder.dart';
import '/components/pages/quiet_room_mastery/relaunch.dart';
import '/components/pages/quiet_room_mastery/review_page.dart';
import '/components/pages/quiet_room_mastery/seed_confirm_widget.dart';
import '/components/pages/quiet_room_mastery/session_widget.dart'
    show sectionLabel;
import '/components/pages/quiet_room_mastery/topics_widget.dart';
import '/components/pages/quiet_room_mastery/welcome_back_widget.dart';
import '/components/pages/quiet_room_today/streak.dart' show recentDays;
import 'jp_study_kit.dart';
import 'quiet_room_drills_widget.dart';

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

/// The days the kept rate looks back over, today included.
const int kKeptRateDays = 30;

/// Days of dots on Today.
const int kHomeDots = 14;

/// The kept rate (A1): of the reviews of Mastered items in the window, the clear ones.
class KeptRate {
  const KeptRate({required this.kept, required this.reviews});

  final int kept;
  final int reviews;

  /// Null when the window holds no review of a Mastered item.
  double? get rate => reviews == 0 ? null : kept / reviews;
}

/// The kept rate over the [days] local days ending on [today], from the attempt log
/// [attempts] (oldest first). Pure.
///
/// Each item's attempts are replayed through the mastery rule (`masteryAfter`), so an attempt
/// counts exactly as the rule counts a kept review: a scored answer, not Say it and not early
/// practice, on an item that was Mastered before it (a maintenance or keep-sharp review). It
/// is kept when it is clear. An item [lookup] does not know is skipped.
KeptRate keptRateOf(List<Attempt> attempts, ItemLookup lookup, int today,
    {int days = kKeptRateDays}) {
  final states = <String, MasteryState>{};
  final from = today - days + 1;
  var kept = 0, reviews = 0;
  for (final a in attempts) {
    final item = lookup(a.itemId);
    if (item == null) continue;
    final before = states[a.itemId] ?? MasteryState.initial(a.itemId);
    final after = masteryAfter(before, a, item);
    states[a.itemId] = after;
    if (a.localDay < from || a.localDay > today) continue;
    reviews += after.keptReviews - before.keptReviews;
    kept += after.keptClear - before.keptClear;
  }
  return KeptRate(kept: kept, reviews: reviews);
}

/// The kept rate line: the share as a whole percent with its counts, or a plain line when
/// the window holds no review of a Mastered item.
String keptRateLine(KeptRate r) {
  final rate = r.rate;
  if (rate == null) {
    return 'Kept rate: no reviews of mastered items in the last $kKeptRateDays days';
  }
  return 'Kept rate ${(rate * 100).round()}% over $kKeptRateDays days '
      '· ${r.kept} of ${r.reviews}';
}

/// "12 mastered".
String masteredLine(int n) => '$n mastered';

/// The dots line: "5 of 14 days".
String dotsLine(List<bool> dots) =>
    '${dots.where((k) => k).length} of ${dots.length} days';

/// What Today shows under the session card, read from the store.
class HomeRecord {
  const HomeRecord(
      {required this.mastered,
      required this.kept,
      required this.dots,
      this.discuss = 0});

  final int mastered;
  final KeptRate kept;

  /// The Discuss marks on the list (PIN-6).
  final int discuss;

  /// The last [kHomeDots] days, oldest first: whether that day's session completed.
  final List<bool> dots;
}

/// Reads [HomeRecord] for [today] from [store]. Writes nothing.
Future<HomeRecord> loadHomeRecord(
    JpStore store, ItemLookup lookup, int today) async {
  final mastery = await store.allMastery();
  final mastered =
      mastery.values.where((m) => m.status == MasteryStatus.mastered).length;
  final kept = keptRateOf(await store.attempts(), lookup, today);
  final done = <DateTime>[];
  for (var d = today - kHomeDots + 1; d <= today; d++) {
    final record = await store.day(d);
    if (record != null && record.completed) done.add(dateOfDay(d));
  }
  return HomeRecord(
    mastered: mastered,
    kept: kept,
    dots: recentDays(done, today: dateOfDay(today), length: kHomeDots),
    discuss: (await store.discussMarks()).length,
  );
}

/// The home's three tabs.
enum HomeTab { today, lessons, topics }

/// The tab a `tab` query parameter names; Today for anything else.
HomeTab homeTabOf(String? name) => HomeTab.values
    .firstWhere((t) => t.name == name, orElse: () => HomeTab.today);

String homeTabLabel(HomeTab tab) => switch (tab) {
      HomeTab.today => 'Today',
      HomeTab.lessons => 'Lessons',
      HomeTab.topics => 'Topics',
    };

class QuietRoomJapaneseWidget extends StatefulWidget {
  const QuietRoomJapaneseWidget({
    super.key,
    this.store,
    this.catalog,
    this.clock = const SystemClock(),
    this.tab = HomeTab.today,
  });

  /// Null uses the app's one shared store (`sharedJpStore`).
  final JpStore? store;

  /// Null loads the shipped catalog.
  final ItemCatalog? catalog;
  final Clock clock;

  /// The tab shown. Under the router it comes from the `tab` query parameter.
  final HomeTab tab;

  static String routeName = 'quietRoomJapanese';
  static String routePath = '/quietRoomJapanese';

  @override
  State<QuietRoomJapaneseWidget> createState() =>
      _QuietRoomJapaneseWidgetState();
}

class _QuietRoomJapaneseWidgetState extends State<QuietRoomJapaneseWidget>
    with WidgetsBindingObserver {
  JpStore? _store;
  ItemCatalog? _catalog;
  Launch? _launch;
  Object? _launchError;
  HomeRecord? _record;
  late HomeTab _tab = widget.tab;

  /// "Not now" on Welcome back: the home for the rest of this visit.
  bool _pastWelcome = false;

  /// Only the latest launch resolution lands (a return from the session or a resume on a
  /// new day can overlap one).
  int _launchRun = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _relaunch();
  }

  @override
  void didUpdateWidget(QuietRoomJapaneseWidget old) {
    super.didUpdateWidget(old);
    // The build that follows shows the new tab, so no setState here.
    if (old.tab != widget.tab) {
      _tab = widget.tab;
      _refreshToday();
    }
  }

  /// A warm app resumed on a later local day resolves the launch again, so the home never
  /// keeps yesterday's card. Only resumed counts: inactive and hidden come with a
  /// permission dialog or the notification shade, and paused shows nothing.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Behind a pushed screen the home waits: `_open` and `_startSession` resolve the
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

  /// Resolves today's launch, then reads the record Today shows. Writes only today's
  /// `DayRecord`, through `onLaunch`.
  Future<void> _relaunch() async {
    final run = ++_launchRun;
    try {
      final store = _store ??= widget.store ?? await sharedJpStore();
      final catalog = _catalog ??= widget.catalog ?? await ItemCatalog.load();
      final launch = await onLaunch(widget.clock.now(), store, catalog);
      final record = await loadHomeRecord(store, catalog.byId, launch.day);
      if (mounted && run == _launchRun) {
        setState(() {
          _launch = launch;
          _record = record;
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
    super.dispose();
  }

  Future<void> _open(String route,
      [Map<String, dynamic> params = const {}]) async {
    await context.pushNamed(route, queryParameters: params);
    if (!mounted) return;
    _relaunchIfNewDay(); // the day may have moved while that screen was up
  }

  /// Opens the Discuss with Mari list, then reads Today again, so the link's count shows
  /// the marks cleared or set while the list was up.
  Future<void> _openDiscuss() async {
    await context.pushNamed(DiscussListWidget.routeName);
    if (!mounted) return;
    _refreshToday();
  }

  /// A tap on a tab: `go` under the router, so the URL names the tab and the stack stays
  /// flat; local state without one.
  ///
  /// The `go` keeps the path the home is already on. nav.dart serves the signed-out home
  /// at `/` and at [QuietRoomJapaneseWidget.routePath], and go_router keys a page by its
  /// matched path, so the same path with a new `tab` updates this State through
  /// `didUpdateWidget`. A `goNamed` from `/` would build a second page, drop this State
  /// with its `_pastWelcome`, and ask Welcome back again after Not now.
  ///
  /// The location comes from the router, not `GoRouterState.of`: nav.dart's `errorBuilder`
  /// serves this home too, for an unmatched URL, and go_router builds that error page
  /// outside its State registry, so `GoRouterState.of` would throw there. On the error
  /// page the `go` lands on `/`, a real route, and the tab shows from there.
  void _selectTab(HomeTab tab) {
    if (tab == _tab) return;
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      final here = router.routeInformationProvider.value.uri;
      final path =
          here.path == QuietRoomJapaneseWidget.routePath ? here.path : '/';
      context.go(Uri(
        path: path,
        queryParameters: tab == HomeTab.today ? null : {'tab': tab.name},
      ).toString());
      return;
    }
    setState(() => _tab = tab);
    _refreshToday();
  }

  /// Today again: the day may have moved while another tab was up, and the record may have,
  /// through a practice run from Lessons or Topics. `onLaunch` keeps a stored plan, so a
  /// same-day refresh builds no second plan.
  void _refreshToday() {
    final launch = _launch;
    if (_tab != HomeTab.today || launch == null) return;
    if (localDay(widget.clock.now()) != launch.day) {
      _relaunchIfNewDay();
    } else {
      _relaunch();
    }
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
    final t = QuietRoomTokens.of(context);
    final Widget body = switch (_tab) {
      HomeTab.today => QrStudyScaffold(showBack: false, child: _today(t)),
      HomeTab.lessons => LessonsPathWidget(
          key: const ValueKey('home-lessons'),
          store: widget.store,
          catalog: widget.catalog,
          clock: widget.clock,
          showBack: false,
        ),
      HomeTab.topics => QuietRoomTopicsWidget(
          key: const ValueKey('home-topics'),
          store: widget.store,
          catalog: widget.catalog,
          clock: widget.clock,
          showBack: false,
        ),
    };
    return Scaffold(
      backgroundColor: t.canvas,
      body: Column(children: [
        Expanded(child: body),
        _bottomNav(t),
      ]),
    );
  }

  Widget _today(QuietRoomTokens t) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
        children: [
          Text('日本語', style: qrTitle(t, size: 30)),
          const SizedBox(height: 16),
          _todayCard(t),
          const SizedBox(height: 18),
          if (_record != null) ..._recordLines(t, _record!),
          const SizedBox(height: 18),
          _quietLinks(t),
        ],
      );

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

  /// The mastered count, the kept rate and the 14 dots: quiet lines under the card.
  List<Widget> _recordLines(QuietRoomTokens t, HomeRecord r) => [
        Text(masteredLine(r.mastered),
            key: const ValueKey('home-mastered'),
            style: qrText(t,
                size: 15, weight: FontWeight.w600, color: t.inkStrong)),
        const SizedBox(height: 4),
        Text(keptRateLine(r.kept),
            key: const ValueKey('home-kept'),
            style: qrText(t, size: 13, color: t.inkMuted)),
        const SizedBox(height: 10),
        // Missed days are drawn small and faint: a miss is not a verdict.
        Row(key: const ValueKey('home-dots'), children: [
          for (final k in r.dots)
            Padding(
              padding: const EdgeInsets.only(right: 5),
              child: Container(
                width: k ? 9 : 5,
                height: k ? 9 : 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: k ? t.sage600 : t.border,
                ),
              ),
            ),
          const SizedBox(width: 6),
          Text(dotsLine(r.dots),
              style: qrText(t, size: 12.5, color: t.inkMuted)),
        ]),
      ];

  /// The drills, the Discuss with Mari list and the study record debug page (Task 13): plain
  /// text links, last.
  Widget _quietLinks(QuietRoomTokens t) {
    Widget link(String label, VoidCallback onTap) => TextButton(
          onPressed: onTap,
          child: Text(label, style: qrText(t, size: 12.5, color: t.inkSubtle)),
        );
    return Center(
      child: Wrap(alignment: WrapAlignment.center, spacing: 4, children: [
        link(
            'Conjugation',
            () => _open(
                QuietRoomDrillsWidget.routeName, {'mode': 'conjugation'})),
        link('Verb pairs',
            () => _open(QuietRoomDrillsWidget.routeName, {'mode': 'pairs'})),
        link(
            'Numbers and counters',
            () =>
                _open(QuietRoomDrillsWidget.routeName, {'mode': 'reference'})),
        link(discussLinkLabel(_record?.discuss ?? 0), _openDiscuss),
        link('Study record', () => _open(MasteryDebugWidget.routeName)),
      ]),
    );
  }

  Widget _bottomNav(QuietRoomTokens t) => Container(
        decoration: BoxDecoration(
          color: t.surface,
          border: Border(top: BorderSide(color: t.border, width: 1)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(t, HomeTab.today, Icons.home_outlined),
                _navItem(t, HomeTab.lessons, Icons.menu_book_outlined),
                _navItem(t, HomeTab.topics, Icons.search),
              ],
            ),
          ),
        ),
      );

  Widget _navItem(QuietRoomTokens t, HomeTab tab, IconData icon) {
    final active = tab == _tab;
    final c = active ? t.ink : t.inkMuted;
    return Semantics(
      selected: active,
      button: true,
      child: InkWell(
        key: ValueKey('tab-${tab.name}'),
        onTap: () => _selectTab(tab),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
              minWidth: QuietRoomMetrics.targetMin,
              minHeight: QuietRoomMetrics.targetMin),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: c),
                const SizedBox(height: 3),
                Text(homeTabLabel(tab),
                    style: qrText(t,
                        size: 11,
                        weight: active ? FontWeight.w600 : FontWeight.w500,
                        color: c)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
