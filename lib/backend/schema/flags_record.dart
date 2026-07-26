import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class FlagsRecord extends FirestoreRecord {
  FlagsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "reason" field.
  String? _reason;
  String get reason => _reason ?? '';
  bool hasReason() => _reason != null;

  // "user_who_flagged" field.
  DocumentReference? _userWhoFlagged;
  DocumentReference? get userWhoFlagged => _userWhoFlagged;
  bool hasUserWhoFlagged() => _userWhoFlagged != null;

  // "group" field.
  DocumentReference? _group;
  DocumentReference? get group => _group;
  bool hasGroup() => _group != null;

  // "timestamp" field.
  DateTime? _timestamp;
  DateTime? get timestamp => _timestamp;
  bool hasTimestamp() => _timestamp != null;

  // "flagged_user" field.
  DocumentReference? _flaggedUser;
  DocumentReference? get flaggedUser => _flaggedUser;
  bool hasFlaggedUser() => _flaggedUser != null;

  DocumentReference get parentReference => reference.parent.parent!;

  void _initializeFields() {
    _reason = snapshotData['reason'] as String?;
    _userWhoFlagged = snapshotData['user_who_flagged'] as DocumentReference?;
    _group = snapshotData['group'] as DocumentReference?;
    _timestamp = snapshotData['timestamp'] as DateTime?;
    _flaggedUser = snapshotData['flagged_user'] as DocumentReference?;
  }

  static Query<Map<String, dynamic>> collection([DocumentReference? parent]) =>
      parent != null
          ? parent.collection('flags')
          : FirebaseFirestore.instance.collectionGroup('flags');

  static DocumentReference createDoc(DocumentReference parent, {String? id}) =>
      parent.collection('flags').doc(id);

  static Stream<FlagsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => FlagsRecord.fromSnapshot(s));

  static Future<FlagsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => FlagsRecord.fromSnapshot(s));

  static FlagsRecord fromSnapshot(DocumentSnapshot snapshot) => FlagsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static FlagsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      FlagsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'FlagsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is FlagsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createFlagsRecordData({
  String? reason,
  DocumentReference? userWhoFlagged,
  DocumentReference? group,
  DateTime? timestamp,
  DocumentReference? flaggedUser,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'reason': reason,
      'user_who_flagged': userWhoFlagged,
      'group': group,
      'timestamp': timestamp,
      'flagged_user': flaggedUser,
    }.withoutNulls,
  );

  return firestoreData;
}

class FlagsRecordDocumentEquality implements Equality<FlagsRecord> {
  const FlagsRecordDocumentEquality();

  @override
  bool equals(FlagsRecord? e1, FlagsRecord? e2) {
    return e1?.reason == e2?.reason &&
        e1?.userWhoFlagged == e2?.userWhoFlagged &&
        e1?.group == e2?.group &&
        e1?.timestamp == e2?.timestamp &&
        e1?.flaggedUser == e2?.flaggedUser;
  }

  @override
  int hash(FlagsRecord? e) => const ListEquality().hash(
      [e?.reason, e?.userWhoFlagged, e?.group, e?.timestamp, e?.flaggedUser]);

  @override
  bool isValidKey(Object? o) => o is FlagsRecord;
}
