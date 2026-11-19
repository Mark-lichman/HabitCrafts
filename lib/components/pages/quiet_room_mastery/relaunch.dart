// Relaunch (D9, PIN-9). `onLaunch` decides, before the first screen draws, what the app opens on.
//
//   * firstLaunch: the seed has never run (no `kSeedFlag`). The caller shows the seed
//     confirmation, runs `seedFromLessons` (seed.dart) and calls `onLaunch` again, which then
//     builds today's plan: first launch seeds, then plans.
//   * done: today already has a plan and its session is complete; the end card.
//   * resume: today already has a plan and its session is not complete.
//   * today: the last session was yesterday, two days ago with one day missed, or never (a seed
//     with no plan yet); today's plan is built and stored.
//   * welcomeBack: two or more local days were missed since the last session; the return plan
//     (warm-up, low-retrievability cap, New paused) is built and stored behind the Welcome back
//     screen. Relaunched the same day before its first answer, it shows Welcome back again.
//
// "The last session" is the latest local day whose `DayRecord` shows an answer (position above
// 0, or completed), and the days missed are the local days strictly between it and today
// (`localDay`, D15). A plan that was built but never answered is no session day (operator
// ruling ASK-5): a Welcome back left unanswered keeps return mode on the next launch.
//
// 🚨 NOTHING HERE RESETS AN ITEM. `onLaunch` reads the record and writes only today's
// `DayRecord`: no attempt, no `SrsState`, no `MasteryState`, however long the break. A return
// changes what the plan shows first, never an item's schedule or mastery (PIN-9).

import 'fsrs.dart';
import 'item_catalog.dart';
import 'jp_store.dart';
import 'local_day.dart';
import 'plan_builder.dart';
import 'scheduler.dart';
import 'seed.dart';

/// What the app opens on (D9).
enum LaunchDecision { firstLaunch, done, resume, today, welcomeBack }

/// The settings a launch builds its plan with.
class LaunchSettings {
  const LaunchSettings({
    this.budget = PlanBudget.standard,
    this.scheduler = const FsrsScheduler(),
  });

  final PlanBudget budget;
  final Scheduler scheduler;
}

/// The launch's decision and what the first screen needs.
class Launch {
  const Launch({
    required this.decision,
    required this.day,
    this.plan,
    this.record,
    this.daysMissed = 0,
  });

  final LaunchDecision decision;

  /// Today's local day.
  final int day;

  /// Today's plan; null on [LaunchDecision.firstLaunch].
  final DayPlan? plan;

  /// Today's stored record (position and completion); null on [LaunchDecision.firstLaunch].
  final DayRecord? record;

  /// Local days with no session since the last one.
  final int daysMissed;

  @override
  String toString() => 'Launch(${decision.name} on $day, missed $daysMissed)';
}

/// Decides what the app opens on at [now] (see the file comment). Writes only today's
/// `DayRecord`, and only when it builds today's plan.
Future<Launch> onLaunch(
  DateTime now,
  JpStore store,
  ItemCatalog catalog, [
  LaunchSettings settings = const LaunchSettings(),
]) async {
  final today = localDay(now);
  if (await store.meta(kSeedFlag) == null) {
    return Launch(decision: LaunchDecision.firstLaunch, day: today);
  }

  final record = await store.day(today);
  if (record != null) {
    final stored = _decode(record.plan);
    if (stored != null) {
      final decision = record.completed
          ? LaunchDecision.done
          : stored.returnMode && record.position == 0
              ? LaunchDecision.welcomeBack
              : LaunchDecision.resume;
      return Launch(
          decision: decision,
          day: today,
          plan: stored,
          record: record,
          daysMissed: stored.daysMissed);
    }
    // A record this build cannot read: today's plan is built again below. Its completion is
    // kept, so a finished session never reopens and never takes a second intake (PIN-6).
  }

  final last = await _lastSessionBefore(store, today);
  final daysMissed = last == null || last >= today ? 0 : today - last - 1;
  final plan = await buildPlan(
    day: today,
    budget: settings.budget,
    daysMissed: daysMissed,
    store: store,
    catalog: catalog,
    clock: FixedClock(now),
    scheduler: settings.scheduler,
  );
  final completed = record?.completed ?? false;
  final written =
      DayRecord(day: today, plan: plan.encode(), completed: completed);
  await store.putDay(written);
  return Launch(
    decision: completed
        ? LaunchDecision.done
        : plan.returnMode
            ? LaunchDecision.welcomeBack
            : LaunchDecision.today,
    day: today,
    plan: plan,
    record: written,
    daysMissed: daysMissed,
  );
}

DayPlan? _decode(String plan) {
  try {
    return DayPlan.decode(plan);
  } on Object {
    return null;
  }
}

/// Whether [record] shows an answer: a session day for the days missed (ASK-5).
bool _answered(DayRecord record) => record.answered;

/// The latest local day before [today] whose `DayRecord` shows an answer, walking back from
/// `store.lastDay()` (ASK-5); [today] when today's record exists or a later one does (the clock
/// moved back), which the caller counts as no day missed; or null when no record shows an
/// answer.
Future<int?> _lastSessionBefore(JpStore store, int today) async {
  final last = await store.lastDay();
  if (last == null) return null;
  // Today's record exists only when it did not decode; any later one is from a clock that
  // moved back. Neither counts as a day missed.
  if (last >= today) return today;
  // No record predates the seed (a plan needs it) and no answer predates the first attempt,
  // so the walk stops at the earlier of the two.
  final floor = await _earliestDay(store);
  if (floor == null) return null;
  for (var d = last; d >= floor; d--) {
    final record = await store.day(d);
    if (record != null && _answered(record)) return d;
  }
  return null;
}

/// The earliest local day of a seed or an attempt, or null when the log is empty.
Future<int?> _earliestDay(JpStore store) async {
  final seeds = await store.seeds();
  final attempts = await store.attempts();
  int? floor;
  for (final s in seeds) {
    final d = localDay(s.atUtc);
    if (floor == null || d < floor) floor = d;
  }
  for (final a in attempts) {
    if (floor == null || a.localDay < floor) floor = a.localDay;
  }
  return floor;
}
