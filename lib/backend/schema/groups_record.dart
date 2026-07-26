import 'dart:async';

import 'package:from_css_color/from_css_color.dart';
import '/backend/algolia/serialization_util.dart';
import '/backend/algolia/algolia_manager.dart';
import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class GroupsRecord extends FirestoreRecord {
  GroupsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "category" field.
  String? _category;
  String get category => _category ?? '';
  bool hasCategory() => _category != null;

  // "chat" field.
  DocumentReference? _chat;
  DocumentReference? get chat => _chat;
  bool hasChat() => _chat != null;

  // "checkin_day" field.
  String? _checkinDay;
  String get checkinDay => _checkinDay ?? '';
  bool hasCheckinDay() => _checkinDay != null;

  // "checkin_time" field.
  DateTime? _checkinTime;
  DateTime? get checkinTime => _checkinTime;
  bool hasCheckinTime() => _checkinTime != null;

  // "creator" field.
  DocumentReference? _creator;
  DocumentReference? get creator => _creator;
  bool hasCreator() => _creator != null;

  // "description" field.
  String? _description;
  String get description => _description ?? '';
  bool hasDescription() => _description != null;

  // "member_limit" field.
  int? _memberLimit;
  int get memberLimit => _memberLimit ?? 0;
  bool hasMemberLimit() => _memberLimit != null;

  // "name" field.
  String? _name;
  String get name => _name ?? '';
  bool hasName() => _name != null;

  // "needs_approval_to_join" field.
  bool? _needsApprovalToJoin;
  bool get needsApprovalToJoin => _needsApprovalToJoin ?? false;
  bool hasNeedsApprovalToJoin() => _needsApprovalToJoin != null;

  // "reminder_owner" field.
  DocumentReference? _reminderOwner;
  DocumentReference? get reminderOwner => _reminderOwner;
  bool hasReminderOwner() => _reminderOwner != null;

  // "search_terms" field.
  List<String>? _searchTerms;
  List<String> get searchTerms => _searchTerms ?? const [];
  bool hasSearchTerms() => _searchTerms != null;

  void _initializeFields() {
    _category = snapshotData['category'] as String?;
    _chat = snapshotData['chat'] as DocumentReference?;
    _checkinDay = snapshotData['checkin_day'] as String?;
    _checkinTime = snapshotData['checkin_time'] as DateTime?;
    _creator = snapshotData['creator'] as DocumentReference?;
    _description = snapshotData['description'] as String?;
    _memberLimit = castToType<int>(snapshotData['member_limit']);
    _name = snapshotData['name'] as String?;
    _needsApprovalToJoin = snapshotData['needs_approval_to_join'] as bool?;
    _reminderOwner = snapshotData['reminder_owner'] as DocumentReference?;
    _searchTerms = getDataList(snapshotData['search_terms']);
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('groups');

  static Stream<GroupsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => GroupsRecord.fromSnapshot(s));

  static Future<GroupsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => GroupsRecord.fromSnapshot(s));

  static GroupsRecord fromSnapshot(DocumentSnapshot snapshot) => GroupsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static GroupsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      GroupsRecord._(reference, mapFromFirestore(data));

  static GroupsRecord fromAlgolia(AlgoliaObjectSnapshot snapshot) =>
      GroupsRecord.getDocumentFromData(
        {
          'category': snapshot.data['category'],
          'chat': convertAlgoliaParam(
            snapshot.data['chat'],
            ParamType.DocumentReference,
            false,
          ),
          'checkin_day': snapshot.data['checkin_day'],
          'checkin_time': convertAlgoliaParam(
            snapshot.data['checkin_time'],
            ParamType.DateTime,
            false,
          ),
          'creator': convertAlgoliaParam(
            snapshot.data['creator'],
            ParamType.DocumentReference,
            false,
          ),
          'description': snapshot.data['description'],
          'member_limit': convertAlgoliaParam(
            snapshot.data['member_limit'],
            ParamType.int,
            false,
          ),
          'name': snapshot.data['name'],
          'needs_approval_to_join': snapshot.data['needs_approval_to_join'],
          'reminder_owner': convertAlgoliaParam(
            snapshot.data['reminder_owner'],
            ParamType.DocumentReference,
            false,
          ),
          'search_terms': safeGet(
            () => snapshot.data['search_terms'].toList(),
          ),
        },
        GroupsRecord.collection.doc(snapshot.objectID),
      );

  static Future<List<GroupsRecord>> search({
    String? term,
    FutureOr<LatLng>? location,
    int? maxResults,
    double? searchRadiusMeters,
    bool useCache = false,
  }) =>
      FFAlgoliaManager.instance
          .algoliaQuery(
            index: 'groups',
            term: term,
            maxResults: maxResults,
            location: location,
            searchRadiusMeters: searchRadiusMeters,
            useCache: useCache,
          )
          .then((r) => r.map(fromAlgolia).toList());

  @override
  String toString() =>
      'GroupsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is GroupsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createGroupsRecordData({
  String? category,
  DocumentReference? chat,
  String? checkinDay,
  DateTime? checkinTime,
  DocumentReference? creator,
  String? description,
  int? memberLimit,
  String? name,
  bool? needsApprovalToJoin,
  DocumentReference? reminderOwner,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'category': category,
      'chat': chat,
      'checkin_day': checkinDay,
      'checkin_time': checkinTime,
      'creator': creator,
      'description': description,
      'member_limit': memberLimit,
      'name': name,
      'needs_approval_to_join': needsApprovalToJoin,
      'reminder_owner': reminderOwner,
    }.withoutNulls,
  );

  return firestoreData;
}

class GroupsRecordDocumentEquality implements Equality<GroupsRecord> {
  const GroupsRecordDocumentEquality();

  @override
  bool equals(GroupsRecord? e1, GroupsRecord? e2) {
    const listEquality = ListEquality();
    return e1?.category == e2?.category &&
        e1?.chat == e2?.chat &&
        e1?.checkinDay == e2?.checkinDay &&
        e1?.checkinTime == e2?.checkinTime &&
        e1?.creator == e2?.creator &&
        e1?.description == e2?.description &&
        e1?.memberLimit == e2?.memberLimit &&
        e1?.name == e2?.name &&
        e1?.needsApprovalToJoin == e2?.needsApprovalToJoin &&
        e1?.reminderOwner == e2?.reminderOwner &&
        listEquality.equals(e1?.searchTerms, e2?.searchTerms);
  }

  @override
  int hash(GroupsRecord? e) => const ListEquality().hash([
        e?.category,
        e?.chat,
        e?.checkinDay,
        e?.checkinTime,
        e?.creator,
        e?.description,
        e?.memberLimit,
        e?.name,
        e?.needsApprovalToJoin,
        e?.reminderOwner,
        e?.searchTerms
      ]);

  @override
  bool isValidKey(Object? o) => o is GroupsRecord;
}
