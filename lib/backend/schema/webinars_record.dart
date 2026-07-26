import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class WebinarsRecord extends FirestoreRecord {
  WebinarsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "link" field.
  String? _link;
  String get link => _link ?? '';
  bool hasLink() => _link != null;

  // "title" field.
  String? _title;
  String get title => _title ?? '';
  bool hasTitle() => _title != null;

  // "expires_at" field.
  DateTime? _expiresAt;
  DateTime? get expiresAt => _expiresAt;
  bool hasExpiresAt() => _expiresAt != null;

  // "event_time" field.
  DateTime? _eventTime;
  DateTime? get eventTime => _eventTime;
  bool hasEventTime() => _eventTime != null;

  // "location_name" field.
  String? _locationName;
  String get locationName => _locationName ?? '';
  bool hasLocationName() => _locationName != null;

  void _initializeFields() {
    _link = snapshotData['link'] as String?;
    _title = snapshotData['title'] as String?;
    _expiresAt = snapshotData['expires_at'] as DateTime?;
    _eventTime = snapshotData['event_time'] as DateTime?;
    _locationName = snapshotData['location_name'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('webinars');

  static Stream<WebinarsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => WebinarsRecord.fromSnapshot(s));

  static Future<WebinarsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => WebinarsRecord.fromSnapshot(s));

  static WebinarsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      WebinarsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static WebinarsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      WebinarsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'WebinarsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is WebinarsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createWebinarsRecordData({
  String? link,
  String? title,
  DateTime? expiresAt,
  DateTime? eventTime,
  String? locationName,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'link': link,
      'title': title,
      'expires_at': expiresAt,
      'event_time': eventTime,
      'location_name': locationName,
    }.withoutNulls,
  );

  return firestoreData;
}

class WebinarsRecordDocumentEquality implements Equality<WebinarsRecord> {
  const WebinarsRecordDocumentEquality();

  @override
  bool equals(WebinarsRecord? e1, WebinarsRecord? e2) {
    return e1?.link == e2?.link &&
        e1?.title == e2?.title &&
        e1?.expiresAt == e2?.expiresAt &&
        e1?.eventTime == e2?.eventTime &&
        e1?.locationName == e2?.locationName;
  }

  @override
  int hash(WebinarsRecord? e) => const ListEquality()
      .hash([e?.link, e?.title, e?.expiresAt, e?.eventTime, e?.locationName]);

  @override
  bool isValidKey(Object? o) => o is WebinarsRecord;
}
