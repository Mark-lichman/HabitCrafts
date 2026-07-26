import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class GoalsRecord extends FirestoreRecord {
  GoalsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "isPublic" field.
  bool? _isPublic;
  bool get isPublic => _isPublic ?? false;
  bool hasIsPublic() => _isPublic != null;

  // "name" field.
  String? _name;
  String get name => _name ?? '';
  bool hasName() => _name != null;

  // "user" field.
  DocumentReference? _user;
  DocumentReference? get user => _user;
  bool hasUser() => _user != null;

  // "icon" field.
  DocumentReference? _icon;
  DocumentReference? get icon => _icon;
  bool hasIcon() => _icon != null;

  // "last_used" field.
  DateTime? _lastUsed;
  DateTime? get lastUsed => _lastUsed;
  bool hasLastUsed() => _lastUsed != null;

  void _initializeFields() {
    _isPublic = snapshotData['isPublic'] as bool?;
    _name = snapshotData['name'] as String?;
    _user = snapshotData['user'] as DocumentReference?;
    _icon = snapshotData['icon'] as DocumentReference?;
    _lastUsed = snapshotData['last_used'] as DateTime?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('goals');

  static Stream<GoalsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => GoalsRecord.fromSnapshot(s));

  static Future<GoalsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => GoalsRecord.fromSnapshot(s));

  static GoalsRecord fromSnapshot(DocumentSnapshot snapshot) => GoalsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static GoalsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      GoalsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'GoalsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is GoalsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createGoalsRecordData({
  bool? isPublic,
  String? name,
  DocumentReference? user,
  DocumentReference? icon,
  DateTime? lastUsed,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'isPublic': isPublic,
      'name': name,
      'user': user,
      'icon': icon,
      'last_used': lastUsed,
    }.withoutNulls,
  );

  return firestoreData;
}

class GoalsRecordDocumentEquality implements Equality<GoalsRecord> {
  const GoalsRecordDocumentEquality();

  @override
  bool equals(GoalsRecord? e1, GoalsRecord? e2) {
    return e1?.isPublic == e2?.isPublic &&
        e1?.name == e2?.name &&
        e1?.user == e2?.user &&
        e1?.icon == e2?.icon &&
        e1?.lastUsed == e2?.lastUsed;
  }

  @override
  int hash(GoalsRecord? e) => const ListEquality()
      .hash([e?.isPublic, e?.name, e?.user, e?.icon, e?.lastUsed]);

  @override
  bool isValidKey(Object? o) => o is GoalsRecord;
}
