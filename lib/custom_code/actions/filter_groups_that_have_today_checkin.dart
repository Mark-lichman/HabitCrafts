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

Future<List<GroupMemberStateRecord>> filterGroupsThatHaveTodayCheckin(
    List<GroupMemberStateRecord> groupMemberStates) async {
  // Add your function code here!
  final now = DateTime.now();
  List<GroupMemberStateRecord> groupList = [];
  for (GroupMemberStateRecord groupMemberState in groupMemberStates) {
    // now pull the group object and check the checkin date to see if it's today
    var groupSnapshot = await groupMemberState.group!.get();

    Map<String, dynamic>? groupDoc =
        groupSnapshot.data() as Map<String, dynamic>?;
    if (groupDoc != null && groupDoc!.containsKey('checkin_time')) {
      final nowDay = now.day; //DateFormat(DateFormat.ABBR_WEEKDAY).format(now);
      final checkinDay = groupSnapshot.get('checkin_time');
      print("nowDay: " + nowDay.toString());
      print("checkinDay: " + checkinDay.toString());
      if (nowDay == checkinDay.toDate().day) {
        groupList.add(groupMemberState);
      }
    }
  }

  return groupList;
}
