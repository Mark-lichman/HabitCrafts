import '/backend/backend.dart';
import '/components/bottom_nav_bar_component_widget.dart';
import '/components/group_components/in_app_notification_component/in_app_notification_component_widget.dart';
import '/components/lesson_category_list_item_widget.dart';
import '/components/resources_list_item/resources_list_item_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:async';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/index.dart';
import 'library_page_widget.dart' show LibraryPageWidget;
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:text_search/text_search.dart';

class LibraryPageModel extends FlutterFlowModel<LibraryPageWidget> {
  ///  Local state fields for this page.

  int weekIndex = 0;

  bool isShowFullList = true;

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
  List<CategoriesRecord> simpleSearchResults = [];
  // Model for bottomNavBarComponent component.
  late BottomNavBarComponentModel bottomNavBarComponentModel;
  // Model for inAppNotificationComponent component.
  late InAppNotificationComponentModel inAppNotificationComponentModel;

  @override
  void initState(BuildContext context) {
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

    bottomNavBarComponentModel.dispose();
    inAppNotificationComponentModel.dispose();
  }
}
