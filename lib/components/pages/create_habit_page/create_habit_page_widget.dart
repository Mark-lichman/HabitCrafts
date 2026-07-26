import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/components/habit_components/new_habit_component/new_habit_component_widget.dart';
import '/components/toolip_component_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/actions/actions.dart' as action_blocks;
import '/index.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'create_habit_page_model.dart';
export 'create_habit_page_model.dart';

class CreateHabitPageWidget extends StatefulWidget {
  const CreateHabitPageWidget({
    super.key,
    this.existingHabit,
    this.prefillGoal,
    this.prefillWhy,
    this.prefillPrompt,
    String? prefillBehavior,
    this.prefillCelebration,
    this.prefillGoalIcon,
  }) : this.prefillBehavior = prefillBehavior ?? '';

  final HabitsRecord? existingHabit;
  final String? prefillGoal;
  final String? prefillWhy;
  final String? prefillPrompt;
  final String prefillBehavior;
  final String? prefillCelebration;
  final DocumentReference? prefillGoalIcon;

  static String routeName = 'createHabitPage';
  static String routePath = '/createHabitPage';

  @override
  State<CreateHabitPageWidget> createState() => _CreateHabitPageWidgetState();
}

class _CreateHabitPageWidgetState extends State<CreateHabitPageWidget> {
  late CreateHabitPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CreateHabitPageModel());

    logFirebaseEvent('screen_view',
        parameters: {'screen_name': 'createHabitPage'});
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: SafeArea(
          top: true,
          child: Align(
            alignment: AlignmentDirectional(0.0, -1.0),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: FFAppConstants.maxWidthForWeb.toDouble(),
              ),
              decoration: BoxDecoration(),
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(0.0, 20.0, 0.0, 0.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Align(
                        alignment: AlignmentDirectional(-1.0, -1.0),
                        child: Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              20.0, 0.0, 0.0, 0.0),
                          child: FlutterFlowIconButton(
                            borderColor: FlutterFlowTheme.of(context).primary,
                            borderRadius: 20.0,
                            borderWidth: 1.0,
                            buttonSize: 40.0,
                            icon: Icon(
                              Icons.arrow_back_ios,
                              color: FlutterFlowTheme.of(context).alternate,
                              size: 24.0,
                            ),
                            onPressed: () async {
                              logFirebaseEvent(
                                  'CREATE_HABIT_arrow_back_ios_ICN_ON_TAP');
                              logFirebaseEvent('IconButton_navigate_back');
                              context.safePop();
                            },
                          ),
                        ),
                      ),
                      Align(
                        alignment: AlignmentDirectional(0.0, -1.0),
                        child: Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              20.0, 0.0, 20.0, 0.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Text(
                                () {
                                  if (widget!.existingHabit != null) {
                                    return 'Edit a habit';
                                  } else if ((widget!.prefillGoal != null &&
                                          widget!.prefillGoal != '') ||
                                      (widget!.prefillWhy != null &&
                                          widget!.prefillWhy != '') ||
                                      (widget!.prefillPrompt != null &&
                                          widget!.prefillPrompt != '') ||
                                      (widget!.prefillBehavior != null &&
                                          widget!.prefillBehavior != '') ||
                                      (widget!.prefillCelebration != null &&
                                          widget!.prefillCelebration != '')) {
                                    return 'Edit a habit';
                                  } else {
                                    return 'Create a habit';
                                  }
                                }(),
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      font: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                      color: FlutterFlowTheme.of(context)
                                          .alternate,
                                      fontSize: 16.0,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                              ),
                              Text(
                                'Keep it small, you can always do more.',
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
                                      color: FlutterFlowTheme.of(context)
                                          .alternate,
                                      fontSize: 13.0,
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                              ),
                              if (() {
                                if (widget!.existingHabit != null) {
                                  return false;
                                } else if ((widget!.prefillGoal != null &&
                                        widget!.prefillGoal != '') ||
                                    (widget!.prefillWhy != null &&
                                        widget!.prefillWhy != '') ||
                                    (widget!.prefillPrompt != null &&
                                        widget!.prefillPrompt != '') ||
                                    (widget!.prefillBehavior != null &&
                                        widget!.prefillBehavior != '')) {
                                  return false;
                                } else {
                                  return true;
                                }
                              }())
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 20.0, 0.0, 0.0),
                                  child: InkWell(
                                    splashColor: Colors.transparent,
                                    focusColor: Colors.transparent,
                                    hoverColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    onTap: () async {
                                      logFirebaseEvent(
                                          'CREATE_HABIT_Container_dy8q0jg7_ON_TAP');
                                      logFirebaseEvent(
                                          'toolipComponent_navigate_to');

                                      context.pushNamed(
                                          ExploreHabitsPageWidget.routeName);
                                    },
                                    child: wrapWithModel(
                                      model: _model.toolipComponentModel,
                                      updateCallback: () => safeSetState(() {}),
                                      child: ToolipComponentWidget(
                                        imagePath:
                                            'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/tiny-habits-jf61nl/assets/z1i7ccf2w5l7/inspiration_icon.png',
                                        text:
                                            'Need inspiration? Click here for ideas.',
                                      ),
                                    ),
                                  ),
                                ),
                              Builder(
                                builder: (context) {
                                  if (widget!.existingHabit != null) {
                                    return Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          0.0, 20.0, 0.0, 0.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.max,
                                        children: [
                                          wrapWithModel(
                                            model: _model
                                                .exisitingBehaviorComponentModel,
                                            updateCallback: () =>
                                                safeSetState(() {}),
                                            child: NewHabitComponentWidget(
                                              type: 'Behavior',
                                              title: 'What will you do?',
                                              isPrompt: false,
                                              isCelebration: false,
                                              initialText: widget!
                                                  .existingHabit?.behavior,
                                              autoCompleteOptions:
                                                  FFAppConstants
                                                      .emptyStringList,
                                              promptRemind: false,
                                              saveCallback: () async {
                                                logFirebaseEvent(
                                                    'CREATE_HABIT_exisitingBehaviorComponent_');
                                                logFirebaseEvent(
                                                    'exisitingBehaviorComponent_action_block');
                                                await _model
                                                    .updateHabit(context);
                                              },
                                            ),
                                          ),
                                          wrapWithModel(
                                            model: _model
                                                .exisitingPromptComponentModel,
                                            updateCallback: () =>
                                                safeSetState(() {}),
                                            child: NewHabitComponentWidget(
                                              type: 'Prompt',
                                              title:
                                                  'When will you do the behavior?',
                                              isPrompt: true,
                                              isCelebration: false,
                                              initialText:
                                                  widget!.existingHabit?.prompt,
                                              autoCompleteOptions:
                                                  FFAppConstants
                                                      .emptyStringList,
                                              promptRemind: widget!
                                                  .existingHabit?.promptRemind,
                                              saveCallback: () async {
                                                logFirebaseEvent(
                                                    'CREATE_HABIT_exisitingPromptComponent_CA');
                                                logFirebaseEvent(
                                                    'exisitingPromptComponent_action_block');
                                                await _model
                                                    .updateHabit(context);
                                              },
                                            ),
                                          ),
                                          wrapWithModel(
                                            model: _model
                                                .exisitingCelebrationComponentModel,
                                            updateCallback: () =>
                                                safeSetState(() {}),
                                            child: NewHabitComponentWidget(
                                              type: 'Celebration',
                                              title: 'How will you celebrate?',
                                              isPrompt: false,
                                              isCelebration: true,
                                              initialText: widget!
                                                  .existingHabit?.celebration,
                                              autoCompleteOptions:
                                                  FFAppConstants
                                                      .emptyStringList,
                                              promptRemind: false,
                                              saveCallback: () async {
                                                logFirebaseEvent(
                                                    'CREATE_HABIT_exisitingCelebrationCompone');
                                                logFirebaseEvent(
                                                    'exisitingCelebrationComponent_action_blo');
                                                await _model
                                                    .updateHabit(context);
                                              },
                                            ),
                                          ),
                                          StreamBuilder<GoalsRecord>(
                                            stream: GoalsRecord.getDocument(
                                                widget!.existingHabit!.goal!),
                                            builder: (context, snapshot) {
                                              // Customize what your widget looks like when it's loading.
                                              if (!snapshot.hasData) {
                                                return Center(
                                                  child: SizedBox(
                                                    width: 40.0,
                                                    height: 40.0,
                                                    child:
                                                        CircularProgressIndicator(
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                              Color>(
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .primary,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }

                                              final existingGoalComponentGoalsRecord =
                                                  snapshot.data!;

                                              return wrapWithModel(
                                                model: _model
                                                    .existingGoalComponentModel,
                                                updateCallback: () =>
                                                    safeSetState(() {}),
                                                child: NewHabitComponentWidget(
                                                  type: 'Goal',
                                                  title:
                                                      'What will success look like?',
                                                  isPrompt: false,
                                                  isCelebration: false,
                                                  initialText:
                                                      existingGoalComponentGoalsRecord
                                                          .name,
                                                  autoCompleteOptions:
                                                      FFAppConstants
                                                          .emptyStringList,
                                                  promptRemind: false,
                                                  isGoal: true,
                                                  saveCallback: () async {},
                                                ),
                                              );
                                            },
                                          ),
                                          wrapWithModel(
                                            model: _model
                                                .existingWhyComponentModel,
                                            updateCallback: () =>
                                                safeSetState(() {}),
                                            child: NewHabitComponentWidget(
                                              type: 'Why',
                                              title:
                                                  'Why is this goal important?',
                                              isPrompt: false,
                                              isCelebration: false,
                                              initialText:
                                                  widget!.existingHabit?.why,
                                              autoCompleteOptions:
                                                  FFAppConstants
                                                      .emptyStringList,
                                              promptRemind: false,
                                              saveCallback: () async {
                                                logFirebaseEvent(
                                                    'CREATE_HABIT_existingWhyComponent_CALLBA');
                                                logFirebaseEvent(
                                                    'existingWhyComponent_action_block');
                                                await _model
                                                    .updateHabit(context);
                                              },
                                            ),
                                          ),
                                          Padding(
                                            padding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    0.0, 20.0, 0.0, 0.0),
                                            child: FFButtonWidget(
                                              onPressed: () async {
                                                logFirebaseEvent(
                                                    'CREATE_HABIT_SAVE_HABIT_BTN_ON_TAP');
                                                logFirebaseEvent(
                                                    'Button_action_block');
                                                await _model
                                                    .updateHabit(context);
                                                logFirebaseEvent(
                                                    'Button_navigate_back');
                                                context.safePop();
                                              },
                                              text: 'Save Habit',
                                              options: FFButtonOptions(
                                                width: 250.0,
                                                height: 40.0,
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        24.0, 0.0, 24.0, 0.0),
                                                iconPadding:
                                                    EdgeInsetsDirectional
                                                        .fromSTEB(
                                                            0.0, 0.0, 0.0, 0.0),
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .tertiary,
                                                textStyle: FlutterFlowTheme.of(
                                                        context)
                                                    .labelLarge
                                                    .override(
                                                      font: GoogleFonts.poppins(
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelLarge
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelLarge
                                                                .fontStyle,
                                                      ),
                                                      letterSpacing: 0.0,
                                                      fontWeight:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .labelLarge
                                                              .fontWeight,
                                                      fontStyle:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .labelLarge
                                                              .fontStyle,
                                                    ),
                                                elevation: 3.0,
                                                borderSide: BorderSide(
                                                  color: Colors.transparent,
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(20.0),
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    0.0, 5.0, 0.0, 0.0),
                                            child: FFButtonWidget(
                                              onPressed: () async {
                                                logFirebaseEvent(
                                                    'CREATE_HABIT_PAGE_PAGE_DELETE_BTN_ON_TAP');
                                                logFirebaseEvent(
                                                    'Button_alert_dialog');
                                                var confirmDialogResponse =
                                                    await showDialog<bool>(
                                                          context: context,
                                                          builder:
                                                              (alertDialogContext) {
                                                            return AlertDialog(
                                                              title: Text(
                                                                  'Delete Habit?'),
                                                              content: Text(
                                                                  'Are you sure you would like to delete this habit?'),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed: () =>
                                                                      Navigator.pop(
                                                                          alertDialogContext,
                                                                          false),
                                                                  child: Text(
                                                                      'Cancel'),
                                                                ),
                                                                TextButton(
                                                                  onPressed: () =>
                                                                      Navigator.pop(
                                                                          alertDialogContext,
                                                                          true),
                                                                  child: Text(
                                                                      'Yes'),
                                                                ),
                                                              ],
                                                            );
                                                          },
                                                        ) ??
                                                        false;
                                                if (confirmDialogResponse) {
                                                  logFirebaseEvent(
                                                      'Button_backend_call');
                                                  await widget!
                                                      .existingHabit!.reference
                                                      .delete();
                                                  logFirebaseEvent(
                                                      'Button_navigate_back');
                                                  context.safePop();
                                                }
                                                logFirebaseEvent(
                                                    'Button_action_block');
                                                await action_blocks
                                                    .clearTempValues(context);
                                              },
                                              text: 'Delete',
                                              options: FFButtonOptions(
                                                height: 40.0,
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        24.0, 0.0, 24.0, 0.0),
                                                iconPadding:
                                                    EdgeInsetsDirectional
                                                        .fromSTEB(
                                                            0.0, 0.0, 0.0, 0.0),
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .error,
                                                textStyle: FlutterFlowTheme.of(
                                                        context)
                                                    .labelLarge
                                                    .override(
                                                      font: GoogleFonts.poppins(
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelLarge
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelLarge
                                                                .fontStyle,
                                                      ),
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .alternate,
                                                      letterSpacing: 0.0,
                                                      fontWeight:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .labelLarge
                                                              .fontWeight,
                                                      fontStyle:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .labelLarge
                                                              .fontStyle,
                                                    ),
                                                elevation: 3.0,
                                                borderSide: BorderSide(
                                                  color: Colors.transparent,
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(20.0),
                                              ),
                                            ),
                                          ),
                                        ]
                                            .divide(SizedBox(height: 5.0))
                                            .addToEnd(SizedBox(height: 80.0)),
                                      ),
                                    );
                                  } else {
                                    return Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          0.0, 20.0, 0.0, 0.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.max,
                                        children: [
                                          wrapWithModel(
                                            model: _model
                                                .newBehaviorComponentModel,
                                            updateCallback: () =>
                                                safeSetState(() {}),
                                            child: NewHabitComponentWidget(
                                              type: 'Behavior',
                                              title: 'What will you do?',
                                              isPrompt: false,
                                              isCelebration: false,
                                              initialText:
                                                  widget!.prefillBehavior,
                                              autoCompleteOptions:
                                                  FFAppConstants
                                                      .emptyStringList,
                                              promptRemind: false,
                                              saveCallback: () async {},
                                            ),
                                          ),
                                          wrapWithModel(
                                            model:
                                                _model.newPromptComponentModel,
                                            updateCallback: () =>
                                                safeSetState(() {}),
                                            child: NewHabitComponentWidget(
                                              type: 'Prompt',
                                              title:
                                                  'When will you do the behavior?',
                                              isPrompt: true,
                                              isCelebration: false,
                                              initialText:
                                                  widget!.prefillPrompt,
                                              autoCompleteOptions:
                                                  FFAppConstants
                                                      .emptyStringList,
                                              promptRemind: false,
                                              saveCallback: () async {},
                                            ),
                                          ),
                                          wrapWithModel(
                                            model: _model
                                                .newCelebrationComponentModel,
                                            updateCallback: () =>
                                                safeSetState(() {}),
                                            child: NewHabitComponentWidget(
                                              type: 'Celebration',
                                              title: 'How will you celebrate?',
                                              isPrompt: false,
                                              isCelebration: true,
                                              initialText:
                                                  widget!.prefillCelebration,
                                              autoCompleteOptions:
                                                  FFAppConstants
                                                      .emptyStringList,
                                              promptRemind: false,
                                              saveCallback: () async {},
                                            ),
                                          ),
                                          StreamBuilder<List<GoalsRecord>>(
                                            stream: queryGoalsRecord(
                                              queryBuilder: (goalsRecord) =>
                                                  goalsRecord
                                                      .where(
                                                        'user',
                                                        isEqualTo:
                                                            currentUserReference,
                                                      )
                                                      .where(
                                                        'name',
                                                        isNotEqualTo: '',
                                                      ),
                                            ),
                                            builder: (context, snapshot) {
                                              // Customize what your widget looks like when it's loading.
                                              if (!snapshot.hasData) {
                                                return Center(
                                                  child: SizedBox(
                                                    width: 40.0,
                                                    height: 40.0,
                                                    child:
                                                        CircularProgressIndicator(
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                              Color>(
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .primary,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }
                                              List<GoalsRecord>
                                                  newGoalComponentGoalsRecordList =
                                                  snapshot.data!;

                                              return wrapWithModel(
                                                model: _model
                                                    .newGoalComponentModel,
                                                updateCallback: () =>
                                                    safeSetState(() {}),
                                                child: NewHabitComponentWidget(
                                                  type: 'Goal',
                                                  title:
                                                      'What will success look like?',
                                                  isPrompt: false,
                                                  isCelebration: false,
                                                  initialText:
                                                      widget!.prefillGoal,
                                                  autoCompleteOptions:
                                                      newGoalComponentGoalsRecordList
                                                          .map((e) => e.name)
                                                          .toList()
                                                          .where((e) =>
                                                              e != null &&
                                                              e != '')
                                                          .toList(),
                                                  promptRemind: false,
                                                  isGoal: true,
                                                  saveCallback: () async {},
                                                ),
                                              );
                                            },
                                          ),
                                          wrapWithModel(
                                            model: _model.newWhyComponentModel,
                                            updateCallback: () =>
                                                safeSetState(() {}),
                                            child: NewHabitComponentWidget(
                                              type: 'Why',
                                              title:
                                                  'Why is this goal important?',
                                              isPrompt: false,
                                              isCelebration: false,
                                              initialText: widget!.prefillWhy,
                                              autoCompleteOptions:
                                                  FFAppConstants
                                                      .emptyStringList,
                                              promptRemind: false,
                                              saveCallback: () async {},
                                            ),
                                          ),
                                          Padding(
                                            padding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    0.0, 20.0, 0.0, 0.0),
                                            child: FFButtonWidget(
                                              onPressed: ((_model
                                                                  .newBehaviorComponentModel
                                                                  .inputFieldTextController
                                                                  .text ==
                                                              null ||
                                                          _model
                                                                  .newBehaviorComponentModel
                                                                  .inputFieldTextController
                                                                  .text ==
                                                              '') &&
                                                      (_model
                                                                  .newPromptComponentModel
                                                                  .inputFieldTextController
                                                                  .text ==
                                                              null ||
                                                          _model
                                                                  .newPromptComponentModel
                                                                  .inputFieldTextController
                                                                  .text ==
                                                              '') &&
                                                      (_model.newGoalComponentModel
                                                                  .inputFieldSelectedOption ==
                                                              null ||
                                                          _model.newGoalComponentModel
                                                                  .inputFieldSelectedOption ==
                                                              ''))
                                                  ? null
                                                  : () async {
                                                      logFirebaseEvent(
                                                          'CREATE_HABIT_CREATE_HABIT_BTN_ON_TAP');
                                                      var _shouldSetState =
                                                          false;
                                                      logFirebaseEvent(
                                                          'Button_firestore_query');
                                                      _model.existinghabits =
                                                          await queryHabitsRecordOnce(
                                                        queryBuilder:
                                                            (habitsRecord) =>
                                                                habitsRecord
                                                                    .where(
                                                                      'user',
                                                                      isEqualTo:
                                                                          currentUserReference,
                                                                    )
                                                                    .where(
                                                                      'is_finished',
                                                                      isEqualTo:
                                                                          false,
                                                                    ),
                                                      );
                                                      _shouldSetState = true;
                                                      if (_model.existinghabits!
                                                              .length >=
                                                          7) {
                                                        logFirebaseEvent(
                                                            'Button_alert_dialog');
                                                        var confirmDialogResponse =
                                                            await showDialog<
                                                                    bool>(
                                                                  context:
                                                                      context,
                                                                  builder:
                                                                      (alertDialogContext) {
                                                                    return AlertDialog(
                                                                      title: Text(
                                                                          'More than 7 habits?'),
                                                                      content: Text(
                                                                          'You have 7 or more active habits. Are you sure you\'d like to add another?'),
                                                                      actions: [
                                                                        TextButton(
                                                                          onPressed: () => Navigator.pop(
                                                                              alertDialogContext,
                                                                              false),
                                                                          child:
                                                                              Text('Cancel'),
                                                                        ),
                                                                        TextButton(
                                                                          onPressed: () => Navigator.pop(
                                                                              alertDialogContext,
                                                                              true),
                                                                          child:
                                                                              Text('Yes'),
                                                                        ),
                                                                      ],
                                                                    );
                                                                  },
                                                                ) ??
                                                                false;
                                                        if (!confirmDialogResponse) {
                                                          if (_shouldSetState)
                                                            safeSetState(() {});
                                                          return;
                                                        }
                                                      }
                                                      logFirebaseEvent(
                                                          'Button_firestore_query');
                                                      _model.newGoal =
                                                          await queryGoalsRecordOnce(
                                                        queryBuilder:
                                                            (goalsRecord) =>
                                                                goalsRecord
                                                                    .where(
                                                                      'user',
                                                                      isEqualTo:
                                                                          currentUserReference,
                                                                    )
                                                                    .where(
                                                                      'name',
                                                                      isEqualTo: _model
                                                                          .newGoalComponentModel
                                                                          .inputFieldTextController
                                                                          .text,
                                                                    ),
                                                        singleRecord: true,
                                                      ).then((s) =>
                                                              s.firstOrNull);
                                                      _shouldSetState = true;
                                                      if (!(_model.newGoal !=
                                                          null)) {
                                                        logFirebaseEvent(
                                                            'Button_backend_call');

                                                        var goalsRecordReference =
                                                            GoalsRecord
                                                                .collection
                                                                .doc();
                                                        await goalsRecordReference
                                                            .set(
                                                                createGoalsRecordData(
                                                          isPublic: false,
                                                          name: _model
                                                              .newGoalComponentModel
                                                              .inputFieldTextController
                                                              .text,
                                                          user:
                                                              currentUserReference,
                                                          icon: widget!
                                                              .prefillGoalIcon,
                                                        ));
                                                        _model.createdGoal = GoalsRecord
                                                            .getDocumentFromData(
                                                                createGoalsRecordData(
                                                                  isPublic:
                                                                      false,
                                                                  name: _model
                                                                      .newGoalComponentModel
                                                                      .inputFieldTextController
                                                                      .text,
                                                                  user:
                                                                      currentUserReference,
                                                                  icon: widget!
                                                                      .prefillGoalIcon,
                                                                ),
                                                                goalsRecordReference);
                                                        _shouldSetState = true;
                                                      }
                                                      logFirebaseEvent(
                                                          'Button_firestore_query');
                                                      _model.goalCopy =
                                                          await queryGoalsRecordOnce(
                                                        queryBuilder:
                                                            (goalsRecord) =>
                                                                goalsRecord
                                                                    .where(
                                                                      'name',
                                                                      isEqualTo: _model
                                                                          .newGoalComponentModel
                                                                          .inputFieldTextController
                                                                          .text,
                                                                    )
                                                                    .where(
                                                                      'user',
                                                                      isEqualTo:
                                                                          currentUserReference,
                                                                    ),
                                                        singleRecord: true,
                                                      ).then((s) =>
                                                              s.firstOrNull);
                                                      _shouldSetState = true;
                                                      // update the last used goal time. We're showing the three most recently used goal in the create habit screen
                                                      logFirebaseEvent(
                                                          'Button_backend_call');

                                                      await _model
                                                          .goalCopy!.reference
                                                          .update(
                                                              createGoalsRecordData(
                                                        lastUsed:
                                                            getCurrentTimestamp,
                                                      ));
                                                      if (_model.goalCopy !=
                                                          null) {
                                                        logFirebaseEvent(
                                                            'Button_backend_call');

                                                        var habitsRecordReference1 =
                                                            HabitsRecord
                                                                .collection
                                                                .doc();
                                                        await habitsRecordReference1
                                                            .set(
                                                                createHabitsRecordData(
                                                          behavior: _model
                                                              .newBehaviorComponentModel
                                                              .inputFieldTextController
                                                              .text,
                                                          celebration: _model
                                                              .newCelebrationComponentModel
                                                              .inputFieldTextController
                                                              .text,
                                                          goal: _model.goalCopy
                                                              ?.reference,
                                                          prompt: _model
                                                              .newPromptComponentModel
                                                              .inputFieldTextController
                                                              .text,
                                                          promptRemind: _model
                                                              .newPromptComponentModel
                                                              .switchValue,
                                                          user:
                                                              currentUserReference,
                                                          why: _model
                                                              .newWhyComponentModel
                                                              .inputFieldTextController
                                                              .text,
                                                          createdTime:
                                                              getCurrentTimestamp,
                                                          isFinished: false,
                                                          reminder: FFAppState()
                                                              .tempReminderRef,
                                                        ));
                                                        _model.newHabit = HabitsRecord
                                                            .getDocumentFromData(
                                                                createHabitsRecordData(
                                                                  behavior: _model
                                                                      .newBehaviorComponentModel
                                                                      .inputFieldTextController
                                                                      .text,
                                                                  celebration: _model
                                                                      .newCelebrationComponentModel
                                                                      .inputFieldTextController
                                                                      .text,
                                                                  goal: _model
                                                                      .goalCopy
                                                                      ?.reference,
                                                                  prompt: _model
                                                                      .newPromptComponentModel
                                                                      .inputFieldTextController
                                                                      .text,
                                                                  promptRemind: _model
                                                                      .newPromptComponentModel
                                                                      .switchValue,
                                                                  user:
                                                                      currentUserReference,
                                                                  why: _model
                                                                      .newWhyComponentModel
                                                                      .inputFieldTextController
                                                                      .text,
                                                                  createdTime:
                                                                      getCurrentTimestamp,
                                                                  isFinished:
                                                                      false,
                                                                  reminder:
                                                                      FFAppState()
                                                                          .tempReminderRef,
                                                                ),
                                                                habitsRecordReference1);
                                                        _shouldSetState = true;
                                                        logFirebaseEvent(
                                                            'Button_update_page_state');
                                                        _model.newHabitRef =
                                                            _model.newHabit
                                                                ?.reference;
                                                      } else {
                                                        logFirebaseEvent(
                                                            'Button_backend_call');

                                                        var habitsRecordReference2 =
                                                            HabitsRecord
                                                                .collection
                                                                .doc();
                                                        await habitsRecordReference2
                                                            .set(
                                                                createHabitsRecordData(
                                                          behavior: _model
                                                              .newBehaviorComponentModel
                                                              .inputFieldTextController
                                                              .text,
                                                          celebration: _model
                                                              .newCelebrationComponentModel
                                                              .inputFieldTextController
                                                              .text,
                                                          prompt: _model
                                                              .newPromptComponentModel
                                                              .inputFieldTextController
                                                              .text,
                                                          promptRemind: _model
                                                              .newPromptComponentModel
                                                              .switchValue,
                                                          user:
                                                              currentUserReference,
                                                          why: _model
                                                              .newWhyComponentModel
                                                              .inputFieldTextController
                                                              .text,
                                                          createdTime:
                                                              getCurrentTimestamp,
                                                          isFinished: false,
                                                          reminder: FFAppState()
                                                              .tempReminderRef,
                                                        ));
                                                        _model.newHabitNoGoal =
                                                            HabitsRecord.getDocumentFromData(
                                                                createHabitsRecordData(
                                                                  behavior: _model
                                                                      .newBehaviorComponentModel
                                                                      .inputFieldTextController
                                                                      .text,
                                                                  celebration: _model
                                                                      .newCelebrationComponentModel
                                                                      .inputFieldTextController
                                                                      .text,
                                                                  prompt: _model
                                                                      .newPromptComponentModel
                                                                      .inputFieldTextController
                                                                      .text,
                                                                  promptRemind: _model
                                                                      .newPromptComponentModel
                                                                      .switchValue,
                                                                  user:
                                                                      currentUserReference,
                                                                  why: _model
                                                                      .newWhyComponentModel
                                                                      .inputFieldTextController
                                                                      .text,
                                                                  createdTime:
                                                                      getCurrentTimestamp,
                                                                  isFinished:
                                                                      false,
                                                                  reminder:
                                                                      FFAppState()
                                                                          .tempReminderRef,
                                                                ),
                                                                habitsRecordReference2);
                                                        _shouldSetState = true;
                                                        logFirebaseEvent(
                                                            'Button_update_page_state');
                                                        _model.newHabitRef =
                                                            _model
                                                                .newHabitNoGoal
                                                                ?.reference;
                                                      }

                                                      logFirebaseEvent(
                                                          'Button_backend_call');

                                                      await UserActivityRecord
                                                              .createDoc(
                                                                  currentUserReference!)
                                                          .set({
                                                        ...createUserActivityRecordData(
                                                          action: ActivityTypes
                                                              .AddedNewHabit,
                                                          habit: _model
                                                              .newHabitRef,
                                                          actionText:
                                                              'Habit Created - ${_model.newBehaviorComponentModel.inputFieldTextController.text}',
                                                        ),
                                                        ...mapToFirestore(
                                                          {
                                                            'created': FieldValue
                                                                .serverTimestamp(),
                                                          },
                                                        ),
                                                      });
                                                      if (FFAppState()
                                                              .tempReminderRef !=
                                                          null) {
                                                        // update the reminder object with the habit ref so the push notification can be sent out
                                                        logFirebaseEvent(
                                                            'Button_backend_call');

                                                        await FFAppState()
                                                            .tempReminderRef!
                                                            .update(
                                                                createRemindersRecordData(
                                                              habit: _model
                                                                  .newHabitRef,
                                                            ));
                                                      }
                                                      logFirebaseEvent(
                                                          'Button_update_app_state');
                                                      FFAppState()
                                                              .shouldMoveToActiveHabits =
                                                          true;
                                                      FFAppState()
                                                              .showWelcomeTooltip =
                                                          false;
                                                      FFAppState()
                                                              .showFirstHabitTooltip =
                                                          FFAppState()
                                                                  .showFirstHabitTooltip +
                                                              1;
                                                      logFirebaseEvent(
                                                          'Button_action_block');
                                                      await action_blocks
                                                          .clearTempValues(
                                                              context);
                                                      logFirebaseEvent(
                                                          'Button_navigate_back');
                                                      context.safePop();
                                                      if (_shouldSetState)
                                                        safeSetState(() {});
                                                    },
                                              text: (widget!.prefillGoal !=
                                                              null &&
                                                          widget!
                                                                  .prefillGoal !=
                                                              '') ||
                                                      (widget!.prefillWhy != null &&
                                                          widget!.prefillWhy !=
                                                              '') ||
                                                      (widget!.prefillPrompt !=
                                                              null &&
                                                          widget!.prefillPrompt !=
                                                              '') ||
                                                      (widget!.prefillBehavior !=
                                                              null &&
                                                          widget!.prefillBehavior !=
                                                              '') ||
                                                      (widget!.prefillCelebration !=
                                                              null &&
                                                          widget!.prefillCelebration !=
                                                              '')
                                                  ? 'Edit Habit'
                                                  : 'Create Habit',
                                              options: FFButtonOptions(
                                                width: 250.0,
                                                height: 40.0,
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        24.0, 0.0, 24.0, 0.0),
                                                iconPadding:
                                                    EdgeInsetsDirectional
                                                        .fromSTEB(
                                                            0.0, 0.0, 0.0, 0.0),
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .tertiary,
                                                textStyle: FlutterFlowTheme.of(
                                                        context)
                                                    .labelLarge
                                                    .override(
                                                      font: GoogleFonts.poppins(
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelLarge
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelLarge
                                                                .fontStyle,
                                                      ),
                                                      letterSpacing: 0.0,
                                                      fontWeight:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .labelLarge
                                                              .fontWeight,
                                                      fontStyle:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .labelLarge
                                                              .fontStyle,
                                                    ),
                                                elevation: 3.0,
                                                borderSide: BorderSide(
                                                  color: Colors.transparent,
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(20.0),
                                                disabledColor:
                                                    Color(0x87E6EEF8),
                                              ),
                                            ),
                                          ),
                                        ]
                                            .divide(SizedBox(height: 5.0))
                                            .addToEnd(SizedBox(height: 180.0)),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
