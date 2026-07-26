import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class ChatsRecord extends FirestoreRecord {
  ChatsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "group_chat_id" field.
  int? _groupChatId;
  int get groupChatId => _groupChatId ?? 0;
  bool hasGroupChatId() => _groupChatId != null;

  // "last_message" field.
  String? _lastMessage;
  String get lastMessage => _lastMessage ?? '';
  bool hasLastMessage() => _lastMessage != null;

  // "last_message_seen_by" field.
  List<DocumentReference>? _lastMessageSeenBy;
  List<DocumentReference> get lastMessageSeenBy =>
      _lastMessageSeenBy ?? const [];
  bool hasLastMessageSeenBy() => _lastMessageSeenBy != null;

  // "users" field.
  List<DocumentReference>? _users;
  List<DocumentReference> get users => _users ?? const [];
  bool hasUsers() => _users != null;

  // "last_message_sent_by" field.
  DocumentReference? _lastMessageSentBy;
  DocumentReference? get lastMessageSentBy => _lastMessageSentBy;
  bool hasLastMessageSentBy() => _lastMessageSentBy != null;

  // "last_message_time" field.
  DateTime? _lastMessageTime;
  DateTime? get lastMessageTime => _lastMessageTime;
  bool hasLastMessageTime() => _lastMessageTime != null;

  // "user_a" field.
  DocumentReference? _userA;
  DocumentReference? get userA => _userA;
  bool hasUserA() => _userA != null;

  // "user_b" field.
  DocumentReference? _userB;
  DocumentReference? get userB => _userB;
  bool hasUserB() => _userB != null;

  // "group" field.
  DocumentReference? _group;
  DocumentReference? get group => _group;
  bool hasGroup() => _group != null;

  // "members_online" field.
  List<DocumentReference>? _membersOnline;
  List<DocumentReference> get membersOnline => _membersOnline ?? const [];
  bool hasMembersOnline() => _membersOnline != null;

  void _initializeFields() {
    _groupChatId = castToType<int>(snapshotData['group_chat_id']);
    _lastMessage = snapshotData['last_message'] as String?;
    _lastMessageSeenBy = getDataList(snapshotData['last_message_seen_by']);
    _users = getDataList(snapshotData['users']);
    _lastMessageSentBy =
        snapshotData['last_message_sent_by'] as DocumentReference?;
    _lastMessageTime = snapshotData['last_message_time'] as DateTime?;
    _userA = snapshotData['user_a'] as DocumentReference?;
    _userB = snapshotData['user_b'] as DocumentReference?;
    _group = snapshotData['group'] as DocumentReference?;
    _membersOnline = getDataList(snapshotData['members_online']);
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('chats');

  static Stream<ChatsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => ChatsRecord.fromSnapshot(s));

  static Future<ChatsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => ChatsRecord.fromSnapshot(s));

  static ChatsRecord fromSnapshot(DocumentSnapshot snapshot) => ChatsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static ChatsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      ChatsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'ChatsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is ChatsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createChatsRecordData({
  int? groupChatId,
  String? lastMessage,
  DocumentReference? lastMessageSentBy,
  DateTime? lastMessageTime,
  DocumentReference? userA,
  DocumentReference? userB,
  DocumentReference? group,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'group_chat_id': groupChatId,
      'last_message': lastMessage,
      'last_message_sent_by': lastMessageSentBy,
      'last_message_time': lastMessageTime,
      'user_a': userA,
      'user_b': userB,
      'group': group,
    }.withoutNulls,
  );

  return firestoreData;
}

class ChatsRecordDocumentEquality implements Equality<ChatsRecord> {
  const ChatsRecordDocumentEquality();

  @override
  bool equals(ChatsRecord? e1, ChatsRecord? e2) {
    const listEquality = ListEquality();
    return e1?.groupChatId == e2?.groupChatId &&
        e1?.lastMessage == e2?.lastMessage &&
        listEquality.equals(e1?.lastMessageSeenBy, e2?.lastMessageSeenBy) &&
        listEquality.equals(e1?.users, e2?.users) &&
        e1?.lastMessageSentBy == e2?.lastMessageSentBy &&
        e1?.lastMessageTime == e2?.lastMessageTime &&
        e1?.userA == e2?.userA &&
        e1?.userB == e2?.userB &&
        e1?.group == e2?.group &&
        listEquality.equals(e1?.membersOnline, e2?.membersOnline);
  }

  @override
  int hash(ChatsRecord? e) => const ListEquality().hash([
        e?.groupChatId,
        e?.lastMessage,
        e?.lastMessageSeenBy,
        e?.users,
        e?.lastMessageSentBy,
        e?.lastMessageTime,
        e?.userA,
        e?.userB,
        e?.group,
        e?.membersOnline
      ]);

  @override
  bool isValidKey(Object? o) => o is ChatsRecord;
}
