import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/group_components/group_invite_list_item2/group_invite_list_item2_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'group_invite_component_model.dart';
export 'group_invite_component_model.dart';

class GroupInviteComponentWidget extends StatefulWidget {
  const GroupInviteComponentWidget({super.key});

  @override
  State<GroupInviteComponentWidget> createState() =>
      _GroupInviteComponentWidgetState();
}

class _GroupInviteComponentWidgetState
    extends State<GroupInviteComponentWidget> {
  late GroupInviteComponentModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => GroupInviteComponentModel());

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
        color: FlutterFlowTheme.of(context).primary,
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(20.0, 20.0, 20.0, 20.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invite friends to join a group!',
                textAlign: TextAlign.start,
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                      ),
                      color: FlutterFlowTheme.of(context).alternate,
                      fontSize: 14.0,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.w600,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                    ),
              ),
              StreamBuilder<List<GroupsRecord>>(
                stream: queryGroupsRecord(
                  queryBuilder: (groupsRecord) => groupsRecord.where(
                    'creator',
                    isEqualTo: currentUserReference,
                  ),
                ),
                builder: (context, snapshot) {
                  // Customize what your widget looks like when it's loading.
                  if (!snapshot.hasData) {
                    return Center(
                      child: SizedBox(
                        width: 40.0,
                        height: 40.0,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            FlutterFlowTheme.of(context).primary,
                          ),
                        ),
                      ),
                    );
                  }
                  List<GroupsRecord> columnGroupsRecordList = snapshot.data!;

                  return Column(
                    mainAxisSize: MainAxisSize.max,
                    children: List.generate(columnGroupsRecordList.length,
                            (columnIndex) {
                      final columnGroupsRecord =
                          columnGroupsRecordList[columnIndex];
                      return GroupInviteListItem2Widget(
                        key: Key(
                            'Keyddh_${columnIndex}_of_${columnGroupsRecordList.length}'),
                        group: columnGroupsRecord,
                      );
                    })
                        .divide(SizedBox(height: 5.0))
                        .addToEnd(SizedBox(height: 120.0)),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
