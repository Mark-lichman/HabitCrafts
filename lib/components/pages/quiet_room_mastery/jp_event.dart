// One event of the Japanese study record, as two devices share it (plan 2026-11-19, Task 1,
// D3, PIN-3, PIN-12, PIN-16).
//
// Every logged event carries a global id, the id of the device that wrote it, and its event
// time. Row ids stay local to one store; the event id is the same on every device, so a merge of
// two logs drops a duplicate by id alone.
//
// Six kinds:
//   attempt      one answer (attempt.dart); the body is the attempt's JSON without ids
//   seed         one seeded item (jp_store.dart `SeedEvent`): itemId, dueDay, atUtc
//   note         a learner note set or cleared: itemId, note (null clears it)
//   discuss      a Discuss mark set or cleared: itemId, note (when set with one), cleared
//   speak_score  one say-it score; the body is the score log's own entry
//   last_lesson  the last grammar lesson opened: lessonId
// Attempts and seeds are the replayed log. The other four never reach the replay: a note, a
// Discuss mark and the last lesson resolve to the event with the latest event time, ties broken
// by the larger event id, so every device lands on the same value (last write wins).
//
// The Firestore map form (`toFirestore`) holds only JSON values, so this file needs no Firestore
// import and stays pure.

import 'dart:convert';
import 'dart:math';

/// The map form's own version, written as `v`.
const int kJpEventMapVersion = 1;

/// The subject every `last_lesson` event shares: there is one last lesson per learner.
const String kLastLessonSubject = 'last_lesson';

/// The six event kinds and their wire names.
enum JpEventKind {
  attempt('attempt'),
  seed('seed'),
  note('note'),
  discuss('discuss'),
  speakScore('speak_score'),
  lastLesson('last_lesson');

  const JpEventKind(this.wire);

  /// The name written to the map form and the export.
  final String wire;

  /// Throws a [FormatException] for a name no kind has.
  static JpEventKind fromWire(Object? wire) => values.firstWhere(
      (k) => k.wire == wire,
      orElse: () => throw FormatException('unknown event kind $wire'));

  /// Whether the replay reads this kind: attempts and seeds.
  bool get replayed => this == attempt || this == seed;
}

final Random _random = Random.secure();

/// A new global event id: a random (version 4) UUID.
String newEventId() {
  final b = List<int>.generate(16, (_) => _random.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final hex = [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// One event of the study record.
class JpEvent {
  JpEvent({
    required this.eventId,
    required this.deviceId,
    required DateTime atUtc,
    required this.kind,
    required Map<String, dynamic> body,
  })  : atUtc = atUtc.toUtc(),
        body = Map<String, dynamic>.unmodifiable(_plainMap(body));

  /// The global id, unique across devices.
  final String eventId;

  /// The device that wrote the event.
  final String deviceId;

  /// The event time. For an attempt or a seed it is the logged instant.
  final DateTime atUtc;
  final JpEventKind kind;

  /// The kind's own fields (see the file comment).
  final Map<String, dynamic> body;

  /// What a later event of the same kind replaces: the item for a note or a Discuss mark, the
  /// one [kLastLessonSubject] for the last lesson. Null for a say-it score, which replaces
  /// nothing. An attempt or a seed names its item but replaces nothing either.
  String? get subject => switch (kind) {
        JpEventKind.lastLesson => kLastLessonSubject,
        JpEventKind.speakScore => null,
        _ => body['itemId'] as String?,
      };

  /// The Firestore document form: JSON values only, the event time as UTC ISO 8601.
  Map<String, dynamic> toFirestore() => {
        'v': kJpEventMapVersion,
        'eventId': eventId,
        'deviceId': deviceId,
        'atUtc': atUtc.toIso8601String(),
        'kind': kind.wire,
        'body': _plainMap(body),
      };

  /// Reads [toFirestore]'s form. Throws a [FormatException] for a missing id or device, an
  /// unreadable time, an unknown kind or a body that is not a map. Fields it does not know,
  /// such as a server timestamp a remote adds, are ignored.
  factory JpEvent.fromFirestore(Map<String, dynamic> m) {
    final eventId = m['eventId'];
    final deviceId = m['deviceId'];
    final at = m['atUtc'];
    final body = m['body'];
    if (eventId is! String || eventId.isEmpty) {
      throw const FormatException('jp event: no eventId');
    }
    if (deviceId is! String || deviceId.isEmpty) {
      throw FormatException('jp event $eventId: no deviceId');
    }
    final atUtc = at is String ? DateTime.tryParse(at) : null;
    if (atUtc == null) {
      throw FormatException('jp event $eventId: unreadable atUtc $at');
    }
    if (body is! Map) {
      throw FormatException('jp event $eventId: the body is not a map');
    }
    return JpEvent(
      eventId: eventId,
      deviceId: deviceId,
      atUtc: atUtc,
      kind: JpEventKind.fromWire(m['kind']),
      body: _plainMap(body),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is JpEvent &&
      other.eventId == eventId &&
      other.deviceId == deviceId &&
      other.atUtc == atUtc &&
      other.kind == kind &&
      _canonical(other.body) == _canonical(body);

  @override
  int get hashCode =>
      Object.hash(eventId, deviceId, atUtc, kind, _canonical(body));

  @override
  String toString() => 'JpEvent(${kind.wire} $eventId ${atUtc.toIso8601String()}'
      '${subject == null ? '' : ' $subject'})';
}

/// The merge order: event time, then event id. Every device sorts a merged log the same way.
int compareEvents(JpEvent a, JpEvent b) {
  final byTime = a.atUtc.compareTo(b.atUtc);
  return byTime != 0 ? byTime : a.eventId.compareTo(b.eventId);
}

/// The last-write-wins event per subject among [events] of [kind]: the latest by
/// [compareEvents]. Pure.
Map<String, JpEvent> latestBySubject(
    Iterable<JpEvent> events, JpEventKind kind) {
  final out = <String, JpEvent>{};
  for (final e in events) {
    final s = e.subject;
    if (e.kind != kind || s == null) continue;
    final old = out[s];
    if (old == null || compareEvents(e, old) > 0) out[s] = e;
  }
  return out;
}

/// The last lesson opened, by the latest `last_lesson` event; null when there is none.
String? resolveLastLesson(Iterable<JpEvent> events) =>
    latestBySubject(events, JpEventKind.lastLesson)[kLastLessonSubject]
        ?.body['lessonId'] as String?;

/// [m] with every nested map typed `Map<String, dynamic>` and every list copied, so a map read
/// back from Firestore or JSON compares and encodes like the one written.
Map<String, dynamic> _plainMap(Map m) =>
    {for (final e in m.entries) e.key as String: _plain(e.value)};

Object? _plain(Object? v) {
  if (v is Map) return _plainMap(v);
  if (v is List) return [for (final x in v) _plain(x)];
  return v;
}

/// A JSON string of [v] with every map's keys sorted, for an order-free comparison.
String _canonical(Object? v) {
  Object? sorted(Object? x) {
    if (x is Map) {
      final keys = x.keys.map((k) => k as String).toList()..sort();
      return {for (final k in keys) k: sorted(x[k])};
    }
    if (x is List) return [for (final y in x) sorted(y)];
    return x;
  }

  return jsonEncode(sorted(v));
}
