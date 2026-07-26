import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'people_icon_for_no_loading_indicator_model.dart';
export 'people_icon_for_no_loading_indicator_model.dart';

class PeopleIconForNoLoadingIndicatorWidget extends StatefulWidget {
  const PeopleIconForNoLoadingIndicatorWidget({super.key});

  @override
  State<PeopleIconForNoLoadingIndicatorWidget> createState() =>
      _PeopleIconForNoLoadingIndicatorWidgetState();
}

class _PeopleIconForNoLoadingIndicatorWidgetState
    extends State<PeopleIconForNoLoadingIndicatorWidget> {
  late PeopleIconForNoLoadingIndicatorModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PeopleIconForNoLoadingIndicatorModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional(0.0, 1.0),
      child: Icon(
        Icons.people_outline,
        color: FlutterFlowTheme.of(context).secondary,
        size: 24.0,
      ),
    );
  }
}
