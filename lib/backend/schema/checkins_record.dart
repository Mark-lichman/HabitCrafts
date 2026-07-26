import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class CheckinsRecord extends FirestoreRecord {
  CheckinsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "date" field.
  DateTime? _date;
  DateTime? get date => _date;
  bool hasDate() => _date != null;

  // "how_did_it_feel" field.
  String? _howDidItFeel;
  String get howDidItFeel => _howDidItFeel ?? '';
  bool hasHowDidItFeel() => _howDidItFeel != null;

  // "share_to_group" field.
  bool? _shareToGroup;
  bool get shareToGroup => _shareToGroup ?? false;
  bool hasShareToGroup() => _shareToGroup != null;

  // "user" field.
  DocumentReference? _user;
  DocumentReference? get user => _user;
  bool hasUser() => _user != null;

  // "what_needs_improvement" field.
  String? _whatNeedsImprovement;
  String get whatNeedsImprovement => _whatNeedsImprovement ?? '';
  bool hasWhatNeedsImprovement() => _whatNeedsImprovement != null;

  // "what_went_well" field.
  String? _whatWentWell;
  String get whatWentWell => _whatWentWell ?? '';
  bool hasWhatWentWell() => _whatWentWell != null;

  // "group" field.
  DocumentReference? _group;
  DocumentReference? get group => _group;
  bool hasGroup() => _group != null;

  // "feeling" field.
  int? _feeling;
  int get feeling => _feeling ?? 0;
  bool hasFeeling() => _feeling != null;

  // "feedback" field.
  bool? _feedback;
  bool get feedback => _feedback ?? false;
  bool hasFeedback() => _feedback != null;

  void _initializeFields() {
    _date = snapshotData['date'] as DateTime?;
    _howDidItFeel = snapshotData['how_did_it_feel'] as String?;
    _shareToGroup = snapshotData['share_to_group'] as bool?;
    _user = snapshotData['user'] as DocumentReference?;
    _whatNeedsImprovement = snapshotData['what_needs_improvement'] as String?;
    _whatWentWell = snapshotData['what_went_well'] as String?;
    _group = snapshotData['group'] as DocumentReference?;
    _feeling = castToType<int>(snapshotData['feeling']);
    _feedback = snapshotData['feedback'] as bool?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('checkins');

  static Stream<CheckinsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => CheckinsRecord.fromSnapshot(s));

  static Future<CheckinsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => CheckinsRecord.fromSnapshot(s));

  static CheckinsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      CheckinsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static CheckinsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      CheckinsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'CheckinsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is CheckinsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createCheckinsRecordData({
  DateTime? date,
  String? howDidItFeel,
  bool? shareToGroup,
  DocumentReference? user,
  String? whatNeedsImprovement,
  String? whatWentWell,
  DocumentReference? group,
  int? feeling,
  bool? feedback,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'date': date,
      'how_did_it_feel': howDidItFeel,
      'share_to_group': shareToGroup,
      'user': user,
      'what_needs_improvement': whatNeedsImprovement,
      'what_went_well': whatWentWell,
      'group': group,
      'feeling': feeling,
      'feedback': feedback,
    }.withoutNulls,
  );

  return firestoreData;
}

class CheckinsRecordDocumentEquality implements Equality<CheckinsRecord> {
  const CheckinsRecordDocumentEquality();

  @override
  bool equals(CheckinsRecord? e1, CheckinsRecord? e2) {
    return e1?.date == e2?.date &&
        e1?.howDidItFeel == e2?.howDidItFeel &&
        e1?.shareToGroup == e2?.shareToGroup &&
        e1?.user == e2?.user &&
        e1?.whatNeedsImprovement == e2?.whatNeedsImprovement &&
        e1?.whatWentWell == e2?.whatWentWell &&
        e1?.group == e2?.group &&
        e1?.feeling == e2?.feeling &&
        e1?.feedback == e2?.feedback;
  }

  @override
  int hash(CheckinsRecord? e) => const ListEquality().hash([
        e?.date,
        e?.howDidItFeel,
        e?.shareToGroup,
        e?.user,
        e?.whatNeedsImprovement,
        e?.whatWentWell,
        e?.group,
        e?.feeling,
        e?.feedback
      ]);

  @override
  bool isValidKey(Object? o) => o is CheckinsRecord;
}
