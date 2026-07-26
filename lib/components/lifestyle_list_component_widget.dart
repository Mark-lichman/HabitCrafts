import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/activity_list_item/activity_list_item_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'lifestyle_list_component_model.dart';
export 'lifestyle_list_component_model.dart';

class LifestyleListComponentWidget extends StatefulWidget {
  const LifestyleListComponentWidget({super.key});

  @override
  State<LifestyleListComponentWidget> createState() =>
      _LifestyleListComponentWidgetState();
}

class _LifestyleListComponentWidgetState
    extends State<LifestyleListComponentWidget> {
  late LifestyleListComponentModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => LifestyleListComponentModel());

    _model.expandableExpandableController =
        ExpandableController(initialExpanded: false)
          ..addListener(() => safeSetState(() {}));
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
      padding: EdgeInsetsDirectional.fromSTEB(0.0, 20.0, 0.0, 0.0),
      child: Container(
        decoration: BoxDecoration(),
        child: Container(
          width: double.infinity,
          color: Color(0x00000000),
          child: ExpandableNotifier(
            controller: _model.expandableExpandableController,
            child: ExpandablePanel(
              header: Align(
                alignment: AlignmentDirectional(-1.0, 0.0),
                child: Text(
                  'Activity',
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        font: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                        ),
                        color: FlutterFlowTheme.of(context).alternate,
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.w600,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                      ),
                ),
              ),
              collapsed: Container(),
              expanded: Container(
                decoration: BoxDecoration(),
                child: StreamBuilder<List<UserActivityRecord>>(
                  stream: queryUserActivityRecord(
                    parent: currentUserReference,
                    queryBuilder: (userActivityRecord) =>
                        userActivityRecord.orderBy('created', descending: true),
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
                    List<UserActivityRecord> columnUserActivityRecordList =
                        snapshot.data!;

                    return Column(
                      mainAxisSize: MainAxisSize.max,
                      children:
                          List.generate(columnUserActivityRecordList.length,
                                  (columnIndex) {
                        final columnUserActivityRecord =
                            columnUserActivityRecordList[columnIndex];
                        return ActivityListItemWidget(
                          key: Key(
                              'Key1t9_${columnIndex}_of_${columnUserActivityRecordList.length}'),
                          activity: columnUserActivityRecord,
                        );
                      })
                              .divide(SizedBox(height: 10.0))
                              .addToStart(SizedBox(height: 10.0)),
                    );
                  },
                ),
              ),
              theme: ExpandableThemeData(
                tapHeaderToExpand: true,
                tapBodyToExpand: false,
                tapBodyToCollapse: false,
                headerAlignment: ExpandablePanelHeaderAlignment.center,
                hasIcon: true,
                iconColor: FlutterFlowTheme.of(context).tertiary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
