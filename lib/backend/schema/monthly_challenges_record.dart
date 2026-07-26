import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class MonthlyChallengesRecord extends FirestoreRecord {
  MonthlyChallengesRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "webinars" field.
  List<DocumentReference>? _webinars;
  List<DocumentReference> get webinars => _webinars ?? const [];
  bool hasWebinars() => _webinars != null;

  // "title" field.
  String? _title;
  String get title => _title ?? '';
  bool hasTitle() => _title != null;

  // "description" field.
  String? _description;
  String get description => _description ?? '';
  bool hasDescription() => _description != null;

  // "start_time" field.
  DateTime? _startTime;
  DateTime? get startTime => _startTime;
  bool hasStartTime() => _startTime != null;

  // "expires_at" field.
  DateTime? _expiresAt;
  DateTime? get expiresAt => _expiresAt;
  bool hasExpiresAt() => _expiresAt != null;

  // "habits" field.
  List<DocumentReference>? _habits;
  List<DocumentReference> get habits => _habits ?? const [];
  bool hasHabits() => _habits != null;

  void _initializeFields() {
    _webinars = getDataList(snapshotData['webinars']);
    _title = snapshotData['title'] as String?;
    _description = snapshotData['description'] as String?;
    _startTime = snapshotData['start_time'] as DateTime?;
    _expiresAt = snapshotData['expires_at'] as DateTime?;
    _habits = getDataList(snapshotData['habits']);
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('monthly_challenges');

  static Stream<MonthlyChallengesRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => MonthlyChallengesRecord.fromSnapshot(s));

  static Future<MonthlyChallengesRecord> getDocumentOnce(
          DocumentReference ref) =>
      ref.get().then((s) => MonthlyChallengesRecord.fromSnapshot(s));

  static MonthlyChallengesRecord fromSnapshot(DocumentSnapshot snapshot) =>
      MonthlyChallengesRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static MonthlyChallengesRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      MonthlyChallengesRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'MonthlyChallengesRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is MonthlyChallengesRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createMonthlyChallengesRecordData({
  String? title,
  String? description,
  DateTime? startTime,
  DateTime? expiresAt,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'title': title,
      'description': description,
      'start_time': startTime,
      'expires_at': expiresAt,
    }.withoutNulls,
  );

  return firestoreData;
}

class MonthlyChallengesRecordDocumentEquality
    implements Equality<MonthlyChallengesRecord> {
  const MonthlyChallengesRecordDocumentEquality();

  @override
  bool equals(MonthlyChallengesRecord? e1, MonthlyChallengesRecord? e2) {
    const listEquality = ListEquality();
    return listEquality.equals(e1?.webinars, e2?.webinars) &&
        e1?.title == e2?.title &&
        e1?.description == e2?.description &&
        e1?.startTime == e2?.startTime &&
        e1?.expiresAt == e2?.expiresAt &&
        listEquality.equals(e1?.habits, e2?.habits);
  }

  @override
  int hash(MonthlyChallengesRecord? e) => const ListEquality().hash([
        e?.webinars,
        e?.title,
        e?.description,
        e?.startTime,
        e?.expiresAt,
        e?.habits
      ]);

  @override
  bool isValidKey(Object? o) => o is MonthlyChallengesRecord;
}
