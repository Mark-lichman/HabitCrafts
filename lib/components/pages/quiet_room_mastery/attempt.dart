// One answer on one probe of one mastery item, and the grade it earns (D17, D22).
//
// The attempt log is append-only and is the source of truth for the study record (D14): the
// scheduler state and the mastery state are both replays of it. Grades are the same on every
// screen:
//
// | grade    | when                                                           | FSRS rating |
// |----------|----------------------------------------------------------------|-------------|
// | clear    | right, no hint, nothing revealed (machine-checked), or Got it  | Good        |
// |          | after the reveal on a self-graded probe                        |             |
// | hinted   | right after a hint below the revealing level, a second try, a | Hard        |
// |          | speech `close`                                                 |             |
// | wrong    | wrong, Missed it, a hint at or above the revealing level, a   | Again       |
// |          | reveal on a machine-checked probe                              |             |
// | unscored | nothing heard, an error, a cancel                              | none        |
// | self     | the learner overrides a machine check (Got it on unverified)  | Hard        |
//
// 🚨 A HINTED ANSWER EARNS ZERO MASTERY CREDIT (PIN-3). Only `clear` counts toward the four
// clears; see [earnsMasteryCredit] and mastery_rule.dart.

/// The kinds of mastery item the record tracks (D1).
enum ItemKind { grammar, particle, word, conjugation, pair, tableRow }

/// The five grades of one attempt (D17).
enum Grade { clear, hinted, wrong, unscored, self }

/// Where the answer was given.
///
/// [review] is a queued review (due, repair or new), [keepSharp] the weekly set of Mastered items
/// (D10), [early] an answer on an item that is not due (D23, PIN-14), and [sayIt] the spoken
/// sentence track, which never counts toward mastery (D4).
enum Source { review, keepSharp, early, sayIt }

/// What the check (or the learner, on a self-graded probe) said about the answer itself.
///
/// [none] means nothing could be scored: nothing heard, an error, a cancel. It is never wrong.
enum Outcome { right, close, wrong, none }

/// FSRS ratings (D12). Easy is never used.
const int kRatingAgain = 1;
const int kRatingHard = 2;
const int kRatingGood = 3;

/// The FSRS rating a grade logs, or null when no review is logged (unscored).
int? fsrsRatingFor(Grade grade) {
  switch (grade) {
    case Grade.clear:
      return kRatingGood;
    case Grade.hinted:
    case Grade.self:
      return kRatingHard;
    case Grade.wrong:
      return kRatingAgain;
    case Grade.unscored:
      return null;
  }
}

/// Whether a grade can count toward the four clears. Hinted and self never do (PIN-3).
bool earnsMasteryCredit(Grade grade) => grade == Grade.clear;

/// Grades one answer (D17, D22, PIN-3, PIN-13).
///
/// [selfGraded] is true on a probe with no machine check (conjugation, pair, table cell, word
/// card): the learner thinks of the answer, reveals it and grades it, so [Outcome.right] is Got
/// it and [Outcome.wrong] is Missed it, and the reveal itself is expected. [hintLevel] is the
/// highest hint taken before answering; a level at or above [revealingHintLevel] showed the
/// answer, so it is wrong. On a machine-checked probe, [revealed] means "show the answer" was
/// used, which is wrong too. [secondTry] marks a right answer after a wrong one on the same
/// probe. [selfOverride] is the learner's Got it over a check that could not score.
Grade gradeAnswer({
  required Outcome outcome,
  required bool selfGraded,
  int hintLevel = 0,
  int? revealingHintLevel,
  bool revealed = false,
  bool secondTry = false,
  bool selfOverride = false,
}) {
  if (revealingHintLevel != null && hintLevel >= revealingHintLevel) {
    return Grade.wrong;
  }
  if (!selfGraded && revealed) return Grade.wrong;
  if (!selfGraded && selfOverride) return Grade.self;
  switch (outcome) {
    case Outcome.none:
      return Grade.unscored;
    case Outcome.wrong:
      return Grade.wrong;
    case Outcome.close:
      return Grade.hinted;
    case Outcome.right:
      return hintLevel > 0 || secondTry ? Grade.hinted : Grade.clear;
  }
}

/// One answer, as written to the append-only log.
class Attempt {
  const Attempt({
    this.id,
    required this.itemId,
    required this.probeId,
    required this.template,
    required this.production,
    required this.selfGraded,
    required this.atUtc,
    required this.localDay,
    required this.grade,
    required this.rating,
    this.hintLevel = 0,
    this.revealed = false,
    required this.wasDue,
    required this.source,
    this.elapsedDays,
    this.rBefore,
    this.rAfter,
    this.sBefore,
    this.sAfter,
    this.durationMs = 0,
    required this.sessionId,
  });

  /// The log's row id, assigned by the store; null before it is written.
  final int? id;
  final String itemId;

  /// The probe answered: a sentence, a verb, a cell, a direction or a recall mode.
  final String probeId;

  /// The question template of the probe (choose, typed, spoken, reveal, a direction).
  final String template;

  /// Whether the template is a production probe (typed, spoken, conjugate, build).
  final bool production;

  /// Whether the probe has no machine check, so the learner graded it (PIN-13).
  final bool selfGraded;
  final DateTime atUtc;

  /// The local day of [atUtc] (D15), stored so a later timezone change cannot move it.
  final int localDay;
  final Grade grade;

  /// The FSRS rating logged, or null for unscored.
  final int? rating;
  final int hintLevel;
  final bool revealed;

  /// Whether the item's scheduled day had arrived when it was answered.
  final bool wasDue;
  final Source source;
  final double? elapsedDays;
  final double? rBefore;
  final double? rAfter;
  final double? sBefore;
  final double? sAfter;
  final int durationMs;
  final String sessionId;

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'itemId': itemId,
        'probeId': probeId,
        'template': template,
        'production': production,
        'selfGraded': selfGraded,
        'atUtc': atUtc.toUtc().toIso8601String(),
        'localDay': localDay,
        'grade': grade.name,
        'rating': rating,
        'hintLevel': hintLevel,
        'revealed': revealed,
        'wasDue': wasDue,
        'source': source.name,
        'elapsedDays': elapsedDays,
        'rBefore': rBefore,
        'rAfter': rAfter,
        'sBefore': sBefore,
        'sAfter': sAfter,
        'durationMs': durationMs,
        'sessionId': sessionId,
      };

  factory Attempt.fromJson(Map<String, dynamic> j) => Attempt(
        id: j['id'] as int?,
        itemId: j['itemId'] as String,
        probeId: j['probeId'] as String,
        template: j['template'] as String,
        production: j['production'] as bool,
        selfGraded: j['selfGraded'] as bool,
        atUtc: DateTime.parse(j['atUtc'] as String).toUtc(),
        localDay: j['localDay'] as int,
        grade: Grade.values.byName(j['grade'] as String),
        rating: j['rating'] as int?,
        hintLevel: (j['hintLevel'] as int?) ?? 0,
        revealed: (j['revealed'] as bool?) ?? false,
        wasDue: j['wasDue'] as bool,
        source: Source.values.byName(j['source'] as String),
        elapsedDays: (j['elapsedDays'] as num?)?.toDouble(),
        rBefore: (j['rBefore'] as num?)?.toDouble(),
        rAfter: (j['rAfter'] as num?)?.toDouble(),
        sBefore: (j['sBefore'] as num?)?.toDouble(),
        sAfter: (j['sAfter'] as num?)?.toDouble(),
        durationMs: (j['durationMs'] as int?) ?? 0,
        sessionId: j['sessionId'] as String,
      );

  List<Object?> get _fields => [
        id,
        itemId,
        probeId,
        template,
        production,
        selfGraded,
        atUtc.toUtc(),
        localDay,
        grade,
        rating,
        hintLevel,
        revealed,
        wasDue,
        source,
        elapsedDays,
        rBefore,
        rAfter,
        sBefore,
        sAfter,
        durationMs,
        sessionId,
      ];

  @override
  bool operator ==(Object other) {
    if (other is! Attempt) return false;
    final a = _fields, b = other._fields;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_fields);

  @override
  String toString() =>
      'Attempt($itemId/$probeId day $localDay ${grade.name} ${source.name}'
      '${wasDue ? ' due' : ''})';
}
