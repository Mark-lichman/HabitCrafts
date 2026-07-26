import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class UserActivityRecord extends FirestoreRecord {
  UserActivityRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "action" field.
  ActivityTypes? _action;
  ActivityTypes? get action => _action;
  bool hasAction() => _action != null;

  // "actionText" field.
  String? _actionText;
  String get actionText => _actionText ?? '';
  bool hasActionText() => _actionText != null;

  // "created" field.
  DateTime? _created;
  DateTime? get created => _created;
  bool hasCreated() => _created != null;

  // "habit" field.
  DocumentReference? _habit;
  DocumentReference? get habit => _habit;
  bool hasHabit() => _habit != null;

  // "checkin" field.
  DocumentReference? _checkin;
  DocumentReference? get checkin => _checkin;
  bool hasCheckin() => _checkin != null;

  // "group" field.
  DocumentReference? _group;
  DocumentReference? get group => _group;
  bool hasGroup() => _group != null;

  // "notes" field.
  String? _notes;
  String get notes => _notes ?? '';
  bool hasNotes() => _notes != null;

  DocumentReference get parentReference => reference.parent.parent!;

  void _initializeFields() {
    _action = snapshotData['action'] is ActivityTypes
        ? snapshotData['action']
        : deserializeEnum<ActivityTypes>(snapshotData['action']);
    _actionText = snapshotData['actionText'] as String?;
    _created = snapshotData['created'] as DateTime?;
    _habit = snapshotData['habit'] as DocumentReference?;
    _checkin = snapshotData['checkin'] as DocumentReference?;
    _group = snapshotData['group'] as DocumentReference?;
    _notes = snapshotData['notes'] as String?;
  }

  static Query<Map<String, dynamic>> collection([DocumentReference? parent]) =>
      parent != null
          ? parent.collection('user_activity')
          : FirebaseFirestore.instance.collectionGroup('user_activity');

  static DocumentReference createDoc(DocumentReference parent, {String? id}) =>
      parent.collection('user_activity').doc(id);

  static Stream<UserActivityRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => UserActivityRecord.fromSnapshot(s));

  static Future<UserActivityRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => UserActivityRecord.fromSnapshot(s));

  static UserActivityRecord fromSnapshot(DocumentSnapshot snapshot) =>
      UserActivityRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static UserActivityRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      UserActivityRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'UserActivityRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is UserActivityRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createUserActivityRecordData({
  ActivityTypes? action,
  String? actionText,
  DateTime? created,
  DocumentReference? habit,
  DocumentReference? checkin,
  DocumentReference? group,
  String? notes,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'action': action,
      'actionText': actionText,
      'created': created,
      'habit': habit,
      'checkin': checkin,
      'group': group,
      'notes': notes,
    }.withoutNulls,
  );

  return firestoreData;
}

class UserActivityRecordDocumentEquality
    implements Equality<UserActivityRecord> {
  const UserActivityRecordDocumentEquality();

  @override
  bool equals(UserActivityRecord? e1, UserActivityRecord? e2) {
    return e1?.action == e2?.action &&
        e1?.actionText == e2?.actionText &&
        e1?.created == e2?.created &&
        e1?.habit == e2?.habit &&
        e1?.checkin == e2?.checkin &&
        e1?.group == e2?.group &&
        e1?.notes == e2?.notes;
  }

  @override
  int hash(UserActivityRecord? e) => const ListEquality().hash([
        e?.action,
        e?.actionText,
        e?.created,
        e?.habit,
        e?.checkin,
        e?.group,
        e?.notes
      ]);

  @override
  bool isValidKey(Object? o) => o is UserActivityRecord;
}
