import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class CelebrationSuggestionsRecord extends FirestoreRecord {
  CelebrationSuggestionsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "name" field.
  String? _name;
  String get name => _name ?? '';
  bool hasName() => _name != null;

  void _initializeFields() {
    _name = snapshotData['name'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('celebration_suggestions');

  static Stream<CelebrationSuggestionsRecord> getDocument(
          DocumentReference ref) =>
      ref.snapshots().map((s) => CelebrationSuggestionsRecord.fromSnapshot(s));

  static Future<CelebrationSuggestionsRecord> getDocumentOnce(
          DocumentReference ref) =>
      ref.get().then((s) => CelebrationSuggestionsRecord.fromSnapshot(s));

  static CelebrationSuggestionsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      CelebrationSuggestionsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static CelebrationSuggestionsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      CelebrationSuggestionsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'CelebrationSuggestionsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is CelebrationSuggestionsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createCelebrationSuggestionsRecordData({
  String? name,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'name': name,
    }.withoutNulls,
  );

  return firestoreData;
}

class CelebrationSuggestionsRecordDocumentEquality
    implements Equality<CelebrationSuggestionsRecord> {
  const CelebrationSuggestionsRecordDocumentEquality();

  @override
  bool equals(
      CelebrationSuggestionsRecord? e1, CelebrationSuggestionsRecord? e2) {
    return e1?.name == e2?.name;
  }

  @override
  int hash(CelebrationSuggestionsRecord? e) =>
      const ListEquality().hash([e?.name]);

  @override
  bool isValidKey(Object? o) => o is CelebrationSuggestionsRecord;
}
