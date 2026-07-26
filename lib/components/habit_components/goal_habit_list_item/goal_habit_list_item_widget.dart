import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'goal_habit_list_item_model.dart';
export 'goal_habit_list_item_model.dart';

class GoalHabitListItemWidget extends StatefulWidget {
  const GoalHabitListItemWidget({
    super.key,
    required this.goal,
    required this.showFinishedSnackbarAction,
    required this.showCompletedSnackbarAction,
  });

  final GoalsRecord? goal;
  final Future Function()? showFinishedSnackbarAction;
  final Future Function()? showCompletedSnackbarAction;

  @override
  State<GoalHabitListItemWidget> createState() =>
      _GoalHabitListItemWidgetState();
}

class _GoalHabitListItemWidgetState extends State<GoalHabitListItemWidget> {
  late GoalHabitListItemModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => GoalHabitListItemModel());

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
        queryBuilder: (habitsRecord) => habitsRecord
            .where(
              'goal',
              isEqualTo: widget!.goal?.reference,
            )
            .where(
              'user',
              isEqualTo: currentUserReference,
            )
            .where(
              'is_finished',
              isEqualTo: false,
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
        List<HabitsRecord> containerHabitsRecordList = snapshot.data!;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.transparent,
          ),
          child: Builder(
            builder: (context) {
              if ((containerHabitsRecordList.length > 1) &&
                  (widget!.goal?.name != null && widget!.goal?.name != '')) {
                return Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 5.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).secondary,
                      borderRadius:
                          BorderRadius.circular(valueOrDefault<double>(
                        FFAppConstants.borderRadius,
                        0.0,
                      )),
                    ),
                    child: Container(
                      width: double.infinity,
                      color: Color(0x00000000),
                      child: ExpandableNotifier(
                        controller: _model.expandableExpandableController,
                        child: ExpandablePanel(
                          header: Container(
                            width: double.infinity,
                            height: 40.0,
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(valueOrDefault<double>(
                                FFAppConstants.borderRadius,
                                0.0,
                              )),
                            ),
                            child: Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  10.0, 0.0, 10.0, 0.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8.0),
                                    child: Image.network(
                                      'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/tiny-habits-jf61nl/assets/blsw8q14iles/goal_icon.png',
                                      width: 20.0,
                                      height: 20.0,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Expanded(
                                    child: Align(
                                      alignment:
                                          AlignmentDirectional(-1.0, 0.0),
                                      child: Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            8.0, 0.0, 0.0, 0.0),
                                        child: Text(
                                          valueOrDefault<String>(
                                            widget!.goal?.name,
                                            'name',
                                          ),
                                          style: FlutterFlowTheme.of(context)
                                              .bodySmall
                                              .override(
                                                font: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.bold,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodySmall
                                                          .fontStyle,
                                                ),
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .alternate,
                                                letterSpacing: 0.0,
                                                fontWeight: FontWeight.bold,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodySmall
                                                        .fontStyle,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          collapsed: Container(
                            width: MediaQuery.sizeOf(context).width * 0.0,
                            height: 0.0,
                            decoration: BoxDecoration(
                              color: FlutterFlowTheme.of(context)
                                  .secondaryBackground,
                            ),
                          ),
                          expanded: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: FlutterFlowTheme.of(context).secondary,
                              borderRadius: BorderRadius.only(
                                bottomLeft:
                                    Radius.circular(valueOrDefault<double>(
                                  FFAppConstants.borderRadius,
                                  0.0,
                                )),
                                bottomRight:
                                    Radius.circular(valueOrDefault<double>(
                                  FFAppConstants.borderRadius,
                                  0.0,
                                )),
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  5.0, 0.0, 5.0, 5.0),
                              child: Builder(
                                builder: (context) {
                                  final habitsWithGoal =
                                      containerHabitsRecordList.toList();

                                  return Column(
                                    mainAxisSize: MainAxisSize.max,
                                    children:
                                        List.generate(habitsWithGoal.length,
                                            (habitsWithGoalIndex) {
                                      final habitsWithGoalItem =
                                          habitsWithGoal[habitsWithGoalIndex];
                                      return Container(
                                        width: double.infinity,
                                        height: 80.0,
                                        child: custom_widgets
                                            .SlidingListItemWidget(
                                          width: double.infinity,
                                          height: 80.0,
                                          title: habitsWithGoalItem.behavior,
                                          habit: habitsWithGoalItem,
                                          finishAction: () async {
                                            logFirebaseEvent(
                                                'GOAL_HABIT_LIST_ITEM_Container_za4jtb6b_');
                                            logFirebaseEvent(
                                                'SlidingListItemWidget_action_block');
                                            await _model.finishHabitActionBlock(
                                              context,
                                              habit: habitsWithGoalItem,
                                            );
                                            logFirebaseEvent(
                                                'SlidingListItemWidget_execute_callback');
                                            await widget
                                                .showFinishedSnackbarAction
                                                ?.call();
                                          },
                                          editAction: () async {
                                            logFirebaseEvent(
                                                'GOAL_HABIT_LIST_ITEM_Container_za4jtb6b_');
                                            logFirebaseEvent(
                                                'SlidingListItemWidget_action_block');
                                            await _model.editHabitActionBlock(
                                              context,
                                              habit: habitsWithGoalItem,
                                            );
                                          },
                                          completeAction: () async {
                                            logFirebaseEvent(
                                                'GOAL_HABIT_LIST_ITEM_Container_za4jtb6b_');
                                            logFirebaseEvent(
                                                'SlidingListItemWidget_action_block');
                                            await _model
                                                .completeHabitActionBlock(
                                              context,
                                              habit: habitsWithGoalItem,
                                            );
                                            logFirebaseEvent(
                                                'SlidingListItemWidget_execute_callback');
                                            await widget
                                                .showCompletedSnackbarAction
                                                ?.call();
                                          },
                                        ),
                                      );
                                    }).divide(SizedBox(height: 5.0)),
                                  );
                                },
                              ),
                            ),
                          ),
                          theme: ExpandableThemeData(
                            tapHeaderToExpand: true,
                            tapBodyToExpand: false,
                            tapBodyToCollapse: false,
                            headerAlignment:
                                ExpandablePanelHeaderAlignment.center,
                            hasIcon: true,
                            iconColor: FlutterFlowTheme.of(context).alternate,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              } else if (containerHabitsRecordList.length > 1) {
                return Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 5.0),
                  child: Builder(
                    builder: (context) {
                      final habitsNoGoal = containerHabitsRecordList.toList();

                      return Column(
                        mainAxisSize: MainAxisSize.max,
                        children: List.generate(habitsNoGoal.length,
                            (habitsNoGoalIndex) {
                          final habitsNoGoalItem =
                              habitsNoGoal[habitsNoGoalIndex];
                          return Container(
                            width: double.infinity,
                            height: 80.0,
                            child: custom_widgets.SlidingListItemWidget(
                              width: double.infinity,
                              height: 80.0,
                              title: habitsNoGoalItem.behavior,
                              habit: habitsNoGoalItem,
                              finishAction: () async {
                                logFirebaseEvent(
                                    'GOAL_HABIT_LIST_ITEM_Container_nlja7ken_');
                                logFirebaseEvent(
                                    'SlidingListItemWidget_action_block');
                                await _model.finishHabitActionBlock(
                                  context,
                                  habit: habitsNoGoalItem,
                                );
                                logFirebaseEvent(
                                    'SlidingListItemWidget_execute_callback');
                                await widget.showFinishedSnackbarAction?.call();
                              },
                              editAction: () async {
                                logFirebaseEvent(
                                    'GOAL_HABIT_LIST_ITEM_Container_nlja7ken_');
                                logFirebaseEvent(
                                    'SlidingListItemWidget_action_block');
                                await _model.editHabitActionBlock(
                                  context,
                                  habit: habitsNoGoalItem,
                                );
                              },
                              completeAction: () async {
                                logFirebaseEvent(
                                    'GOAL_HABIT_LIST_ITEM_Container_nlja7ken_');
                                logFirebaseEvent(
                                    'SlidingListItemWidget_action_block');
                                await _model.completeHabitActionBlock(
                                  context,
                                  habit: habitsNoGoalItem,
                                );
                                logFirebaseEvent(
                                    'SlidingListItemWidget_execute_callback');
                                await widget.showCompletedSnackbarAction
                                    ?.call();
                              },
                            ),
                          );
                        }).divide(SizedBox(height: 5.0)),
                      );
                    },
                  ),
                );
              } else if (containerHabitsRecordList.length == 1) {
                return Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 5.0),
                  child: Container(
                    width: double.infinity,
                    height: 80.0,
                    child: custom_widgets.SlidingListItemWidget(
                      width: double.infinity,
                      height: 80.0,
                      title: valueOrDefault<String>(
                        containerHabitsRecordList.firstOrNull?.behavior,
                        'behavior',
                      ),
                      habit: containerHabitsRecordList.firstOrNull,
                      finishAction: () async {
                        logFirebaseEvent(
                            'GOAL_HABIT_LIST_ITEM_Container_ed8kdl1g_');
                        logFirebaseEvent('SlidingListItemWidget_action_block');
                        await _model.finishHabitActionBlock(
                          context,
                          habit: containerHabitsRecordList.firstOrNull,
                        );
                        logFirebaseEvent(
                            'SlidingListItemWidget_execute_callback');
                        await widget.showFinishedSnackbarAction?.call();
                      },
                      editAction: () async {
                        logFirebaseEvent(
                            'GOAL_HABIT_LIST_ITEM_Container_ed8kdl1g_');
                        logFirebaseEvent('SlidingListItemWidget_action_block');
                        await _model.editHabitActionBlock(
                          context,
                          habit: containerHabitsRecordList.firstOrNull,
                        );
                      },
                      completeAction: () async {
                        logFirebaseEvent(
                            'GOAL_HABIT_LIST_ITEM_Container_ed8kdl1g_');
                        logFirebaseEvent('SlidingListItemWidget_action_block');
                        await _model.completeHabitActionBlock(
                          context,
                          habit: containerHabitsRecordList.firstOrNull,
                        );
                        logFirebaseEvent(
                            'SlidingListItemWidget_execute_callback');
                        await widget.showCompletedSnackbarAction?.call();
                      },
                    ),
                  ),
                );
              } else {
                return Container(
                  width: 100.0,
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).secondaryBackground,
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }
}
