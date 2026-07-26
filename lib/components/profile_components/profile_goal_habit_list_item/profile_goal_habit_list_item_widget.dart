import '/backend/backend.dart';
import '/components/habit_components/active_habit_list_item/active_habit_list_item_widget.dart';
import '/components/habit_components/habit_preview_component/habit_preview_component_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'profile_goal_habit_list_item_model.dart';
export 'profile_goal_habit_list_item_model.dart';

class ProfileGoalHabitListItemWidget extends StatefulWidget {
  const ProfileGoalHabitListItemWidget({
    super.key,
    required this.goal,
  });

  final GoalsRecord? goal;

  @override
  State<ProfileGoalHabitListItemWidget> createState() =>
      _ProfileGoalHabitListItemWidgetState();
}

class _ProfileGoalHabitListItemWidgetState
    extends State<ProfileGoalHabitListItemWidget> {
  late ProfileGoalHabitListItemModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ProfileGoalHabitListItemModel());

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
    return StreamBuilder<List<HabitsRecord>>(
      stream: queryHabitsRecord(
        queryBuilder: (habitsRecord) => habitsRecord.where(
          'goal',
          isEqualTo: widget!.goal?.reference,
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
        List<HabitsRecord> expandableHabitsRecordList = snapshot.data!;

        return Container(
          width: double.infinity,
          color: Colors.transparent,
          child: ExpandableNotifier(
            controller: _model.expandableExpandableController,
            child: ExpandablePanel(
              header: Container(
                width: double.infinity,
                height: 50.0,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).secondaryBackground,
                  borderRadius: BorderRadius.circular(valueOrDefault<double>(
                    FFAppConstants.borderRadius,
                    0.0,
                  )),
                ),
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(10.0, 0.0, 10.0, 0.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Image.asset(
                          'assets/images/goal_icon.png',
                          width: 20.0,
                          height: 20.0,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              8.0, 0.0, 0.0, 0.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Align(
                                alignment: AlignmentDirectional(-1.0, 0.0),
                                child: Text(
                                  valueOrDefault<String>(
                                    widget!.goal?.name,
                                    'No Goal',
                                  ),
                                  style: FlutterFlowTheme.of(context)
                                      .bodySmall
                                      .override(
                                        font: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodySmall
                                                  .fontStyle,
                                        ),
                                        color: FlutterFlowTheme.of(context)
                                            .secondary,
                                        letterSpacing: 0.0,
                                        fontWeight: FontWeight.bold,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodySmall
                                            .fontStyle,
                                      ),
                                ),
                              ),
                              Text(
                                'Habits: ${expandableHabitsRecordList.length.toString()}',
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      font: GoogleFonts.poppins(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down,
                        color: FlutterFlowTheme.of(context).secondary,
                      ),
                    ],
                  ),
                ),
              ),
              collapsed: Container(
                width: MediaQuery.sizeOf(context).width * 1.0,
                height: 0.0,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).secondaryBackground,
                ),
              ),
              expanded: Builder(
                builder: (context) {
                  final habits = expandableHabitsRecordList.toList();

                  return Column(
                    mainAxisSize: MainAxisSize.max,
                    children: List.generate(habits.length, (habitsIndex) {
                      final habitsItem = habits[habitsIndex];
                      return Builder(
                        builder: (context) => InkWell(
                          splashColor: Colors.transparent,
                          focusColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          onTap: () async {
                            logFirebaseEvent(
                                'PROFILE_GOAL_HABIT_LIST_ITEM_Container_5');
                            logFirebaseEvent(
                                'ActiveHabitListItem_alert_dialog');
                            await showDialog(
                              context: context,
                              builder: (dialogContext) {
                                return Dialog(
                                  elevation: 0,
                                  insetPadding: EdgeInsets.zero,
                                  backgroundColor: Colors.transparent,
                                  alignment: AlignmentDirectional(0.0, 0.0)
                                      .resolve(Directionality.of(context)),
                                  child: HabitPreviewComponentWidget(
                                    habit: habitsItem,
                                  ),
                                );
                              },
                            );
                          },
                          child: ActiveHabitListItemWidget(
                            key: Key(
                                'Key5k6_${habitsIndex}_of_${habits.length}'),
                            habit: habitsItem,
                          ),
                        ),
                      );
                    }).divide(SizedBox(height: 5.0)),
                  );
                },
              ),
              theme: ExpandableThemeData(
                tapHeaderToExpand: true,
                tapBodyToExpand: false,
                tapBodyToCollapse: false,
                headerAlignment: ExpandablePanelHeaderAlignment.center,
                hasIcon: false,
              ),
            ),
          ),
        );
      },
    );
  }
}
