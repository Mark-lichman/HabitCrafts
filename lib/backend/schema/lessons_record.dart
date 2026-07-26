import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class LessonsRecord extends FirestoreRecord {
  LessonsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "title" field.
  String? _title;
  String get title => _title ?? '';
  bool hasTitle() => _title != null;

  // "order" field.
  int? _order;
  int get order => _order ?? 0;
  bool hasOrder() => _order != null;

  // "articles" field.
  List<DocumentReference>? _articles;
  List<DocumentReference> get articles => _articles ?? const [];
  bool hasArticles() => _articles != null;

  // "description" field.
  String? _description;
  String get description => _description ?? '';
  bool hasDescription() => _description != null;

  // "icon" field.
  DocumentReference? _icon;
  DocumentReference? get icon => _icon;
  bool hasIcon() => _icon != null;

  // "categories" field.
  List<DocumentReference>? _categories;
  List<DocumentReference> get categories => _categories ?? const [];
  bool hasCategories() => _categories != null;

  void _initializeFields() {
    _title = snapshotData['title'] as String?;
    _order = castToType<int>(snapshotData['order']);
    _articles = getDataList(snapshotData['articles']);
    _description = snapshotData['description'] as String?;
    _icon = snapshotData['icon'] as DocumentReference?;
    _categories = getDataList(snapshotData['categories']);
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('lessons');

  static Stream<LessonsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => LessonsRecord.fromSnapshot(s));

  static Future<LessonsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => LessonsRecord.fromSnapshot(s));

  static LessonsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      LessonsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static LessonsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      LessonsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'LessonsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is LessonsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createLessonsRecordData({
  String? title,
  int? order,
  String? description,
  DocumentReference? icon,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'title': title,
      'order': order,
      'description': description,
      'icon': icon,
    }.withoutNulls,
  );

  return firestoreData;
}

class LessonsRecordDocumentEquality implements Equality<LessonsRecord> {
  const LessonsRecordDocumentEquality();

  @override
  bool equals(LessonsRecord? e1, LessonsRecord? e2) {
    const listEquality = ListEquality();
    return e1?.title == e2?.title &&
        e1?.order == e2?.order &&
        listEquality.equals(e1?.articles, e2?.articles) &&
        e1?.description == e2?.description &&
        e1?.icon == e2?.icon &&
        listEquality.equals(e1?.categories, e2?.categories);
  }

  @override
  int hash(LessonsRecord? e) => const ListEquality().hash([
        e?.title,
        e?.order,
        e?.articles,
        e?.description,
        e?.icon,
        e?.categories
      ]);

  @override
  bool isValidKey(Object? o) => o is LessonsRecord;
}
