// ignore_for_file: unnecessary_getters_setters
import '/backend/algolia/serialization_util.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class ReactionCountStruct extends FFFirebaseStruct {
  ReactionCountStruct({
    String? emoji,
    int? count,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _emoji = emoji,
        _count = count,
        super(firestoreUtilData);

  // "emoji" field.
  String? _emoji;
  String get emoji => _emoji ?? '';
  set emoji(String? val) => _emoji = val;

  bool hasEmoji() => _emoji != null;

  // "count" field.
  int? _count;
  int get count => _count ?? 0;
  set count(int? val) => _count = val;

  void incrementCount(int amount) => count = count + amount;

  bool hasCount() => _count != null;

  static ReactionCountStruct fromMap(Map<String, dynamic> data) =>
      ReactionCountStruct(
        emoji: data['emoji'] as String?,
        count: castToType<int>(data['count']),
      );

  static ReactionCountStruct? maybeFromMap(dynamic data) => data is Map
      ? ReactionCountStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'emoji': _emoji,
        'count': _count,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'emoji': serializeParam(
          _emoji,
          ParamType.String,
        ),
        'count': serializeParam(
          _count,
          ParamType.int,
        ),
      }.withoutNulls;

  static ReactionCountStruct fromSerializableMap(Map<String, dynamic> data) =>
      ReactionCountStruct(
        emoji: deserializeParam(
          data['emoji'],
          ParamType.String,
          false,
        ),
        count: deserializeParam(
          data['count'],
          ParamType.int,
          false,
        ),
      );

  static ReactionCountStruct fromAlgoliaData(Map<String, dynamic> data) =>
      ReactionCountStruct(
        emoji: convertAlgoliaParam(
          data['emoji'],
          ParamType.String,
          false,
        ),
        count: convertAlgoliaParam(
          data['count'],
          ParamType.int,
          false,
        ),
        firestoreUtilData: FirestoreUtilData(
          clearUnsetFields: false,
          create: true,
        ),
      );

  @override
  String toString() => 'ReactionCountStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is ReactionCountStruct &&
        emoji == other.emoji &&
        count == other.count;
  }

  @override
  int get hashCode => const ListEquality().hash([emoji, count]);
}

ReactionCountStruct createReactionCountStruct({
  String? emoji,
  int? count,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    ReactionCountStruct(
      emoji: emoji,
      count: count,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

ReactionCountStruct? updateReactionCountStruct(
  ReactionCountStruct? reactionCount, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    reactionCount
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addReactionCountStructData(
  Map<String, dynamic> firestoreData,
  ReactionCountStruct? reactionCount,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (reactionCount == null) {
    return;
  }
  if (reactionCount.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && reactionCount.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final reactionCountData =
      getReactionCountFirestoreData(reactionCount, forFieldValue);
  final nestedData =
      reactionCountData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = reactionCount.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getReactionCountFirestoreData(
  ReactionCountStruct? reactionCount, [
  bool forFieldValue = false,
]) {
  if (reactionCount == null) {
    return {};
  }
  final firestoreData = mapToFirestore(reactionCount.toMap());

  // Add any Firestore field values
  mapToFirestore(reactionCount.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getReactionCountListFirestoreData(
  List<ReactionCountStruct>? reactionCounts,
) =>
    reactionCounts
        ?.map((e) => getReactionCountFirestoreData(e, true))
        .toList() ??
    [];
