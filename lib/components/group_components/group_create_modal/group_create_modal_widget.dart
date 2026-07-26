import '/components/group_components/create_group_component/create_group_component_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'group_create_modal_model.dart';
export 'group_create_modal_model.dart';

class GroupCreateModalWidget extends StatefulWidget {
  const GroupCreateModalWidget({
    super.key,
    required this.isModal,
    required this.groupCreatedCallback,
  });

  final bool? isModal;
  final Future Function()? groupCreatedCallback;

  @override
  State<GroupCreateModalWidget> createState() => _GroupCreateModalWidgetState();
}

class _GroupCreateModalWidgetState extends State<GroupCreateModalWidget> {
  late GroupCreateModalModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => GroupCreateModalModel());

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
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).alternate,
        borderRadius: BorderRadius.circular(valueOrDefault<double>(
          FFAppConstants.borderRadius,
          0.0,
        )),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(0.0, 5.0, 0.0, 0.0),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(10.0, 0.0, 0.0, 0.0),
                  child: Text(
                    'Create New Group',
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          font: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontStyle: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .fontStyle,
                          ),
                          fontSize: 18.0,
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.w600,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                        ),
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional(1.0, -1.0),
                  child: Padding(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 10.0, 0.0),
                    child: FlutterFlowIconButton(
                      borderColor: FlutterFlowTheme.of(context).alternate,
                      borderRadius: 20.0,
                      borderWidth: 0.0,
                      buttonSize: 40.0,
                      icon: Icon(
                        Icons.close,
                        color: FlutterFlowTheme.of(context).grayDark,
                        size: 24.0,
                      ),
                      onPressed: () async {
                        logFirebaseEvent(
                            'GROUP_CREATE_MODAL_COMP_close_ICN_ON_TAP');
                        logFirebaseEvent('IconButton_dismiss_dialog');
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: wrapWithModel(
              model: _model.createGroupComponentModel,
              updateCallback: () => safeSetState(() {}),
              child: CreateGroupComponentWidget(
                groupCreatedCallback: () async {},
              ),
            ),
          ),
        ],
      ),
    );
  }
}
