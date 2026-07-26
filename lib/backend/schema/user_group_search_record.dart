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

class UserGroupSearchRecord extends FirestoreRecord {
  UserGroupSearchRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "user" field.
  DocumentReference? _user;
  DocumentReference? get user => _user;
  bool hasUser() => _user != null;

  // "search_term" field.
  String? _searchTerm;
  String get searchTerm => _searchTerm ?? '';
  bool hasSearchTerm() => _searchTerm != null;

  // "group" field.
  DocumentReference? _group;
  DocumentReference? get group => _group;
  bool hasGroup() => _group != null;

  // "additional_search_terms" field.
  List<String>? _additionalSearchTerms;
  List<String> get additionalSearchTerms => _additionalSearchTerms ?? const [];
  bool hasAdditionalSearchTerms() => _additionalSearchTerms != null;

  void _initializeFields() {
    _user = snapshotData['user'] as DocumentReference?;
    _searchTerm = snapshotData['search_term'] as String?;
    _group = snapshotData['group'] as DocumentReference?;
    _additionalSearchTerms =
        getDataList(snapshotData['additional_search_terms']);
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('user_group_search');

  static Stream<UserGroupSearchRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => UserGroupSearchRecord.fromSnapshot(s));

  static Future<UserGroupSearchRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => UserGroupSearchRecord.fromSnapshot(s));

  static UserGroupSearchRecord fromSnapshot(DocumentSnapshot snapshot) =>
      UserGroupSearchRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static UserGroupSearchRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      UserGroupSearchRecord._(reference, mapFromFirestore(data));

  static UserGroupSearchRecord fromAlgolia(AlgoliaObjectSnapshot snapshot) =>
      UserGroupSearchRecord.getDocumentFromData(
        {
          'user': convertAlgoliaParam(
            snapshot.data['user'],
            ParamType.DocumentReference,
            false,
          ),
          'search_term': snapshot.data['search_term'],
          'group': convertAlgoliaParam(
            snapshot.data['group'],
            ParamType.DocumentReference,
            false,
          ),
          'additional_search_terms': safeGet(
            () => snapshot.data['additional_search_terms'].toList(),
          ),
        },
        UserGroupSearchRecord.collection.doc(snapshot.objectID),
      );

  static Future<List<UserGroupSearchRecord>> search({
    String? term,
    FutureOr<LatLng>? location,
    int? maxResults,
    double? searchRadiusMeters,
    bool useCache = false,
  }) =>
      FFAlgoliaManager.instance
          .algoliaQuery(
            index: 'user_group_search',
            term: term,
            maxResults: maxResults,
            location: location,
            searchRadiusMeters: searchRadiusMeters,
            useCache: useCache,
          )
          .then((r) => r.map(fromAlgolia).toList());

  @override
  String toString() =>
      'UserGroupSearchRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is UserGroupSearchRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createUserGroupSearchRecordData({
  DocumentReference? user,
  String? searchTerm,
  DocumentReference? group,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'user': user,
      'search_term': searchTerm,
      'group': group,
    }.withoutNulls,
  );

  return firestoreData;
}

class UserGroupSearchRecordDocumentEquality
    implements Equality<UserGroupSearchRecord> {
  const UserGroupSearchRecordDocumentEquality();

  @override
  bool equals(UserGroupSearchRecord? e1, UserGroupSearchRecord? e2) {
    const listEquality = ListEquality();
    return e1?.user == e2?.user &&
        e1?.searchTerm == e2?.searchTerm &&
        e1?.group == e2?.group &&
        listEquality.equals(
            e1?.additionalSearchTerms, e2?.additionalSearchTerms);
  }

  @override
  int hash(UserGroupSearchRecord? e) => const ListEquality()
      .hash([e?.user, e?.searchTerm, e?.group, e?.additionalSearchTerms]);

  @override
  bool isValidKey(Object? o) => o is UserGroupSearchRecord;
}
