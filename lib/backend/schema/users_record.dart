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

class UsersRecord extends FirestoreRecord {
  UsersRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "email" field.
  String? _email;
  String get email => _email ?? '';
  bool hasEmail() => _email != null;

  // "display_name" field.
  String? _displayName;
  String get displayName => _displayName ?? '';
  bool hasDisplayName() => _displayName != null;

  // "photo_url" field.
  String? _photoUrl;
  String get photoUrl => _photoUrl ?? '';
  bool hasPhotoUrl() => _photoUrl != null;

  // "uid" field.
  String? _uid;
  String get uid => _uid ?? '';
  bool hasUid() => _uid != null;

  // "created_time" field.
  DateTime? _createdTime;
  DateTime? get createdTime => _createdTime;
  bool hasCreatedTime() => _createdTime != null;

  // "phone_number" field.
  String? _phoneNumber;
  String get phoneNumber => _phoneNumber ?? '';
  bool hasPhoneNumber() => _phoneNumber != null;

  // "age" field.
  int? _age;
  int get age => _age ?? 0;
  bool hasAge() => _age != null;

  // "age_public" field.
  bool? _agePublic;
  bool get agePublic => _agePublic ?? false;
  bool hasAgePublic() => _agePublic != null;

  // "height" field.
  int? _height;
  int get height => _height ?? 0;
  bool hasHeight() => _height != null;

  // "height_public" field.
  bool? _heightPublic;
  bool get heightPublic => _heightPublic ?? false;
  bool hasHeightPublic() => _heightPublic != null;

  // "location" field.
  String? _location;
  String get location => _location ?? '';
  bool hasLocation() => _location != null;

  // "profile_public" field.
  bool? _profilePublic;
  bool get profilePublic => _profilePublic ?? false;
  bool hasProfilePublic() => _profilePublic != null;

  // "userSex" field.
  String? _userSex;
  String get userSex => _userSex ?? '';
  bool hasUserSex() => _userSex != null;

  // "userSex_public" field.
  bool? _userSexPublic;
  bool get userSexPublic => _userSexPublic ?? false;
  bool hasUserSexPublic() => _userSexPublic != null;

  // "weight" field.
  int? _weight;
  int get weight => _weight ?? 0;
  bool hasWeight() => _weight != null;

  // "weight_public" field.
  bool? _weightPublic;
  bool get weightPublic => _weightPublic ?? false;
  bool hasWeightPublic() => _weightPublic != null;

  // "height_feet" field.
  String? _heightFeet;
  String get heightFeet => _heightFeet ?? '';
  bool hasHeightFeet() => _heightFeet != null;

  // "height_inch" field.
  String? _heightInch;
  String get heightInch => _heightInch ?? '';
  bool hasHeightInch() => _heightInch != null;

  // "local_offset" field.
  int? _localOffset;
  int get localOffset => _localOffset ?? 0;
  bool hasLocalOffset() => _localOffset != null;

  // "last_active" field.
  DateTime? _lastActive;
  DateTime? get lastActive => _lastActive;
  bool hasLastActive() => _lastActive != null;

  // "search_terms" field.
  List<String>? _searchTerms;
  List<String> get searchTerms => _searchTerms ?? const [];
  bool hasSearchTerms() => _searchTerms != null;

  // "blocked_users" field.
  List<DocumentReference>? _blockedUsers;
  List<DocumentReference> get blockedUsers => _blockedUsers ?? const [];
  bool hasBlockedUsers() => _blockedUsers != null;

  // "habits_public" field.
  bool? _habitsPublic;
  bool get habitsPublic => _habitsPublic ?? false;
  bool hasHabitsPublic() => _habitsPublic != null;

  // "goals_public" field.
  bool? _goalsPublic;
  bool get goalsPublic => _goalsPublic ?? false;
  bool hasGoalsPublic() => _goalsPublic != null;

  // "birthday" field.
  DateTime? _birthday;
  DateTime? get birthday => _birthday;
  bool hasBirthday() => _birthday != null;

  void _initializeFields() {
    _email = snapshotData['email'] as String?;
    _displayName = snapshotData['display_name'] as String?;
    _photoUrl = snapshotData['photo_url'] as String?;
    _uid = snapshotData['uid'] as String?;
    _createdTime = snapshotData['created_time'] as DateTime?;
    _phoneNumber = snapshotData['phone_number'] as String?;
    _age = castToType<int>(snapshotData['age']);
    _agePublic = snapshotData['age_public'] as bool?;
    _height = castToType<int>(snapshotData['height']);
    _heightPublic = snapshotData['height_public'] as bool?;
    _location = snapshotData['location'] as String?;
    _profilePublic = snapshotData['profile_public'] as bool?;
    _userSex = snapshotData['userSex'] as String?;
    _userSexPublic = snapshotData['userSex_public'] as bool?;
    _weight = castToType<int>(snapshotData['weight']);
    _weightPublic = snapshotData['weight_public'] as bool?;
    _heightFeet = snapshotData['height_feet'] as String?;
    _heightInch = snapshotData['height_inch'] as String?;
    _localOffset = castToType<int>(snapshotData['local_offset']);
    _lastActive = snapshotData['last_active'] as DateTime?;
    _searchTerms = getDataList(snapshotData['search_terms']);
    _blockedUsers = getDataList(snapshotData['blocked_users']);
    _habitsPublic = snapshotData['habits_public'] as bool?;
    _goalsPublic = snapshotData['goals_public'] as bool?;
    _birthday = snapshotData['birthday'] as DateTime?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('users');

  static Stream<UsersRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => UsersRecord.fromSnapshot(s));

  static Future<UsersRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => UsersRecord.fromSnapshot(s));

  static UsersRecord fromSnapshot(DocumentSnapshot snapshot) => UsersRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static UsersRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      UsersRecord._(reference, mapFromFirestore(data));

  static UsersRecord fromAlgolia(AlgoliaObjectSnapshot snapshot) =>
      UsersRecord.getDocumentFromData(
        {
          'email': snapshot.data['email'],
          'display_name': snapshot.data['display_name'],
          'photo_url': snapshot.data['photo_url'],
          'uid': snapshot.data['uid'],
          'created_time': convertAlgoliaParam(
            snapshot.data['created_time'],
            ParamType.DateTime,
            false,
          ),
          'phone_number': snapshot.data['phone_number'],
          'age': convertAlgoliaParam(
            snapshot.data['age'],
            ParamType.int,
            false,
          ),
          'age_public': snapshot.data['age_public'],
          'height': convertAlgoliaParam(
            snapshot.data['height'],
            ParamType.int,
            false,
          ),
          'height_public': snapshot.data['height_public'],
          'location': snapshot.data['location'],
          'profile_public': snapshot.data['profile_public'],
          'userSex': snapshot.data['userSex'],
          'userSex_public': snapshot.data['userSex_public'],
          'weight': convertAlgoliaParam(
            snapshot.data['weight'],
            ParamType.int,
            false,
          ),
          'weight_public': snapshot.data['weight_public'],
          'height_feet': snapshot.data['height_feet'],
          'height_inch': snapshot.data['height_inch'],
          'local_offset': convertAlgoliaParam(
            snapshot.data['local_offset'],
            ParamType.int,
            false,
          ),
          'last_active': convertAlgoliaParam(
            snapshot.data['last_active'],
            ParamType.DateTime,
            false,
          ),
          'search_terms': safeGet(
            () => snapshot.data['search_terms'].toList(),
          ),
          'blocked_users': safeGet(
            () => convertAlgoliaParam<DocumentReference>(
              snapshot.data['blocked_users'],
              ParamType.DocumentReference,
              true,
            ).toList(),
          ),
          'habits_public': snapshot.data['habits_public'],
          'goals_public': snapshot.data['goals_public'],
          'birthday': convertAlgoliaParam(
            snapshot.data['birthday'],
            ParamType.DateTime,
            false,
          ),
        },
        UsersRecord.collection.doc(snapshot.objectID),
      );

  static Future<List<UsersRecord>> search({
    String? term,
    FutureOr<LatLng>? location,
    int? maxResults,
    double? searchRadiusMeters,
    bool useCache = false,
  }) =>
      FFAlgoliaManager.instance
          .algoliaQuery(
            index: 'users',
            term: term,
            maxResults: maxResults,
            location: location,
            searchRadiusMeters: searchRadiusMeters,
            useCache: useCache,
          )
          .then((r) => r.map(fromAlgolia).toList());

  @override
  String toString() =>
      'UsersRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is UsersRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createUsersRecordData({
  String? email,
  String? displayName,
  String? photoUrl,
  String? uid,
  DateTime? createdTime,
  String? phoneNumber,
  int? age,
  bool? agePublic,
  int? height,
  bool? heightPublic,
  String? location,
  bool? profilePublic,
  String? userSex,
  bool? userSexPublic,
  int? weight,
  bool? weightPublic,
  String? heightFeet,
  String? heightInch,
  int? localOffset,
  DateTime? lastActive,
  bool? habitsPublic,
  bool? goalsPublic,
  DateTime? birthday,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'email': email,
      'display_name': displayName,
      'photo_url': photoUrl,
      'uid': uid,
      'created_time': createdTime,
      'phone_number': phoneNumber,
      'age': age,
      'age_public': agePublic,
      'height': height,
      'height_public': heightPublic,
      'location': location,
      'profile_public': profilePublic,
      'userSex': userSex,
      'userSex_public': userSexPublic,
      'weight': weight,
      'weight_public': weightPublic,
      'height_feet': heightFeet,
      'height_inch': heightInch,
      'local_offset': localOffset,
      'last_active': lastActive,
      'habits_public': habitsPublic,
      'goals_public': goalsPublic,
      'birthday': birthday,
    }.withoutNulls,
  );

  return firestoreData;
}

class UsersRecordDocumentEquality implements Equality<UsersRecord> {
  const UsersRecordDocumentEquality();

  @override
  bool equals(UsersRecord? e1, UsersRecord? e2) {
    const listEquality = ListEquality();
    return e1?.email == e2?.email &&
        e1?.displayName == e2?.displayName &&
        e1?.photoUrl == e2?.photoUrl &&
        e1?.uid == e2?.uid &&
        e1?.createdTime == e2?.createdTime &&
        e1?.phoneNumber == e2?.phoneNumber &&
        e1?.age == e2?.age &&
        e1?.agePublic == e2?.agePublic &&
        e1?.height == e2?.height &&
        e1?.heightPublic == e2?.heightPublic &&
        e1?.location == e2?.location &&
        e1?.profilePublic == e2?.profilePublic &&
        e1?.userSex == e2?.userSex &&
        e1?.userSexPublic == e2?.userSexPublic &&
        e1?.weight == e2?.weight &&
        e1?.weightPublic == e2?.weightPublic &&
        e1?.heightFeet == e2?.heightFeet &&
        e1?.heightInch == e2?.heightInch &&
        e1?.localOffset == e2?.localOffset &&
        e1?.lastActive == e2?.lastActive &&
        listEquality.equals(e1?.searchTerms, e2?.searchTerms) &&
        listEquality.equals(e1?.blockedUsers, e2?.blockedUsers) &&
        e1?.habitsPublic == e2?.habitsPublic &&
        e1?.goalsPublic == e2?.goalsPublic &&
        e1?.birthday == e2?.birthday;
  }

  @override
  int hash(UsersRecord? e) => const ListEquality().hash([
        e?.email,
        e?.displayName,
        e?.photoUrl,
        e?.uid,
        e?.createdTime,
        e?.phoneNumber,
        e?.age,
        e?.agePublic,
        e?.height,
        e?.heightPublic,
        e?.location,
        e?.profilePublic,
        e?.userSex,
        e?.userSexPublic,
        e?.weight,
        e?.weightPublic,
        e?.heightFeet,
        e?.heightInch,
        e?.localOffset,
        e?.lastActive,
        e?.searchTerms,
        e?.blockedUsers,
        e?.habitsPublic,
        e?.goalsPublic,
        e?.birthday
      ]);

  @override
  bool isValidKey(Object? o) => o is UsersRecord;
}
