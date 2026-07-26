import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/components/bottom_nav_bar_component_widget.dart';
import '/components/group_components/empty_groups_component/empty_groups_component_widget.dart';
import '/components/group_components/group_checkin_list_component/group_checkin_list_component_widget.dart';
import '/components/group_components/group_create_modal/group_create_modal_widget.dart';
import '/components/group_components/group_invite_list_item/group_invite_list_item_widget.dart';
import '/components/group_components/group_list_contents/group_list_contents_widget.dart';
import '/components/group_components/group_management_component/group_management_component_widget.dart';
import '/components/group_components/in_app_notification_component/in_app_notification_component_widget.dart';
import '/components/group_components/search_list_item/search_list_item_widget.dart';
import '/components/monthly_challenge_list_item_widget.dart';
import '/components/no_webinars_component_widget.dart';
import '/components/webinar_list_item_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:async';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import 'groups_page_widget.dart' show GroupsPageWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class GroupsPageModel extends FlutterFlowModel<GroupsPageWidget> {
  ///  Local state fields for this page.

  bool isShowFullList = true;

  List<GroupMembershipStatus> memberLeaderCreator = [
    GroupMembershipStatus.Leader,
    GroupMembershipStatus.Member,
    GroupMembershipStatus.Creator
  ];
  void addToMemberLeaderCreator(GroupMembershipStatus item) =>
      memberLeaderCreator.add(item);
  void removeFromMemberLeaderCreator(GroupMembershipStatus item) =>
      memberLeaderCreator.remove(item);
  void removeAtIndexFromMemberLeaderCreator(int index) =>
      memberLeaderCreator.removeAt(index);
  void insertAtIndexInMemberLeaderCreator(
          int index, GroupMembershipStatus item) =>
      memberLeaderCreator.insert(index, item);
  void updateMemberLeaderCreatorAtIndex(
          int index, Function(GroupMembershipStatus) updateFn) =>
      memberLeaderCreator[index] = updateFn(memberLeaderCreator[index]);

  List<GroupMemberStateRecord> todaysCheckins = [];
  void addToTodaysCheckins(GroupMemberStateRecord item) =>
      todaysCheckins.add(item);
  void removeFromTodaysCheckins(GroupMemberStateRecord item) =>
      todaysCheckins.remove(item);
  void removeAtIndexFromTodaysCheckins(int index) =>
      todaysCheckins.removeAt(index);
  void insertAtIndexInTodaysCheckins(int index, GroupMemberStateRecord item) =>
      todaysCheckins.insert(index, item);
  void updateTodaysCheckinsAtIndex(
          int index, Function(GroupMemberStateRecord) updateFn) =>
      todaysCheckins[index] = updateFn(todaysCheckins[index]);

  bool executeSearch = false;

  ///  State fields for stateful widgets in this page.

  // State field(s) for TabBar widget.
  TabController? tabBarController;
  int get tabBarCurrentIndex =>
      tabBarController != null ? tabBarController!.index : 0;
  int get tabBarPreviousIndex =>
      tabBarController != null ? tabBarController!.previousIndex : 0;

  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode;
  TextEditingController? textController;
  String? Function(BuildContext, String?)? textControllerValidator;
  // Algolia Search Results from action on TextField
  List<UserGroupSearchRecord>? algoliaSearchResults = [];
  // Model for groupCheckinListComponent component.
  late GroupCheckinListComponentModel groupCheckinListComponentModel;
  // Model for groupManagementComponent component.
  late GroupManagementComponentModel groupManagementComponentModel;
  // Model for bottomNavBarComponent component.
  late BottomNavBarComponentModel bottomNavBarComponentModel;
  // Model for inAppNotificationComponent component.
  late InAppNotificationComponentModel inAppNotificationComponentModel;

  @override
  void initState(BuildContext context) {
    groupCheckinListComponentModel =
        createModel(context, () => GroupCheckinListComponentModel());
    groupManagementComponentModel =
        createModel(context, () => GroupManagementComponentModel());
    bottomNavBarComponentModel =
        createModel(context, () => BottomNavBarComponentModel());
    inAppNotificationComponentModel =
        createModel(context, () => InAppNotificationComponentModel());
  }

  @override
  void dispose() {
    tabBarController?.dispose();
    textFieldFocusNode?.dispose();
    textController?.dispose();

    groupCheckinListComponentModel.dispose();
    groupManagementComponentModel.dispose();
    bottomNavBarComponentModel.dispose();
    inAppNotificationComponentModel.dispose();
  }

  /// Action blocks.
  Future fetchTodaysCheckins(BuildContext context) async {
    List<GroupMemberStateRecord>? groupMembersStates;
    List<GroupMemberStateRecord>? filteredGroupMemberStates;
    List<CheckinsRecord>? userCheckins;
    List<GroupMemberStateRecord>? filterGroupMemberStatesWithTodayRemoved;

    logFirebaseEvent('fetchTodaysCheckins_firestore_query');
    groupMembersStates = await queryGroupMemberStateRecordOnce(
      queryBuilder: (groupMemberStateRecord) => groupMemberStateRecord
          .where(
            'member',
            isEqualTo: currentUserReference,
          )
          .whereIn(
              'status',
              FFAppState()
                  .ownerLeaderMemberTypes
                  .map((e) => e.serialize())
                  .toList()),
    );
    logFirebaseEvent('fetchTodaysCheckins_custom_action');
    filteredGroupMemberStates = await actions.filterGroupsThatHaveTodayCheckin(
      groupMembersStates!.unique((e) => e.group!).toList(),
    );
    logFirebaseEvent('fetchTodaysCheckins_firestore_query');
    userCheckins = await queryCheckinsRecordOnce(
      queryBuilder: (checkinsRecord) => checkinsRecord
          .where(
            'user',
            isEqualTo: currentUserReference,
          )
          .whereIn(
              'group',
              filteredGroupMemberStates
                  ?.map((e) => e.group)
                  .withoutNulls
                  .toList())
          .where(
            'date',
            isGreaterThan: functions.startOfDay(),
          ),
    );
    logFirebaseEvent('fetchTodaysCheckins_custom_action');
    filterGroupMemberStatesWithTodayRemoved =
        await actions.groupMemberStatesWithPreviousCheckinsRemoved(
      userCheckins!.toList(),
      filteredGroupMemberStates!.toList(),
    );
    logFirebaseEvent('fetchTodaysCheckins_update_page_state');
    todaysCheckins = filterGroupMemberStatesWithTodayRemoved!
        .toList()
        .cast<GroupMemberStateRecord>();
  }
}
