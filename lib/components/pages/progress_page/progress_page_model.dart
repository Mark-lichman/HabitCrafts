import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/bottom_nav_bar_component_widget.dart';
import '/components/group_components/in_app_notification_component/in_app_notification_component_widget.dart';
import '/components/habit_components/finished_habit_list_item/finished_habit_list_item_widget.dart';
import '/components/lifestyle_list_component_widget.dart';
import '/components/notes_modal_component/notes_modal_component_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/index.dart';
import 'progress_page_widget.dart' show ProgressPageWidget;
import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ProgressPageModel extends FlutterFlowModel<ProgressPageWidget> {
  ///  State fields for stateful widgets in this page.

  // State field(s) for TabBar widget.
  TabController? tabBarController;
  int get tabBarCurrentIndex =>
      tabBarController != null ? tabBarController!.index : 0;
  int get tabBarPreviousIndex =>
      tabBarController != null ? tabBarController!.previousIndex : 0;

  // Model for lifestyleListComponent component.
  late LifestyleListComponentModel lifestyleListComponentModel1;
  // State field(s) for Expandable widget.
  late ExpandableController expandableExpandableController;

  // Model for lifestyleListComponent component.
  late LifestyleListComponentModel lifestyleListComponentModel2;
  // Model for bottomNavBarComponent component.
  late BottomNavBarComponentModel bottomNavBarComponentModel;
  // Model for inAppNotificationComponent component.
  late InAppNotificationComponentModel inAppNotificationComponentModel;

  @override
  void initState(BuildContext context) {
    lifestyleListComponentModel1 =
        createModel(context, () => LifestyleListComponentModel());
    lifestyleListComponentModel2 =
        createModel(context, () => LifestyleListComponentModel());
    bottomNavBarComponentModel =
        createModel(context, () => BottomNavBarComponentModel());
    inAppNotificationComponentModel =
        createModel(context, () => InAppNotificationComponentModel());
  }

  @override
  void dispose() {
    tabBarController?.dispose();
    lifestyleListComponentModel1.dispose();
    expandableExpandableController.dispose();
    lifestyleListComponentModel2.dispose();
    bottomNavBarComponentModel.dispose();
    inAppNotificationComponentModel.dispose();
  }
}
