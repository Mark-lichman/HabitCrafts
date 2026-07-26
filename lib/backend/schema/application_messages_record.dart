import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class ApplicationMessagesRecord extends FirestoreRecord {
  ApplicationMessagesRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "message_type" field.
  String? _messageType;
  String get messageType => _messageType ?? '';
  bool hasMessageType() => _messageType != null;

  // "content" field.
  String? _content;
  String get content => _content ?? '';
  bool hasContent() => _content != null;

  void _initializeFields() {
    _messageType = snapshotData['message_type'] as String?;
    _content = snapshotData['content'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('application_messages');

  static Stream<ApplicationMessagesRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => ApplicationMessagesRecord.fromSnapshot(s));

  static Future<ApplicationMessagesRecord> getDocumentOnce(
          DocumentReference ref) =>
      ref.get().then((s) => ApplicationMessagesRecord.fromSnapshot(s));

  static ApplicationMessagesRecord fromSnapshot(DocumentSnapshot snapshot) =>
      ApplicationMessagesRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static ApplicationMessagesRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      ApplicationMessagesRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'ApplicationMessagesRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is ApplicationMessagesRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createApplicationMessagesRecordData({
  String? messageType,
  String? content,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'message_type': messageType,
      'content': content,
    }.withoutNulls,
  );

  return firestoreData;
}

class ApplicationMessagesRecordDocumentEquality
    implements Equality<ApplicationMessagesRecord> {
  const ApplicationMessagesRecordDocumentEquality();

  @override
  bool equals(ApplicationMessagesRecord? e1, ApplicationMessagesRecord? e2) {
    return e1?.messageType == e2?.messageType && e1?.content == e2?.content;
  }

  @override
  int hash(ApplicationMessagesRecord? e) =>
      const ListEquality().hash([e?.messageType, e?.content]);

  @override
  bool isValidKey(Object? o) => o is ApplicationMessagesRecord;
}
