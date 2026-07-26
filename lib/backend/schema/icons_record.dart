import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class IconsRecord extends FirestoreRecord {
  IconsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "name" field.
  String? _name;
  String get name => _name ?? '';
  bool hasName() => _name != null;

  // "image" field.
  String? _image;
  String get image => _image ?? '';
  bool hasImage() => _image != null;

  void _initializeFields() {
    _name = snapshotData['name'] as String?;
    _image = snapshotData['image'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('icons');

  static Stream<IconsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => IconsRecord.fromSnapshot(s));

  static Future<IconsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => IconsRecord.fromSnapshot(s));

  static IconsRecord fromSnapshot(DocumentSnapshot snapshot) => IconsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static IconsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      IconsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'IconsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is IconsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createIconsRecordData({
  String? name,
  String? image,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'name': name,
      'image': image,
    }.withoutNulls,
  );

  return firestoreData;
}

class IconsRecordDocumentEquality implements Equality<IconsRecord> {
  const IconsRecordDocumentEquality();

  @override
  bool equals(IconsRecord? e1, IconsRecord? e2) {
    return e1?.name == e2?.name && e1?.image == e2?.image;
  }

  @override
  int hash(IconsRecord? e) => const ListEquality().hash([e?.name, e?.image]);

  @override
  bool isValidKey(Object? o) => o is IconsRecord;
}
