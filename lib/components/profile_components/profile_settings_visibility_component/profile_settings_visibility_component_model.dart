import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/flutter_flow/custom_functions.dart' as functions;
import 'profile_settings_visibility_component_widget.dart'
    show ProfileSettingsVisibilityComponentWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ProfileSettingsVisibilityComponentModel
    extends FlutterFlowModel<ProfileSettingsVisibilityComponentWidget> {
  ///  State fields for stateful widgets in this component.

  // State field(s) for goalSwitch widget.
  bool? goalSwitchValue;
  // State field(s) for habitSwitch widget.
  bool? habitSwitchValue;
  // State field(s) for profileSwitch widget.
  bool? profileSwitchValue;
  // State field(s) for ageSwitch widget.
  bool? ageSwitchValue;
  // State field(s) for genderSwitch widget.
  bool? genderSwitchValue;
  // State field(s) for Switch widget.
  bool? switchValue;
  // State field(s) for weightSwitch widget.
  bool? weightSwitchValue;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
