import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'profile_button_model.dart';
export 'profile_button_model.dart';

class ProfileButtonWidget extends StatefulWidget {
  const ProfileButtonWidget({super.key});

  @override
  State<ProfileButtonWidget> createState() => _ProfileButtonWidgetState();
}

class _ProfileButtonWidgetState extends State<ProfileButtonWidget> {
  late ProfileButtonModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ProfileButtonModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FFButtonWidget(
      onPressed: () async {
        logFirebaseEvent('PROFILE_BUTTON_COMP__BTN_ON_TAP');
        logFirebaseEvent('Button_navigate_to');

        context.pushNamed(ProfilePageWidget.routeName);
      },
      text: '',
      icon: Icon(
        Icons.person_rounded,
        size: 15.0,
      ),
      options: FFButtonOptions(
        width: 40.0,
        height: 40.0,
        padding: EdgeInsetsDirectional.fromSTEB(8.0, 0.0, 0.0, 0.0),
        iconPadding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
        iconColor: Color(0xFFAEAEB2),
        color: FlutterFlowTheme.of(context).alternate,
        textStyle: FlutterFlowTheme.of(context).titleSmall.override(
              font: GoogleFonts.poppins(
                fontWeight: FlutterFlowTheme.of(context).titleSmall.fontWeight,
                fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
              ),
              color: Colors.white,
              letterSpacing: 0.0,
              fontWeight: FlutterFlowTheme.of(context).titleSmall.fontWeight,
              fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
            ),
        elevation: 0.0,
        borderSide: BorderSide(
          color: Colors.transparent,
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(20.0),
      ),
    );
  }
}
