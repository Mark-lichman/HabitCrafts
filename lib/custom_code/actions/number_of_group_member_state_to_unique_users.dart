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

Future<int> numberOfGroupMemberStateToUniqueUsers(
    List<GroupMemberStateRecord> groupMemberStates) async {
  List<dynamic> uniqueMembers = [];

  // Iterate through the list and add unique members to uniqueMembers list
  for (var item in groupMemberStates) {
    if (!uniqueMembers.contains(item.member)) {
      uniqueMembers.add(item.member);
    }
  }

  int uniqueMemberCount = uniqueMembers.length;
  return uniqueMemberCount;
}
