import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/empty_blocked_users_widget.dart';
import '/components/profile_components/profile_goal_habit_list_item/profile_goal_habit_list_item_widget.dart';
import '/components/profile_components/profile_image_component/profile_image_component_widget.dart';
import '/components/profile_components/profile_line_item/profile_line_item_widget.dart';
import '/components/profile_components/profile_settings_user_details_component/profile_settings_user_details_component_widget.dart';
import '/components/profile_components/profile_settings_visibility_component/profile_settings_visibility_component_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/index.dart';
import 'profile_page_widget.dart' show ProfilePageWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfilePageModel extends FlutterFlowModel<ProfilePageWidget> {
  ///  State fields for stateful widgets in this page.

  // State field(s) for TabBar widget.
  TabController? tabBarController;
  int get tabBarCurrentIndex =>
      tabBarController != null ? tabBarController!.index : 0;
  int get tabBarPreviousIndex =>
      tabBarController != null ? tabBarController!.previousIndex : 0;

  // Model for profileImageComponent component.
  late ProfileImageComponentModel profileImageComponentModel1;
  // Model for profileImageComponent component.
  late ProfileImageComponentModel profileImageComponentModel2;
  // Model for profileLineItem component.
  late ProfileLineItemModel profileLineItemModel1;
  // Model for profileLineItem component.
  late ProfileLineItemModel profileLineItemModel2;
  // Stores action output result for [Firestore Query - Query a collection] action in Button widget.
  List<HabitsRecord>? habits;
  // Stores action output result for [Firestore Query - Query a collection] action in Button widget.
  List<GroupMemberStateRecord>? groupMemberStates;
  // Model for profileImageComponent component.
  late ProfileImageComponentModel profileImageComponentModel3;
  // State field(s) for Expandable widget.
  late ExpandableController expandableExpandableController1;

  // Model for profileLineItem component.
  late ProfileLineItemModel profileLineItemModel3;
  // Model for profileSettingsUserDetailsComponent component.
  late ProfileSettingsUserDetailsComponentModel
      profileSettingsUserDetailsComponentModel;
  // State field(s) for Expandable widget.
  late ExpandableController expandableExpandableController2;

  // Model for profileLineItem component.
  late ProfileLineItemModel profileLineItemModel4;
  // Model for profileSettingsVisibilityComponent component.
  late ProfileSettingsVisibilityComponentModel
      profileSettingsVisibilityComponentModel;
  // State field(s) for Expandable widget.
  late ExpandableController expandableExpandableController3;

  // Model for profileLineItem component.
  late ProfileLineItemModel profileLineItemModel5;
  // Model for profileLineItem component.
  late ProfileLineItemModel profileLineItemModel6;

  @override
  void initState(BuildContext context) {
    profileImageComponentModel1 =
        createModel(context, () => ProfileImageComponentModel());
    profileImageComponentModel2 =
        createModel(context, () => ProfileImageComponentModel());
    profileLineItemModel1 = createModel(context, () => ProfileLineItemModel());
    profileLineItemModel2 = createModel(context, () => ProfileLineItemModel());
    profileImageComponentModel3 =
        createModel(context, () => ProfileImageComponentModel());
    profileLineItemModel3 = createModel(context, () => ProfileLineItemModel());
    profileSettingsUserDetailsComponentModel =
        createModel(context, () => ProfileSettingsUserDetailsComponentModel());
    profileLineItemModel4 = createModel(context, () => ProfileLineItemModel());
    profileSettingsVisibilityComponentModel =
        createModel(context, () => ProfileSettingsVisibilityComponentModel());
    profileLineItemModel5 = createModel(context, () => ProfileLineItemModel());
    profileLineItemModel6 = createModel(context, () => ProfileLineItemModel());
  }

  @override
  void dispose() {
    tabBarController?.dispose();
    profileImageComponentModel1.dispose();
    profileImageComponentModel2.dispose();
    profileLineItemModel1.dispose();
    profileLineItemModel2.dispose();
    profileImageComponentModel3.dispose();
    expandableExpandableController1.dispose();
    profileLineItemModel3.dispose();
    profileSettingsUserDetailsComponentModel.dispose();
    expandableExpandableController2.dispose();
    profileLineItemModel4.dispose();
    profileSettingsVisibilityComponentModel.dispose();
    expandableExpandableController3.dispose();
    profileLineItemModel5.dispose();
    profileLineItemModel6.dispose();
  }
}
