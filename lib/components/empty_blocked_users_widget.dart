import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'empty_blocked_users_model.dart';
export 'empty_blocked_users_model.dart';

class EmptyBlockedUsersWidget extends StatefulWidget {
  const EmptyBlockedUsersWidget({super.key});

  @override
  State<EmptyBlockedUsersWidget> createState() =>
      _EmptyBlockedUsersWidgetState();
}

class _EmptyBlockedUsersWidgetState extends State<EmptyBlockedUsersWidget> {
  late EmptyBlockedUsersModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => EmptyBlockedUsersModel());

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
      width: double.infinity,
      height: 60.0,
      decoration: BoxDecoration(),
      child: Align(
        alignment: AlignmentDirectional(0.0, 0.0),
        child: Text(
          'No Blocked Users',
          style: FlutterFlowTheme.of(context).bodySmall.override(
                font: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                ),
                letterSpacing: 0.0,
                fontWeight: FontWeight.w500,
                fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
              ),
        ),
      ),
    );
  }
}
