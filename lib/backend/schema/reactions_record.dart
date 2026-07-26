import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class ReactionsRecord extends FirestoreRecord {
  ReactionsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "emoji" field.
  String? _emoji;
  String get emoji => _emoji ?? '';
  bool hasEmoji() => _emoji != null;

  // "created_at" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  // "count" field.
  int? _count;
  int get count => _count ?? 0;
  bool hasCount() => _count != null;

  // "users" field.
  List<DocumentReference>? _users;
  List<DocumentReference> get users => _users ?? const [];
  bool hasUsers() => _users != null;

  DocumentReference get parentReference => reference.parent.parent!;

  void _initializeFields() {
    _emoji = snapshotData['emoji'] as String?;
    _createdAt = snapshotData['created_at'] as DateTime?;
    _count = castToType<int>(snapshotData['count']);
    _users = getDataList(snapshotData['users']);
  }

  static Query<Map<String, dynamic>> collection([DocumentReference? parent]) =>
      parent != null
          ? parent.collection('reactions')
          : FirebaseFirestore.instance.collectionGroup('reactions');

  static DocumentReference createDoc(DocumentReference parent, {String? id}) =>
      parent.collection('reactions').doc(id);

  static Stream<ReactionsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => ReactionsRecord.fromSnapshot(s));

  static Future<ReactionsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => ReactionsRecord.fromSnapshot(s));

  static ReactionsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      ReactionsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static ReactionsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      ReactionsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'ReactionsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is ReactionsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createReactionsRecordData({
  String? emoji,
  DateTime? createdAt,
  int? count,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'emoji': emoji,
      'created_at': createdAt,
      'count': count,
    }.withoutNulls,
  );

  return firestoreData;
}

class ReactionsRecordDocumentEquality implements Equality<ReactionsRecord> {
  const ReactionsRecordDocumentEquality();

  @override
  bool equals(ReactionsRecord? e1, ReactionsRecord? e2) {
    const listEquality = ListEquality();
    return e1?.emoji == e2?.emoji &&
        e1?.createdAt == e2?.createdAt &&
        e1?.count == e2?.count &&
        listEquality.equals(e1?.users, e2?.users);
  }

  @override
  int hash(ReactionsRecord? e) =>
      const ListEquality().hash([e?.emoji, e?.createdAt, e?.count, e?.users]);

  @override
  bool isValidKey(Object? o) => o is ReactionsRecord;
}
