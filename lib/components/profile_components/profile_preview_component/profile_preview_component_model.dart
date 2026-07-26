import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/profile_components/profile_tag_component/profile_tag_component_widget.dart';
import '/components/user_icon_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/actions/actions.dart' as action_blocks;
import '/flutter_flow/custom_functions.dart' as functions;
import 'profile_preview_component_widget.dart'
    show ProfilePreviewComponentWidget;
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ProfilePreviewComponentModel
    extends FlutterFlowModel<ProfilePreviewComponentWidget> {
  ///  State fields for stateful widgets in this component.

  // Model for userIcon component.
  late UserIconModel userIconModel;
  // Model for profileTagComponent component.
  late ProfileTagComponentModel profileTagComponentModel1;
  // Model for profileTagComponent component.
  late ProfileTagComponentModel profileTagComponentModel2;
  // Model for profileTagComponent component.
  late ProfileTagComponentModel profileTagComponentModel3;
  // Model for profileTagComponent component.
  late ProfileTagComponentModel profileTagComponentModel4;
  // Model for profileTagComponent component.
  late ProfileTagComponentModel profileTagComponentModel5;

  @override
  void initState(BuildContext context) {
    userIconModel = createModel(context, () => UserIconModel());
    profileTagComponentModel1 =
        createModel(context, () => ProfileTagComponentModel());
    profileTagComponentModel2 =
        createModel(context, () => ProfileTagComponentModel());
    profileTagComponentModel3 =
        createModel(context, () => ProfileTagComponentModel());
    profileTagComponentModel4 =
        createModel(context, () => ProfileTagComponentModel());
    profileTagComponentModel5 =
        createModel(context, () => ProfileTagComponentModel());
  }

  @override
  void dispose() {
    userIconModel.dispose();
    profileTagComponentModel1.dispose();
    profileTagComponentModel2.dispose();
    profileTagComponentModel3.dispose();
    profileTagComponentModel4.dispose();
    profileTagComponentModel5.dispose();
  }
}
