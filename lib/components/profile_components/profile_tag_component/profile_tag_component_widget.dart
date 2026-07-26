import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'profile_tag_component_model.dart';
export 'profile_tag_component_model.dart';

class ProfileTagComponentWidget extends StatefulWidget {
  const ProfileTagComponentWidget({
    super.key,
    required this.title,
  });

  final String? title;

  @override
  State<ProfileTagComponentWidget> createState() =>
      _ProfileTagComponentWidgetState();
}

class _ProfileTagComponentWidgetState extends State<ProfileTagComponentWidget> {
  late ProfileTagComponentModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ProfileTagComponentModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20.0,
      decoration: BoxDecoration(
        color: Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Visibility(
        visible: widget!.title != null && widget!.title != '',
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(6.0, 0.0, 6.0, 0.0),
          child: Text(
            valueOrDefault<String>(
              widget!.title,
              'title',
            ),
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  font: GoogleFonts.poppins(
                    fontWeight:
                        FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                  ),
                  color: Color(0xFF8B8585),
                  letterSpacing: 0.0,
                  fontWeight:
                      FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                  fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                ),
          ),
        ),
      ),
    );
  }
}
