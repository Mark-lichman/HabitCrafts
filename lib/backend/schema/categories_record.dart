import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class CategoriesRecord extends FirestoreRecord {
  CategoriesRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "title" field.
  String? _title;
  String get title => _title ?? '';
  bool hasTitle() => _title != null;

  // "description" field.
  String? _description;
  String get description => _description ?? '';
  bool hasDescription() => _description != null;

  // "icon" field.
  DocumentReference? _icon;
  DocumentReference? get icon => _icon;
  bool hasIcon() => _icon != null;

  // "articles" field.
  List<DocumentReference>? _articles;
  List<DocumentReference> get articles => _articles ?? const [];
  bool hasArticles() => _articles != null;

  // "isLesson" field.
  bool? _isLesson;
  bool get isLesson => _isLesson ?? false;
  bool hasIsLesson() => _isLesson != null;

  // "order" field.
  int? _order;
  int get order => _order ?? 0;
  bool hasOrder() => _order != null;

  // "parentCategory" field.
  DocumentReference? _parentCategory;
  DocumentReference? get parentCategory => _parentCategory;
  bool hasParentCategory() => _parentCategory != null;

  // "lesson" field.
  DocumentReference? _lesson;
  DocumentReference? get lesson => _lesson;
  bool hasLesson() => _lesson != null;

  void _initializeFields() {
    _title = snapshotData['title'] as String?;
    _description = snapshotData['description'] as String?;
    _icon = snapshotData['icon'] as DocumentReference?;
    _articles = getDataList(snapshotData['articles']);
    _isLesson = snapshotData['isLesson'] as bool?;
    _order = castToType<int>(snapshotData['order']);
    _parentCategory = snapshotData['parentCategory'] as DocumentReference?;
    _lesson = snapshotData['lesson'] as DocumentReference?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('categories');

  static Stream<CategoriesRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => CategoriesRecord.fromSnapshot(s));

  static Future<CategoriesRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => CategoriesRecord.fromSnapshot(s));

  static CategoriesRecord fromSnapshot(DocumentSnapshot snapshot) =>
      CategoriesRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static CategoriesRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      CategoriesRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'CategoriesRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is CategoriesRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createCategoriesRecordData({
  String? title,
  String? description,
  DocumentReference? icon,
  bool? isLesson,
  int? order,
  DocumentReference? parentCategory,
  DocumentReference? lesson,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'title': title,
      'description': description,
      'icon': icon,
      'isLesson': isLesson,
      'order': order,
      'parentCategory': parentCategory,
      'lesson': lesson,
    }.withoutNulls,
  );

  return firestoreData;
}

class CategoriesRecordDocumentEquality implements Equality<CategoriesRecord> {
  const CategoriesRecordDocumentEquality();

  @override
  bool equals(CategoriesRecord? e1, CategoriesRecord? e2) {
    const listEquality = ListEquality();
    return e1?.title == e2?.title &&
        e1?.description == e2?.description &&
        e1?.icon == e2?.icon &&
        listEquality.equals(e1?.articles, e2?.articles) &&
        e1?.isLesson == e2?.isLesson &&
        e1?.order == e2?.order &&
        e1?.parentCategory == e2?.parentCategory &&
        e1?.lesson == e2?.lesson;
  }

  @override
  int hash(CategoriesRecord? e) => const ListEquality().hash([
        e?.title,
        e?.description,
        e?.icon,
        e?.articles,
        e?.isLesson,
        e?.order,
        e?.parentCategory,
        e?.lesson
      ]);

  @override
  bool isValidKey(Object? o) => o is CategoriesRecord;
}
