import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class RemindersRecord extends FirestoreRecord {
  RemindersRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "days" field.
  List<String>? _days;
  List<String> get days => _days ?? const [];
  bool hasDays() => _days != null;

  // "time" field.
  DateTime? _time;
  DateTime? get time => _time;
  bool hasTime() => _time != null;

  // "user" field.
  DocumentReference? _user;
  DocumentReference? get user => _user;
  bool hasUser() => _user != null;

  // "habit" field.
  DocumentReference? _habit;
  DocumentReference? get habit => _habit;
  bool hasHabit() => _habit != null;

  // "hour" field.
  int? _hour;
  int get hour => _hour ?? 0;
  bool hasHour() => _hour != null;

  // "minute" field.
  int? _minute;
  int get minute => _minute ?? 0;
  bool hasMinute() => _minute != null;

  // "timezone_offset" field.
  int? _timezoneOffset;
  int get timezoneOffset => _timezoneOffset ?? 0;
  bool hasTimezoneOffset() => _timezoneOffset != null;

  // "group" field.
  DocumentReference? _group;
  DocumentReference? get group => _group;
  bool hasGroup() => _group != null;

  // "hour_local" field.
  int? _hourLocal;
  int get hourLocal => _hourLocal ?? 0;
  bool hasHourLocal() => _hourLocal != null;

  // "minute_local" field.
  int? _minuteLocal;
  int get minuteLocal => _minuteLocal ?? 0;
  bool hasMinuteLocal() => _minuteLocal != null;

  void _initializeFields() {
    _days = getDataList(snapshotData['days']);
    _time = snapshotData['time'] as DateTime?;
    _user = snapshotData['user'] as DocumentReference?;
    _habit = snapshotData['habit'] as DocumentReference?;
    _hour = castToType<int>(snapshotData['hour']);
    _minute = castToType<int>(snapshotData['minute']);
    _timezoneOffset = castToType<int>(snapshotData['timezone_offset']);
    _group = snapshotData['group'] as DocumentReference?;
    _hourLocal = castToType<int>(snapshotData['hour_local']);
    _minuteLocal = castToType<int>(snapshotData['minute_local']);
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('reminders');

  static Stream<RemindersRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => RemindersRecord.fromSnapshot(s));

  static Future<RemindersRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => RemindersRecord.fromSnapshot(s));

  static RemindersRecord fromSnapshot(DocumentSnapshot snapshot) =>
      RemindersRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static RemindersRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      RemindersRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'RemindersRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is RemindersRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createRemindersRecordData({
  DateTime? time,
  DocumentReference? user,
  DocumentReference? habit,
  int? hour,
  int? minute,
  int? timezoneOffset,
  DocumentReference? group,
  int? hourLocal,
  int? minuteLocal,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'time': time,
      'user': user,
      'habit': habit,
      'hour': hour,
      'minute': minute,
      'timezone_offset': timezoneOffset,
      'group': group,
      'hour_local': hourLocal,
      'minute_local': minuteLocal,
    }.withoutNulls,
  );

  return firestoreData;
}

class RemindersRecordDocumentEquality implements Equality<RemindersRecord> {
  const RemindersRecordDocumentEquality();

  @override
  bool equals(RemindersRecord? e1, RemindersRecord? e2) {
    const listEquality = ListEquality();
    return listEquality.equals(e1?.days, e2?.days) &&
        e1?.time == e2?.time &&
        e1?.user == e2?.user &&
        e1?.habit == e2?.habit &&
        e1?.hour == e2?.hour &&
        e1?.minute == e2?.minute &&
        e1?.timezoneOffset == e2?.timezoneOffset &&
        e1?.group == e2?.group &&
        e1?.hourLocal == e2?.hourLocal &&
        e1?.minuteLocal == e2?.minuteLocal;
  }

  @override
  int hash(RemindersRecord? e) => const ListEquality().hash([
        e?.days,
        e?.time,
        e?.user,
        e?.habit,
        e?.hour,
        e?.minute,
        e?.timezoneOffset,
        e?.group,
        e?.hourLocal,
        e?.minuteLocal
      ]);

  @override
  bool isValidKey(Object? o) => o is RemindersRecord;
}
