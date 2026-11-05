// The synthetic learner and the day loop behind test/srs_simulation_test.dart (Task 16).
//
// The learner answers the real catalog's items through their real probes and templates. Its
// chance of a clear is 85% while the item is retrievable (FSRS retrievability at or above
// 0.85); below that the chance is the retrievability itself. An item with no FSRS state (New,
// or seeded and not yet answered) is cleared 68% of the time, the Python reference's
// first-sight rate (sim_queue.py, 0.85 x 0.8). A miss is hinted 45% of the time and wrong 55%.
//
// The day loop is the app's, with nothing stubbed: `buildPlan` builds the day's plan from a
// `JpStoreMemory`; the plan is stored as the day's `DayRecord` (keep-sharp reads the week's
// plans); the session walks the entries in order and records every answer through
// `JpStore.recordAnswer` (the FSRS scheduler and the mastery rule); a wrong is re-asked through
// `DayPlan.afterWrong`; the session ends before an answer that would pass the ceiling and leaves
// the rest due tomorrow (PIN-5). The learner always taps Keep going at the soft stop, never
// takes the opt-in catch-up, and takes the stretch only in the stretch run, only when the end
// card would offer it: the plan's `stretchOffer`, every entry answered, and room under the
// ceiling.
//
// 🚨 THE ANSWER CARRIES THE ENTRY'S `wasDue`, as the Review session writes it (Task 18). The plan
// stamps it (operator ruling ASK-6): a New or stretch entry is due, because the session that asks
// it is the item's scheduled introduction, so its clear is the first of the four; a re-ask from
// `DayPlan.afterWrong` is not due, because the wrong before it scheduled the item for tomorrow at
// the earliest (`srsAfter`, D11), so its clear starts no run of counting clears (End state 2).
// Measured on 2026-11-04 before the ruling, writing New entries as not due mastered 145 items
// by day 120 in run A instead of 393, under End state 8's 200. test/srs_simulation_test.dart
// holds both stamps by value.

import 'dart:math' as math;

import 'package:habit_craft/components/pages/quiet_room_mastery/attempt.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/fsrs.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/item_catalog.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_memory.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/local_day.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/mastery_rule.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/plan_builder.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/scheduler.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/seed.dart';

/// The learner's clear rate while an item is retrievable.
const double kLearnerClear = 0.85;

/// The retrievability at or above which an item counts as retrievable.
const double kLearnerRetrievable = 0.85;

/// The clear rate on an item with no FSRS state (sim_queue.py: 0.85 x 0.8).
const double kLearnerFirstSight = 0.68;

/// The share of misses that are hinted; the rest are wrong.
const double kLearnerHintedShare = 0.45;

/// The answer the learner gives, before it is graded.
enum LearnerAnswer { clear, hinted, wrong }

/// A learner that answers by its rates, from one seeded random source.
class SyntheticLearner {
  SyntheticLearner(int seed) : _rng = math.Random(seed);

  final math.Random _rng;

  /// The chance of a clear on an item with [retrievability] (null: no FSRS state).
  static double clearChance(double? retrievability) {
    if (retrievability == null) return kLearnerFirstSight;
    if (retrievability >= kLearnerRetrievable) return kLearnerClear;
    return retrievability;
  }

  LearnerAnswer answer(double? retrievability) {
    final p = clearChance(retrievability);
    final x = _rng.nextDouble();
    if (x < p) return LearnerAnswer.clear;
    if (x < p + (1 - p) * kLearnerHintedShare) return LearnerAnswer.hinted;
    return LearnerAnswer.wrong;
  }
}

/// The scored probe asked on an item's [n]th scored answer: the probes in turn, so an item
/// meets its templates and its transfer probes the way a session that rotates them would.
ProbeDef probeFor(ItemDef item, int n) {
  final probes = item.scoredProbes.toList();
  return probes[n % probes.length];
}

/// The grade of [answer] on [probe], through the app's own `gradeAnswer` (D17, PIN-13): a
/// hinted answer is right after a hint below the revealing level.
Grade gradeOf(LearnerAnswer answer, ProbeDef probe) => switch (answer) {
      LearnerAnswer.clear =>
        gradeAnswer(outcome: Outcome.right, selfGraded: probe.selfGraded),
      LearnerAnswer.hinted => gradeAnswer(
          outcome: Outcome.right, selfGraded: probe.selfGraded, hintLevel: 1),
      LearnerAnswer.wrong =>
        gradeAnswer(outcome: Outcome.wrong, selfGraded: probe.selfGraded),
    };

/// How one run starts and what the learner does.
class SimConfig {
  const SimConfig({
    required this.label,
    this.days = 120,
    this.breakDays = const {},
    this.seeded = false,
    this.takeStretch = false,
    this.randomSeed = 7,
  });

  final String label;
  final int days;

  /// Simulation days (0-based) with no session.
  final Set<int> breakDays;

  /// Whether `seedFromLessons` runs on day 0 with the default ticked lessons.
  final bool seeded;

  /// Whether the learner takes the "4 more new" stretch whenever the end card offers it.
  final bool takeStretch;

  final int randomSeed;
}

/// One simulated day.
class SimDay {
  SimDay({required this.day, this.onBreak = false});

  /// The simulation day, 0-based.
  final int day;
  final bool onBreak;
  int answers = 0;
  int seconds = 0;
  int plannedSeconds = 0;
  int repairs = 0;
  int due = 0;
  int keepSharp = 0;
  int newItems = 0;
  int stretch = 0;
  int reasks = 0;
  bool returnMode = false;
  bool hitCeiling = false;
  NewSkip newSkip = NewSkip.none;

  /// The plan's `stretchOffer`, and whether the end card offered it.
  bool planStretchOffer = false;
  bool stretchOffered = false;

  /// The plan offered the stretch while a due item or a repair stayed out of it.
  bool stretchWithWorkLeft = false;

  /// Items due on or before today before the session, and after it (the backlog left behind).
  int backlogBefore = 0;
  int backlogAfter = 0;
  int mastered = 0;
  int learning = 0;
  int shaky = 0;
}

/// A finished run: its days and its mastery dates.
class SimRun {
  SimRun(this.config, this.days, this.masteredOn, this.kindOf);

  final SimConfig config;
  final List<SimDay> days;

  /// Item id to the simulation day it was first Mastered.
  final Map<String, int> masteredOn;
  final Map<String, ItemKind> kindOf;

  Iterable<SimDay> get active => days.where((d) => !d.onBreak);

  double get meanSeconds =>
      active.fold<int>(0, (s, d) => s + d.seconds) / active.length;
  double get meanAnswers =>
      active.fold<int>(0, (s, d) => s + d.answers) / active.length;
  int get peakSeconds => days.map((d) => d.seconds).reduce(math.max);
  int get peakAnswers => days.map((d) => d.answers).reduce(math.max);
  int get peakPlannedSeconds =>
      days.map((d) => d.plannedSeconds).reduce(math.max);
  int get peakBacklog => days.map((d) => d.backlogAfter).reduce(math.max);
  int get masteredEnd => days.last.mastered;

  /// The first day an item was Mastered, or null.
  int? get firstMasteredDay =>
      masteredOn.isEmpty ? null : masteredOn.values.reduce(math.min);

  int? get medianMasteredDay {
    if (masteredOn.isEmpty) return null;
    final sorted = masteredOn.values.toList()..sort();
    return sorted[sorted.length ~/ 2];
  }

  /// The last active day whose session left a due item behind, or null.
  int? get lastBacklogDay {
    int? last;
    for (final d in active) {
      if (d.backlogAfter > 0) last = d.day;
    }
    return last;
  }

  int get daysOverTarget =>
      active.where((d) => d.seconds > kTargetSeconds).length;
  int get daysAtCeiling => active.where((d) => d.hitCeiling).length;
  int get stretchOfferedDays => days.where((d) => d.stretchOffered).length;
  int get stretchTaken => days.fold<int>(0, (s, d) => s + d.stretch);

  /// Items ever Mastered during the run, by kind (from `masteredOn`, so an item that later
  /// went Shaky still counts here but not in [masteredEnd]).
  Map<ItemKind, int> get masteredByKind {
    final out = {for (final k in ItemKind.values) k: 0};
    for (final id in masteredOn.keys) {
      out[kindOf[id]!] = out[kindOf[id]!]! + 1;
    }
    return out;
  }

  /// The run's summary line, the numbers the plan's Context quotes.
  String summary() {
    final kinds = masteredByKind.entries
        .map((e) => '${e.key.name} ${e.value}')
        .join(', ');
    return 'Run ${config.label}: mean ${meanAnswers.toStringAsFixed(1)} answers '
        '(${(meanSeconds / 60).toStringAsFixed(1)} min) a day, peak $peakAnswers answers '
        '(${(peakSeconds / 60).toStringAsFixed(1)} min), $daysOverTarget days over the '
        'target, $daysAtCeiling at the ceiling, peak backlog $peakBacklog, last day with a '
        'backlog ${lastBacklogDay ?? 'none'}, first Mastered on day '
        '${firstMasteredDay ?? 'none'}, median ${medianMasteredDay ?? 'none'}, '
        '$masteredEnd Mastered on day ${config.days}, ever Mastered by kind: ($kinds), '
        'stretch offered on '
        '$stretchOfferedDays days, $stretchTaken stretch items taken';
  }

  /// A 10-day table of the run, for re-measuring by eye.
  String table() {
    final b = StringBuffer('day  rep due keep new str | answers  sec backlog | '
        'mastered learning shaky\n');
    for (final d in days) {
      if (d.day % 10 != 0 && d.day != days.length - 1) continue;
      String p(int v, int w) => v.toString().padLeft(w);
      b.writeln('${p(d.day, 3)}  ${p(d.repairs, 3)} ${p(d.due, 3)} '
          '${p(d.keepSharp, 4)} ${p(d.newItems, 3)} ${p(d.stretch, 3)} | '
          '${p(d.answers, 7)} ${p(d.seconds, 4)} ${p(d.backlogAfter, 7)} | '
          '${p(d.mastered, 8)} ${p(d.learning, 8)} ${p(d.shaky, 5)}'
          '${d.onBreak ? '  (break)' : ''}${d.returnMode ? '  (return)' : ''}');
    }
    return b.toString();
  }
}

/// The local day simulation day 0 falls on.
const int kSimFirstDay = 300;

/// Runs one 120-day simulation against [catalog].
Future<SimRun> simulate(SimConfig config, ItemCatalog catalog,
    {Scheduler scheduler = const FsrsScheduler()}) async {
  final store = JpStoreMemory();
  final learner = SyntheticLearner(config.randomSeed);
  final clock =
      FixedClock(dayStart(kSimFirstDay).add(const Duration(hours: 4)));
  final scoredAnswers = <String, int>{};
  final masteredOn = <String, int>{};
  final days = <SimDay>[];
  int? lastSession;

  if (config.seeded) {
    await seedFromLessons(kSimFirstDay, store, catalog,
        nowUtc: clock.now().toUtc());
  }

  for (var sim = 0; sim < config.days; sim++) {
    final today = kSimFirstDay + sim;
    clock.set(dayStart(today).add(const Duration(hours: 4)));
    final record = SimDay(day: sim, onBreak: config.breakDays.contains(sim));
    days.add(record);
    if (record.onBreak) {
      await _tally(record, store, today, catalog);
      continue;
    }

    final daysMissed = lastSession == null ? 0 : today - lastSession - 1;
    var plan = await buildPlan(
      day: today,
      daysMissed: daysMissed,
      store: store,
      catalog: catalog,
      clock: clock,
      scheduler: scheduler,
    );
    await store.putDay(DayRecord(day: today, plan: plan.encode()));
    lastSession = today;
    record
      ..returnMode = plan.returnMode
      ..newSkip = plan.newSkip
      ..plannedSeconds = plan.plannedSeconds
      ..planStretchOffer = plan.stretchOffer;

    final dueBefore = await store.dueOnOrBefore(today);
    record.backlogBefore = dueBefore.length;
    if (plan.stretchOffer) {
      final planned = {for (final e in plan.entries) e.itemId};
      final yesterdaysWrongs = {
        for (final a in await store.attempts())
          if (a.localDay == today - 1 &&
              a.grade == Grade.wrong &&
              a.source != Source.sayIt)
            a.itemId
      };
      record.stretchWithWorkLeft = plan.dueLeft > 0 ||
          dueBefore.any((d) => !planned.contains(d.itemId)) ||
          yesterdaysWrongs.any((id) => !planned.contains(id));
    }

    var spent = 0;
    var tick = 0;
    // Answers one entry; returns null when it would pass the ceiling, else whether it was wrong.
    Future<bool?> ask(QueueEntry entry, {bool stretch = false}) async {
      if (spent + entry.costSeconds > kCeilingSeconds) return null;
      final item = catalog.byId(entry.itemId)!;
      final state = await store.srs(item.id);
      final r = state == null ? null : scheduler.retrievability(state, today);
      final n = scoredAnswers[item.id] ?? 0;
      final probe = probeFor(item, n);
      final grade = gradeOf(learner.answer(r), probe);
      final attempt = Attempt(
        itemId: item.id,
        probeId: probe.id,
        template: probe.template,
        production: probe.production,
        selfGraded: probe.selfGraded,
        atUtc: clock.now().add(Duration(seconds: tick++ * 15)).toUtc(),
        localDay: today,
        grade: grade,
        rating: fsrsRatingFor(grade),
        hintLevel: grade == Grade.hinted ? 1 : 0,
        wasDue: entry.wasDue,
        source: entry.source,
        durationMs: entry.costSeconds * 1000,
        sessionId: 'sim${config.label}-$today',
      );
      final outcome =
          await store.recordAnswer(attempt, item: item, scheduler: scheduler);
      scoredAnswers[item.id] = n + 1;
      if (outcome.mastery?.status == MasteryStatus.mastered) {
        masteredOn.putIfAbsent(item.id, () => sim);
      }
      spent += entry.costSeconds;
      record.answers++;
      if (stretch) {
        record.stretch++;
      } else if (entry.reask) {
        record.reasks++;
        record.repairs++;
      } else {
        switch (entry.section) {
          case PlanSection.warmUp:
          case PlanSection.due:
            record.due++;
          case PlanSection.repair:
            record.repairs++;
          case PlanSection.keepSharp:
            record.keepSharp++;
          case PlanSection.newItems:
            record.newItems++;
        }
      }
      return grade == Grade.wrong;
    }

    // The session: every entry in order, a wrong re-asked later, a hard stop at the ceiling.
    var finished = true;
    for (var i = 0; i < plan.entries.length; i++) {
      final wrong = await ask(plan.entries[i]);
      if (wrong == null) {
        finished = false;
        record.hitCeiling = true;
        break;
      }
      if (wrong) plan = plan.afterWrong(i);
    }

    // The end card offers the stretch only when the plan does, every entry was answered and
    // the ceiling leaves room for it (PIN-6).
    if (plan.stretchOffer && finished) {
      final stretchSeconds =
          plan.stretchEntries.fold<int>(0, (s, e) => s + e.costSeconds);
      record.stretchOffered = spent + stretchSeconds <= kCeilingSeconds;
      if (record.stretchOffered && config.takeStretch) {
        for (final entry in plan.stretchEntries) {
          if (await ask(entry, stretch: true) == null) break;
        }
      }
    }

    record.seconds = spent;
    await store
        .putDay(DayRecord(day: today, plan: plan.encode(), completed: true));
    await _tally(record, store, today, catalog);
  }

  return SimRun(
      config, days, masteredOn, {for (final i in catalog.items) i.id: i.kind});
}

Future<void> _tally(
    SimDay record, JpStore store, int today, ItemCatalog catalog) async {
  record.backlogAfter = [
    for (final d in await store.dueOnOrBefore(today))
      if (catalog.byId(d.itemId) != null) d
  ].length;
  for (final m in (await store.allMastery()).values) {
    switch (m.status) {
      case MasteryStatus.mastered:
        record.mastered++;
      case MasteryStatus.learning:
        record.learning++;
      case MasteryStatus.shaky:
        record.learning++;
        record.shaky++;
      case MasteryStatus.neu:
        break;
    }
  }
}
