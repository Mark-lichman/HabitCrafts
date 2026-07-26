// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/actions/actions.dart' as action_blocks;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

Future<List<GroupMemberStateRecord>>
    groupMemberStatesWithPreviousCheckinsRemoved(
  List<CheckinsRecord> todayCheckins,
  List<GroupMemberStateRecord> groupMemberStates,
) async {
  // I need to filter out the groupMemberStates if one of the todayCheckins also have a group that matches one of the groupMemberStates field

  List<GroupMemberStateRecord> filteredGroupMemberStates = [];

  for (GroupMemberStateRecord groupMemberState in groupMemberStates) {
    bool hasMatchingCheckin = todayCheckins.any((checkin) =>
        checkin.group == groupMemberState.group &&
        checkin.user == groupMemberState.member);

    if (!hasMatchingCheckin) {
      filteredGroupMemberStates.add(groupMemberState);
    }
  }

  return filteredGroupMemberStates;
}
