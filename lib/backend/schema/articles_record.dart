import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class ArticlesRecord extends FirestoreRecord {
  ArticlesRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "content" field.
  String? _content;
  String get content => _content ?? '';
  bool hasContent() => _content != null;

  // "description" field.
  String? _description;
  String get description => _description ?? '';
  bool hasDescription() => _description != null;

  // "order" field.
  int? _order;
  int get order => _order ?? 0;
  bool hasOrder() => _order != null;

  // "title" field.
  String? _title;
  String get title => _title ?? '';
  bool hasTitle() => _title != null;

  // "link" field.
  String? _link;
  String get link => _link ?? '';
  bool hasLink() => _link != null;

  // "page_title" field.
  String? _pageTitle;
  String get pageTitle => _pageTitle ?? '';
  bool hasPageTitle() => _pageTitle != null;

  // "lesson" field.
  DocumentReference? _lesson;
  DocumentReference? get lesson => _lesson;
  bool hasLesson() => _lesson != null;

  // "category" field.
  DocumentReference? _category;
  DocumentReference? get category => _category;
  bool hasCategory() => _category != null;

  // "video_link" field.
  String? _videoLink;
  String get videoLink => _videoLink ?? '';
  bool hasVideoLink() => _videoLink != null;

  void _initializeFields() {
    _content = snapshotData['content'] as String?;
    _description = snapshotData['description'] as String?;
    _order = castToType<int>(snapshotData['order']);
    _title = snapshotData['title'] as String?;
    _link = snapshotData['link'] as String?;
    _pageTitle = snapshotData['page_title'] as String?;
    _lesson = snapshotData['lesson'] as DocumentReference?;
    _category = snapshotData['category'] as DocumentReference?;
    _videoLink = snapshotData['video_link'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('articles');

  static Stream<ArticlesRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => ArticlesRecord.fromSnapshot(s));

  static Future<ArticlesRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => ArticlesRecord.fromSnapshot(s));

  static ArticlesRecord fromSnapshot(DocumentSnapshot snapshot) =>
      ArticlesRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static ArticlesRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      ArticlesRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'ArticlesRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is ArticlesRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createArticlesRecordData({
  String? content,
  String? description,
  int? order,
  String? title,
  String? link,
  String? pageTitle,
  DocumentReference? lesson,
  DocumentReference? category,
  String? videoLink,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'content': content,
      'description': description,
      'order': order,
      'title': title,
      'link': link,
      'page_title': pageTitle,
      'lesson': lesson,
      'category': category,
      'video_link': videoLink,
    }.withoutNulls,
  );

  return firestoreData;
}

class ArticlesRecordDocumentEquality implements Equality<ArticlesRecord> {
  const ArticlesRecordDocumentEquality();

  @override
  bool equals(ArticlesRecord? e1, ArticlesRecord? e2) {
    return e1?.content == e2?.content &&
        e1?.description == e2?.description &&
        e1?.order == e2?.order &&
        e1?.title == e2?.title &&
        e1?.link == e2?.link &&
        e1?.pageTitle == e2?.pageTitle &&
        e1?.lesson == e2?.lesson &&
        e1?.category == e2?.category &&
        e1?.videoLink == e2?.videoLink;
  }

  @override
  int hash(ArticlesRecord? e) => const ListEquality().hash([
        e?.content,
        e?.description,
        e?.order,
        e?.title,
        e?.link,
        e?.pageTitle,
        e?.lesson,
        e?.category,
        e?.videoLink
      ]);

  @override
  bool isValidKey(Object? o) => o is ArticlesRecord;
}
