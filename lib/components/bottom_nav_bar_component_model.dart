import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/components/people_icon_for_no_loading_indicator_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/index.dart';
import 'bottom_nav_bar_component_widget.dart' show BottomNavBarComponentWidget;
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class BottomNavBarComponentModel
    extends FlutterFlowModel<BottomNavBarComponentWidget> {
  ///  State fields for stateful widgets in this component.

  // Model for peopleIconForNoLoadingIndicator component.
  late PeopleIconForNoLoadingIndicatorModel
      peopleIconForNoLoadingIndicatorModel;

  @override
  void initState(BuildContext context) {
    peopleIconForNoLoadingIndicatorModel =
        createModel(context, () => PeopleIconForNoLoadingIndicatorModel());
  }

  @override
  void dispose() {
    peopleIconForNoLoadingIndicatorModel.dispose();
  }
}
