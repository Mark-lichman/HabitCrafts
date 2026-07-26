import 'package:collection/collection.dart';

enum GroupMembershipStatus {
  Leader,
  Member,
  Pending,
  Creator,
  Denied,
  Invited,
  Banned,
}

enum ActivityTypes {
  AddedNewHabit,
  CompletedCheckin,
  JoinedGroup,
  CompletedHabit,
  FinishedHabit,
}

extension FFEnumExtensions<T extends Enum> on T {
  String serialize() => name;
}

extension FFEnumListExtensions<T extends Enum> on Iterable<T> {
  T? deserialize(String? value) =>
      firstWhereOrNull((e) => e.serialize() == value);
}

T? deserializeEnum<T>(String? value) {
  switch (T) {
    case (GroupMembershipStatus):
      return GroupMembershipStatus.values.deserialize(value) as T?;
    case (ActivityTypes):
      return ActivityTypes.values.deserialize(value) as T?;
    default:
      return null;
  }
}
