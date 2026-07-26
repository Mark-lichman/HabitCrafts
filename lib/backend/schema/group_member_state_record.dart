import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class GroupMemberStateRecord extends FirestoreRecord {
  GroupMemberStateRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "member" field.
  DocumentReference? _member;
  DocumentReference? get member => _member;
  bool hasMember() => _member != null;

  // "status" field.
  GroupMembershipStatus? _status;
  GroupMembershipStatus? get status => _status;
  bool hasStatus() => _status != null;

  // "group" field.
  DocumentReference? _group;
  DocumentReference? get group => _group;
  bool hasGroup() => _group != null;

  // "joined_chat" field.
  bool? _joinedChat;
  bool get joinedChat => _joinedChat ?? false;
  bool hasJoinedChat() => _joinedChat != null;

  // "last_active" field.
  DateTime? _lastActive;
  DateTime? get lastActive => _lastActive;
  bool hasLastActive() => _lastActive != null;

  // "checkin_day" field.
  String? _checkinDay;
  String get checkinDay => _checkinDay ?? '';
  bool hasCheckinDay() => _checkinDay != null;

  // "recent_checkin" field.
  String? _recentCheckin;
  String get recentCheckin => _recentCheckin ?? '';
  bool hasRecentCheckin() => _recentCheckin != null;

  void _initializeFields() {
    _member = snapshotData['member'] as DocumentReference?;
    _status = snapshotData['status'] is GroupMembershipStatus
        ? snapshotData['status']
        : deserializeEnum<GroupMembershipStatus>(snapshotData['status']);
    _group = snapshotData['group'] as DocumentReference?;
    _joinedChat = snapshotData['joined_chat'] as bool?;
    _lastActive = snapshotData['last_active'] as DateTime?;
    _checkinDay = snapshotData['checkin_day'] as String?;
    _recentCheckin = snapshotData['recent_checkin'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('group_member_state');

  static Stream<GroupMemberStateRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => GroupMemberStateRecord.fromSnapshot(s));

  static Future<GroupMemberStateRecord> getDocumentOnce(
          DocumentReference ref) =>
      ref.get().then((s) => GroupMemberStateRecord.fromSnapshot(s));

  static GroupMemberStateRecord fromSnapshot(DocumentSnapshot snapshot) =>
      GroupMemberStateRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static GroupMemberStateRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      GroupMemberStateRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'GroupMemberStateRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is GroupMemberStateRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createGroupMemberStateRecordData({
  DocumentReference? member,
  GroupMembershipStatus? status,
  DocumentReference? group,
  bool? joinedChat,
  DateTime? lastActive,
  String? checkinDay,
  String? recentCheckin,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'member': member,
      'status': status,
      'group': group,
      'joined_chat': joinedChat,
      'last_active': lastActive,
      'checkin_day': checkinDay,
      'recent_checkin': recentCheckin,
    }.withoutNulls,
  );

  return firestoreData;
}

class GroupMemberStateRecordDocumentEquality
    implements Equality<GroupMemberStateRecord> {
  const GroupMemberStateRecordDocumentEquality();

  @override
  bool equals(GroupMemberStateRecord? e1, GroupMemberStateRecord? e2) {
    return e1?.member == e2?.member &&
        e1?.status == e2?.status &&
        e1?.group == e2?.group &&
        e1?.joinedChat == e2?.joinedChat &&
        e1?.lastActive == e2?.lastActive &&
        e1?.checkinDay == e2?.checkinDay &&
        e1?.recentCheckin == e2?.recentCheckin;
  }

  @override
  int hash(GroupMemberStateRecord? e) => const ListEquality().hash([
        e?.member,
        e?.status,
        e?.group,
        e?.joinedChat,
        e?.lastActive,
        e?.checkinDay,
        e?.recentCheckin
      ]);

  @override
  bool isValidKey(Object? o) => o is GroupMemberStateRecord;
}
