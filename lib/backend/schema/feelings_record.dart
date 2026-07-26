import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class FeelingsRecord extends FirestoreRecord {
  FeelingsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "imagePath" field.
  String? _imagePath;
  String get imagePath => _imagePath ?? '';
  bool hasImagePath() => _imagePath != null;

  // "level" field.
  int? _level;
  int get level => _level ?? 0;
  bool hasLevel() => _level != null;

  void _initializeFields() {
    _imagePath = snapshotData['imagePath'] as String?;
    _level = castToType<int>(snapshotData['level']);
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('feelings');

  static Stream<FeelingsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => FeelingsRecord.fromSnapshot(s));

  static Future<FeelingsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => FeelingsRecord.fromSnapshot(s));

  static FeelingsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      FeelingsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static FeelingsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      FeelingsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'FeelingsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is FeelingsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createFeelingsRecordData({
  String? imagePath,
  int? level,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'imagePath': imagePath,
      'level': level,
    }.withoutNulls,
  );

  return firestoreData;
}

class FeelingsRecordDocumentEquality implements Equality<FeelingsRecord> {
  const FeelingsRecordDocumentEquality();

  @override
  bool equals(FeelingsRecord? e1, FeelingsRecord? e2) {
    return e1?.imagePath == e2?.imagePath && e1?.level == e2?.level;
  }

  @override
  int hash(FeelingsRecord? e) =>
      const ListEquality().hash([e?.imagePath, e?.level]);

  @override
  bool isValidKey(Object? o) => o is FeelingsRecord;
}
