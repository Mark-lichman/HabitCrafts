import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'profile_line_item_model.dart';
export 'profile_line_item_model.dart';

class ProfileLineItemWidget extends StatefulWidget {
  const ProfileLineItemWidget({
    super.key,
    String? title,
    bool? showArrow,
  })  : this.title = title ?? 'title',
        this.showArrow = showArrow ?? true;

  final String title;
  final bool showArrow;

  @override
  State<ProfileLineItemWidget> createState() => _ProfileLineItemWidgetState();
}

class _ProfileLineItemWidgetState extends State<ProfileLineItemWidget> {
  late ProfileLineItemModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ProfileLineItemModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(0.0, 5.0, 0.0, 0.0),
      child: Container(
        width: double.infinity,
        height: 54.0,
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).grayLight,
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 0.0),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget!.title,
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                      ),
                      color: FlutterFlowTheme.of(context).alternate,
                      fontSize: 17.0,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.w600,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                    ),
              ),
              if (widget!.showArrow)
                Icon(
                  Icons.arrow_circle_right_outlined,
                  color: FlutterFlowTheme.of(context).secondaryText,
                  size: 34.0,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
