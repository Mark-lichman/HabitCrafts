import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/custom_cloud_functions/custom_cloud_function_response_manager.dart';
import '/backend/schema/structs/index.dart';
import '/components/bottom_nav_bar_component_widget.dart';
import '/components/eula_modal_widget.dart';
import '/components/group_components/in_app_notification_component/in_app_notification_component_widget.dart';
import '/components/habit_components/explore_habit_component/explore_habit_component_widget.dart';
import '/components/habit_components/goal_habit_list_item/goal_habit_list_item_widget.dart';
import '/components/habit_components/habit_completed_snack_bar/habit_completed_snack_bar_widget.dart';
import '/components/lesson_category_list_item_widget.dart';
import '/components/notes_modal_component/notes_modal_component_widget.dart';
import '/components/toolip_component_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:async';
import 'dart:ui';
import '/actions/actions.dart' as action_blocks;
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import 'home_page_widget.dart' show HomePageWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class HomePageModel extends FlutterFlowModel<HomePageWidget> {
  ///  Local state fields for this page.

  String exploreString = 'Explore';

  int weekIndex = 1;

  String buildNumber = 'buildNumber not set';

  ///  State fields for stateful widgets in this page.

  List<HabitsRecord>? homePagePreviousSnapshot;
  // Stores action output result for [Custom Action - getBuildNumber] action in homePage widget.
  String? buildNumberOutput;
  // Stores action output result for [Custom Action - setWeekIndex] action in homePage widget.
  int? calculatedWeekIndex;
  // Stores action output result for [Firestore Query - Query a collection] action in homePage widget.
  int? usersInSearch;
  // Stores action output result for [Cloud Function - cleanInvalidChatEntries] action in Container widget.
  CleanInvalidChatEntriesCloudFunctionCallResponse? cloudFunctionpas;
  // State field(s) for TabBar widget.
  TabController? tabBarController;
  int get tabBarCurrentIndex =>
      tabBarController != null ? tabBarController!.index : 0;
  int get tabBarPreviousIndex =>
      tabBarController != null ? tabBarController!.previousIndex : 0;

  // Model for welcomeToolipComponent.
  late ToolipComponentModel welcomeToolipComponentModel;
  // Model for firstHabitLeftToolipComponent.
  late ToolipComponentModel firstHabitLeftToolipComponentModel;
  // Model for exploreHabitComponent component.
  late ExploreHabitComponentModel exploreHabitComponentModel;
  // Model for bottomNavBarComponent component.
  late BottomNavBarComponentModel bottomNavBarComponentModel;
  // Model for inAppNotificationComponent component.
  late InAppNotificationComponentModel inAppNotificationComponentModel;

  @override
  void initState(BuildContext context) {
    welcomeToolipComponentModel =
        createModel(context, () => ToolipComponentModel());
    firstHabitLeftToolipComponentModel =
        createModel(context, () => ToolipComponentModel());
    exploreHabitComponentModel =
        createModel(context, () => ExploreHabitComponentModel());
    bottomNavBarComponentModel =
        createModel(context, () => BottomNavBarComponentModel());
    inAppNotificationComponentModel =
        createModel(context, () => InAppNotificationComponentModel());
  }

  @override
  void dispose() {
    tabBarController?.dispose();
    welcomeToolipComponentModel.dispose();
    firstHabitLeftToolipComponentModel.dispose();
    exploreHabitComponentModel.dispose();
    bottomNavBarComponentModel.dispose();
    inAppNotificationComponentModel.dispose();
  }
}
