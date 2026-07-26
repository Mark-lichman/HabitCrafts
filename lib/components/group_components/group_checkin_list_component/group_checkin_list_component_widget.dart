import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/components/group_components/checkin_component/checkin_component_widget.dart';
import '/components/group_components/group_check_in_list_item/group_check_in_list_item_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'group_checkin_list_component_model.dart';
export 'group_checkin_list_component_model.dart';

class GroupCheckinListComponentWidget extends StatefulWidget {
  const GroupCheckinListComponentWidget({super.key});

  @override
  State<GroupCheckinListComponentWidget> createState() =>
      _GroupCheckinListComponentWidgetState();
}

class _GroupCheckinListComponentWidgetState
    extends State<GroupCheckinListComponentWidget> {
  late GroupCheckinListComponentModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => GroupCheckinListComponentModel());

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
      padding: EdgeInsetsDirectional.fromSTEB(0.0, 10.0, 0.0, 0.0),
      child: StreamBuilder<List<GroupMemberStateRecord>>(
        stream: queryGroupMemberStateRecord(
          queryBuilder: (groupMemberStateRecord) => groupMemberStateRecord
              .where(
                'checkin_day',
                isEqualTo: dateTimeFormat("EEEE", getCurrentTimestamp),
              )
              .where(
                'member',
                isEqualTo: currentUserReference,
              )
              .where(
                'recent_checkin',
                isNotEqualTo: dateTimeFormat("yMMMd", getCurrentTimestamp),
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
          List<GroupMemberStateRecord>
              checkinContainerGroupMemberStateRecordList = snapshot.data!;

          return Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Color(0x00FFFFFF),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                if (checkinContainerGroupMemberStateRecordList.length > 0)
                  Align(
                    alignment: AlignmentDirectional(-1.0, 0.0),
                    child: Text(
                      'Check-ins',
                      textAlign: TextAlign.start,
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            font: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .fontStyle,
                            ),
                            color: FlutterFlowTheme.of(context).alternate,
                            fontSize: 13.0,
                            letterSpacing: 0.0,
                            fontWeight: FontWeight.w600,
                            fontStyle: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .fontStyle,
                          ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(0.0, 4.0, 0.0, 0.0),
                  child: Builder(
                    builder: (context) {
                      final checkinContainerVar =
                          checkinContainerGroupMemberStateRecordList
                              .where((e) =>
                                  e.recentCheckin !=
                                  dateTimeFormat("yMMMd", getCurrentTimestamp))
                              .toList();

                      return Column(
                        mainAxisSize: MainAxisSize.max,
                        children: List.generate(checkinContainerVar.length,
                                (checkinContainerVarIndex) {
                          final checkinContainerVarItem =
                              checkinContainerVar[checkinContainerVarIndex];
                          return Builder(
                            builder: (context) => InkWell(
                              splashColor: Colors.transparent,
                              focusColor: Colors.transparent,
                              hoverColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              onTap: () async {
                                logFirebaseEvent(
                                    'GROUP_CHECKIN_LIST_COMPONENT_Container_e');
                                logFirebaseEvent(
                                    'groupCheckInListItem_alert_dialog');
                                await showDialog(
                                  context: context,
                                  builder: (dialogContext) {
                                    return Dialog(
                                      elevation: 0,
                                      insetPadding: EdgeInsets.zero,
                                      backgroundColor: Colors.transparent,
                                      alignment: AlignmentDirectional(0.0, 0.0)
                                          .resolve(Directionality.of(context)),
                                      child: CheckinComponentWidget(
                                        group: checkinContainerVarItem.group!,
                                        refreshCheckins: () async {},
                                      ),
                                    );
                                  },
                                );
                              },
                              child: GroupCheckInListItemWidget(
                                key: Key(
                                    'Keye9u_${checkinContainerVarIndex}_of_${checkinContainerVar.length}'),
                                groupMemberState: checkinContainerVarItem,
                              ),
                            ),
                          );
                        })
                            .divide(SizedBox(height: 5.0))
                            .addToEnd(SizedBox(height: 10.0)),
                      );
                    },
                  ),
                ),
                if (checkinContainerGroupMemberStateRecordList.length > 0)
                  Container(
                    width: double.infinity,
                    height: 1.0,
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).accent1,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
