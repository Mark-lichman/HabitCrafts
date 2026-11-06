// HAND-WRITTEN. Not FlutterFlow output, so S3 has nothing to adopt.
//
// The Welcome back screen (plan 2026-11-02, Task 20, D9, PIN-9). After two or more missed
// local days, `onLaunch` builds the return plan and the app opens here before Today: the
// days away, the items due, the days to catch up at the 15-minute target, New paused, the
// items now Shaky with the rule that wins them back, and one loud Start.
//
// 🚨 IT READS, NEVER WRITES. The screen reads the stored return plan and the record; it writes
// no attempt, no `SrsState` and no `MasteryState`. A break changes what the plan shows first,
// never an item (PIN-9). A Shaky badge here comes from a real wrong, never from the break.

import 'package:flutter/material.dart';

import '/flutter_flow/quiet_room.dart';
import '../quiet_room_grammar/jp_study_kit.dart';
import 'item_catalog.dart';
import 'jp_store.dart';
import 'jp_store_sqlite.dart' show sharedJpStore;
import 'local_day.dart';
import 'mastery_rule.dart';
import 'plan_builder.dart';
import 'relaunch.dart';
import 'review_page.dart';

/// What the Welcome back screen says.
class WelcomeBackSummary {
  const WelcomeBackSummary({
    required this.daysAway,
    required this.itemsDue,
    required this.catchUpDays,
    required this.newPaused,
    required this.shaky,
    required this.targetMinutes,
  });

  /// Local days with no session since the last one.
  final int daysAway;

  /// Items due today or earlier.
  final int itemsDue;

  /// Days of target-length sessions the backlog takes, at least 1.
  final int catchUpDays;

  /// The return plan holds no New entries.
  final bool newPaused;

  /// The titles of the items now Shaky, in catalog order.
  final List<String> shaky;

  /// The plan's daily target, in minutes.
  final int targetMinutes;
}

/// Reads [launch]'s return plan and the record into the screen's summary. Writes nothing.
Future<WelcomeBackSummary> welcomeBackSummary(
    Launch launch, JpStore store, ItemCatalog catalog) async {
  final plan = launch.plan!;
  final due = await store.dueOnOrBefore(launch.day);
  final mastery = await store.allMastery();
  final target = plan.targetSeconds < 1 ? 1 : plan.targetSeconds;
  final days = (plan.backlogSeconds + target - 1) ~/ target;
  return WelcomeBackSummary(
    daysAway: launch.daysMissed,
    itemsDue: due.length,
    catchUpDays: days < 1 ? 1 : days,
    newPaused: plan.section(PlanSection.newItems).isEmpty,
    shaky: [
      for (final i in catalog.items)
        if (mastery[i.id]?.status == MasteryStatus.shaky) i.title
    ],
    targetMinutes: plan.targetSeconds ~/ 60,
  );
}

/// The regain rule in the learner's words, from the rule's constants (D16).
String regainRuleLine() =>
    'Two clear answers on two days, $kRegainGapDays or more days apart, win each one back.';

String _plural(int n, String one) => n == 1 ? '1 $one' : '$n ${one}s';

class WelcomeBackWidget extends StatefulWidget {
  const WelcomeBackWidget({
    super.key,
    this.launch,
    this.store,
    this.catalog,
    this.clock = const SystemClock(),
    this.onStart,
    this.onLater,
  });

  static String routeName = 'quietRoomWelcomeBack';
  static String routePath = '/quietRoomWelcomeBack';

  /// Today's launch. Null runs `onLaunch` here.
  final Launch? launch;

  /// Null uses the app's one shared store (`sharedJpStore`).
  final JpStore? store;

  /// Null loads the shipped catalog.
  final ItemCatalog? catalog;
  final Clock clock;

  /// Start. Null opens the Review session.
  final VoidCallback? onStart;

  /// The quiet way past the screen to Today. Null hides it.
  final VoidCallback? onLater;

  @override
  State<WelcomeBackWidget> createState() => _WelcomeBackWidgetState();
}

class _WelcomeBackWidgetState extends State<WelcomeBackWidget> {
  JpStore? _store;
  ItemCatalog? _catalog;
  WelcomeBackSummary? _summary;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final store = _store ??= widget.store ?? await sharedJpStore();
      final catalog = _catalog ??= widget.catalog ?? await ItemCatalog.load();
      final launch =
          widget.launch ?? await onLaunch(widget.clock.now(), store, catalog);
      if (launch.plan == null) {
        throw StateError('no plan for today (${launch.decision.name})');
      }
      final summary = await welcomeBackSummary(launch, store, catalog);
      if (mounted) setState(() => _summary = summary);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _start() {
    final onStart = widget.onStart;
    if (onStart != null) {
      onStart();
    } else {
      openReviewSession(context,
          store: _store, catalog: _catalog, clock: widget.clock);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = QuietRoomTokens.of(context);
    final s = _summary;
    if (s == null) {
      return QrStudyScaffold(
          showBack: false,
          child:
              qrLoadingOr(context, _error, 'Could not load the return plan:'));
    }
    Widget line(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(text, style: qrText(t, size: 15)),
        );
    return QrStudyScaffold(
      showBack: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
        children: [
          Text('Welcome back', style: qrTitle(t, size: 30)),
          const SizedBox(height: 14),
          line('You were away ${_plural(s.daysAway, 'day')}.'),
          line('${_plural(s.itemsDue, 'item')} due.'),
          line('About ${_plural(s.catchUpDays, 'day')} to catch up at '
              '${s.targetMinutes} minutes a day.'),
          if (s.newPaused)
            line('New items are paused until the backlog is down.'),
          const SizedBox(height: 4),
          Text(
              'Nothing you learned was reset. Today starts with a warm-up '
              'of things you likely still know.',
              style: qrText(t, color: t.inkMuted)),
          if (s.shaky.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('Now Shaky',
                style: qrText(t,
                    size: 13, weight: FontWeight.w600, color: t.amber700)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final title in s.shaky)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: t.amberSurface,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(title,
                        style: qrText(t, size: 13, color: t.amber700)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(regainRuleLine(),
                style: qrText(t, size: 13, color: t.inkMuted)),
          ],
          const SizedBox(height: 24),
          QrLoudButton(label: 'Start', onPressed: _start),
          if (widget.onLater != null)
            Center(
              child: TextButton(
                onPressed: widget.onLater,
                child: Text('Not now',
                    style: qrText(t, size: 12.5, color: t.inkSubtle)),
              ),
            ),
        ],
      ),
    );
  }
}
