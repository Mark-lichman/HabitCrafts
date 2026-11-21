import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/activity_list_item/activity_list_item_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'lifestyle_list_component_widget.dart' show LifestyleListComponentWidget;
import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class LifestyleListComponentModel
    extends FlutterFlowModel<LifestyleListComponentWidget> {
  ///  State fields for stateful widgets in this component.

  // State field(s) for Expandable widget. The widget sets the controller in its initState,
  // but a parent page creates and disposes this model even when the widget never builds
  // (the progress page's second tab), so dispose must cope with no controller.
  ExpandableController? _expandableController;
  ExpandableController get expandableExpandableController =>
      _expandableController!;
  set expandableExpandableController(ExpandableController controller) =>
      _expandableController = controller;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    _expandableController?.dispose();
  }
}
