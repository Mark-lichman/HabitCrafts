import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class HabitsRecord extends FirestoreRecord {
  HabitsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "behavior" field.
  String? _behavior;
  String get behavior => _behavior ?? '';
  bool hasBehavior() => _behavior != null;

  // "celebration" field.
  String? _celebration;
  String get celebration => _celebration ?? '';
  bool hasCelebration() => _celebration != null;

  // "complete" field.
  List<DateTime>? _complete;
  List<DateTime> get complete => _complete ?? const [];
  bool hasComplete() => _complete != null;

  // "finished" field.
  DateTime? _finished;
  DateTime? get finished => _finished;
  bool hasFinished() => _finished != null;

  // "goal" field.
  DocumentReference? _goal;
  DocumentReference? get goal => _goal;
  bool hasGoal() => _goal != null;

  // "prompt" field.
  String? _prompt;
  String get prompt => _prompt ?? '';
  bool hasPrompt() => _prompt != null;

  // "prompt_remind" field.
  bool? _promptRemind;
  bool get promptRemind => _promptRemind ?? false;
  bool hasPromptRemind() => _promptRemind != null;

  // "user" field.
  DocumentReference? _user;
  DocumentReference? get user => _user;
  bool hasUser() => _user != null;

  // "why" field.
  String? _why;
  String get why => _why ?? '';
  bool hasWhy() => _why != null;

  // "created_time" field.
  DateTime? _createdTime;
  DateTime? get createdTime => _createdTime;
  bool hasCreatedTime() => _createdTime != null;

  // "icon" field.
  DocumentReference? _icon;
  DocumentReference? get icon => _icon;
  bool hasIcon() => _icon != null;

  // "article" field.
  DocumentReference? _article;
  DocumentReference? get article => _article;
  bool hasArticle() => _article != null;

  // "is_finished" field.
  bool? _isFinished;
  bool get isFinished => _isFinished ?? false;
  bool hasIsFinished() => _isFinished != null;

  // "category" field.
  DocumentReference? _category;
  DocumentReference? get category => _category;
  bool hasCategory() => _category != null;

  // "reminder" field.
  DocumentReference? _reminder;
  DocumentReference? get reminder => _reminder;
  bool hasReminder() => _reminder != null;

  void _initializeFields() {
    _behavior = snapshotData['behavior'] as String?;
    _celebration = snapshotData['celebration'] as String?;
    _complete = getDataList(snapshotData['complete']);
    _finished = snapshotData['finished'] as DateTime?;
    _goal = snapshotData['goal'] as DocumentReference?;
    _prompt = snapshotData['prompt'] as String?;
    _promptRemind = snapshotData['prompt_remind'] as bool?;
    _user = snapshotData['user'] as DocumentReference?;
    _why = snapshotData['why'] as String?;
    _createdTime = snapshotData['created_time'] as DateTime?;
    _icon = snapshotData['icon'] as DocumentReference?;
    _article = snapshotData['article'] as DocumentReference?;
    _isFinished = snapshotData['is_finished'] as bool?;
    _category = snapshotData['category'] as DocumentReference?;
    _reminder = snapshotData['reminder'] as DocumentReference?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('habits');

  static Stream<HabitsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => HabitsRecord.fromSnapshot(s));

  static Future<HabitsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => HabitsRecord.fromSnapshot(s));

  static HabitsRecord fromSnapshot(DocumentSnapshot snapshot) => HabitsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static HabitsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      HabitsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'HabitsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is HabitsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createHabitsRecordData({
  String? behavior,
  String? celebration,
  DateTime? finished,
  DocumentReference? goal,
  String? prompt,
  bool? promptRemind,
  DocumentReference? user,
  String? why,
  DateTime? createdTime,
  DocumentReference? icon,
  DocumentReference? article,
  bool? isFinished,
  DocumentReference? category,
  DocumentReference? reminder,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'behavior': behavior,
      'celebration': celebration,
      'finished': finished,
      'goal': goal,
      'prompt': prompt,
      'prompt_remind': promptRemind,
      'user': user,
      'why': why,
      'created_time': createdTime,
      'icon': icon,
      'article': article,
      'is_finished': isFinished,
      'category': category,
      'reminder': reminder,
    }.withoutNulls,
  );

  return firestoreData;
}

class HabitsRecordDocumentEquality implements Equality<HabitsRecord> {
  const HabitsRecordDocumentEquality();

  @override
  bool equals(HabitsRecord? e1, HabitsRecord? e2) {
    const listEquality = ListEquality();
    return e1?.behavior == e2?.behavior &&
        e1?.celebration == e2?.celebration &&
        listEquality.equals(e1?.complete, e2?.complete) &&
        e1?.finished == e2?.finished &&
        e1?.goal == e2?.goal &&
        e1?.prompt == e2?.prompt &&
        e1?.promptRemind == e2?.promptRemind &&
        e1?.user == e2?.user &&
        e1?.why == e2?.why &&
        e1?.createdTime == e2?.createdTime &&
        e1?.icon == e2?.icon &&
        e1?.article == e2?.article &&
        e1?.isFinished == e2?.isFinished &&
        e1?.category == e2?.category &&
        e1?.reminder == e2?.reminder;
  }

  @override
  int hash(HabitsRecord? e) => const ListEquality().hash([
        e?.behavior,
        e?.celebration,
        e?.complete,
        e?.finished,
        e?.goal,
        e?.prompt,
        e?.promptRemind,
        e?.user,
        e?.why,
        e?.createdTime,
        e?.icon,
        e?.article,
        e?.isFinished,
        e?.category,
        e?.reminder
      ]);

  @override
  bool isValidKey(Object? o) => o is HabitsRecord;
}
