import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/custom_cloud_functions/custom_cloud_function_response_manager.dart';
import '/backend/schema/structs/index.dart';
import '/components/bottom_nav_bar_component_widget.dart';
import '/components/eula_modal_widget.dart';
import '/components/group_components/in_app_notification_component/in_app_notification_component_widget.dart';
import '/components/habit_components/explore_habit_component/explore_habit_component_widget.dart';
import '/components/habit_components/goal_habit_list_item/goal_habit_list_item_widget.dart';
import '/components/habit_components/habit_completed_snack_bar/habit_completed_snack_bar_widget.dart';
import '/components/lesson_category_list_item_widget.dart';
import '/components/notes_modal_component/notes_modal_component_widget.dart';
import '/components/toolip_component_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:async';
import 'dart:ui';
import '/actions/actions.dart' as action_blocks;
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'home_page_model.dart';
export 'home_page_model.dart';

class HomePageWidget extends StatefulWidget {
  const HomePageWidget({super.key});

  static String routeName = 'homePage';
  static String routePath = '/homePage';

  @override
  State<HomePageWidget> createState() => _HomePageWidgetState();
}

class _HomePageWidgetState extends State<HomePageWidget>
    with TickerProviderStateMixin {
  late HomePageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  late StreamSubscription<bool> _keyboardVisibilitySubscription;
  bool _isKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HomePageModel());

    logFirebaseEvent('screen_view', parameters: {'screen_name': 'homePage'});
    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      logFirebaseEvent('HOME_PAGE_PAGE_homePage_ON_INIT_STATE');
      if (FFAppState().showOnboard) {
        logFirebaseEvent('homePage_update_app_state');
        FFAppState().showOnboard = false;
        logFirebaseEvent('homePage_navigate_to');

        context.pushNamed(OnboardingWidget.routeName);
      }
      logFirebaseEvent('homePage_custom_action');
      _model.buildNumberOutput = await actions.getBuildNumber();
      if (!FFAppState().eulaAccepted) {
        logFirebaseEvent('homePage_alert_dialog');
        await showDialog(
          barrierDismissible: false,
          context: context,
          builder: (dialogContext) {
            return Dialog(
              elevation: 0,
              insetPadding: EdgeInsets.zero,
              backgroundColor: Colors.transparent,
              alignment: AlignmentDirectional(0.0, 0.0)
                  .resolve(Directionality.of(context)),
              child: EulaModalWidget(),
            );
          },
        );
      }
      logFirebaseEvent('homePage_backend_call');

      await currentUserReference!.update(createUsersRecordData(
        localOffset: functions.localToUTCOffset(getCurrentTimestamp),
        lastActive: getCurrentTimestamp,
      ));
      logFirebaseEvent('homePage_custom_action');
      _model.calculatedWeekIndex = await actions.setWeekIndex(
        currentUserDocument!.createdTime!,
      );
      logFirebaseEvent('homePage_update_page_state');
      _model.buildNumber = _model.buildNumberOutput!;
      _model.weekIndex = _model.calculatedWeekIndex!;
      safeSetState(() {});
      logFirebaseEvent('homePage_action_block');
      await action_blocks.fetchContacts(context);
      // add the user search term
      logFirebaseEvent('homePage_firestore_query');
      _model.usersInSearch = await queryUserGroupSearchRecordCount(
        queryBuilder: (userGroupSearchRecord) => userGroupSearchRecord.where(
          'user',
          isEqualTo: currentUserReference,
        ),
      );
      if (_model.usersInSearch! <= 0) {
        logFirebaseEvent('homePage_backend_call');

        await UserGroupSearchRecord.collection
            .doc()
            .set(createUserGroupSearchRecordData(
              user: currentUserReference,
              searchTerm: currentUserDisplayName,
            ));
      }
    });

    if (!isWeb) {
      _keyboardVisibilitySubscription =
          KeyboardVisibilityController().onChange.listen((bool visible) {
        safeSetState(() {
          _isKeyboardVisible = visible;
        });
      });
    }

    _model.tabBarController = TabController(
      vsync: this,
      length: 2,
      initialIndex: 0,
    )..addListener(() => safeSetState(() {}));

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    if (!isWeb) {
      _keyboardVisibilitySubscription.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return Builder(
      builder: (context) => StreamBuilder<List<HabitsRecord>>(
        stream: queryHabitsRecord(
          queryBuilder: (habitsRecord) => habitsRecord
              .where(
                'user',
                isEqualTo: currentUserReference,
              )
              .where(
                'is_finished',
                isEqualTo: false,
              ),
        )..listen((snapshot) {
            List<HabitsRecord> homePageHabitsRecordList = snapshot;
            if (_model.homePagePreviousSnapshot != null &&
                !const ListEquality(HabitsRecordDocumentEquality()).equals(
                    homePageHabitsRecordList,
                    _model.homePagePreviousSnapshot)) {
              () async {
                logFirebaseEvent('HOME_PAGE_PAGE_homePage_ON_DATA_CHANGE');
                logFirebaseEvent('homePage_tab_bar');
                safeSetState(() {
                  _model.tabBarController!.animateTo(
                    0,
                    duration: Duration(milliseconds: 300),
                    curve: Curves.ease,
                  );
                });

                safeSetState(() {});
              }();
            }
            _model.homePagePreviousSnapshot = snapshot;
          }),
        builder: (context, snapshot) {
          // Customize what your widget looks like when it's loading.
          if (!snapshot.hasData) {
            return Scaffold(
              backgroundColor: FlutterFlowTheme.of(context).primary,
              body: Center(
                child: SizedBox(
                  width: 40.0,
                  height: 40.0,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      FlutterFlowTheme.of(context).primary,
                    ),
                  ),
                ),
              ),
            );
          }
          List<HabitsRecord> homePageHabitsRecordList = snapshot.data!;

          return Scaffold(
            key: scaffoldKey,
            backgroundColor: FlutterFlowTheme.of(context).primary,
            body: Align(
              alignment: AlignmentDirectional(0.0, -1.0),
              child: StreamBuilder<List<LessonsRecord>>(
                stream: queryLessonsRecord(
                  queryBuilder: (lessonsRecord) =>
                      lessonsRecord.orderBy('order'),
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
                  List<LessonsRecord> containerLessonsRecordList =
                      snapshot.data!;

                  return InkWell(
                    splashColor: Colors.transparent,
                    focusColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    onTap: () async {
                      logFirebaseEvent(
                          'HOME_PAGE_PAGE_Container_bilqe37u_ON_TAP');
                      logFirebaseEvent('Container_cloud_function');
                      try {
                        final result = await FirebaseFunctions.instanceFor(
                                region: 'us-central1')
                            .httpsCallable('cleanInvalidChatEntries')
                            .call({});
                        _model.cloudFunctionpas =
                            CleanInvalidChatEntriesCloudFunctionCallResponse(
                          succeeded: true,
                        );
                      } on FirebaseFunctionsException catch (error) {
                        _model.cloudFunctionpas =
                            CleanInvalidChatEntriesCloudFunctionCallResponse(
                          errorCode: error.code,
                          succeeded: false,
                        );
                      }

                      safeSetState(() {});
                    },
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: FFAppConstants.maxWidthForWeb.toDouble(),
                      ),
                      decoration: BoxDecoration(),
                      child: Stack(
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Align(
                                alignment: AlignmentDirectional(1.0, -1.0),
                                child: Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 40.0, 10.0, 0.0),
                                  child: FFButtonWidget(
                                    onPressed: () async {
                                      logFirebaseEvent(
                                          'HOME_PAGE_PAGE__BTN_ON_TAP');
                                      logFirebaseEvent('Button_navigate_to');

                                      context.pushNamed(
                                          ProfilePageWidget.routeName);
                                    },
                                    text: '',
                                    icon: Icon(
                                      Icons.person_2,
                                      size: 15.0,
                                    ),
                                    options: FFButtonOptions(
                                      width: 40.0,
                                      height: 40.0,
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          8.0, 0.0, 0.0, 0.0),
                                      iconPadding:
                                          EdgeInsetsDirectional.fromSTEB(
                                              0.0, 0.0, 0.0, 0.0),
                                      iconColor:
                                          FlutterFlowTheme.of(context).grayDark,
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryBackground,
                                      textStyle: FlutterFlowTheme.of(context)
                                          .titleSmall
                                          .override(
                                            font: GoogleFonts.poppins(
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .titleSmall
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .titleSmall
                                                      .fontStyle,
                                            ),
                                            color: Colors.white,
                                            letterSpacing: 0.0,
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .titleSmall
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .titleSmall
                                                    .fontStyle,
                                          ),
                                      elevation: 3.0,
                                      borderSide: BorderSide(
                                        color: Colors.transparent,
                                        width: 1.0,
                                      ),
                                      borderRadius: BorderRadius.circular(20.0),
                                    ),
                                  ),
                                ),
                              ),
                              Align(
                                alignment: AlignmentDirectional(0.0, 0.0),
                                child: Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 20.0, 0.0, 0.0),
                                  child: Text(
                                    'Habits',
                                    style: FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .override(
                                          font: GoogleFonts.poppins(
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .titleMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .titleMedium
                                                    .fontStyle,
                                          ),
                                          letterSpacing: 0.0,
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .titleMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .titleMedium
                                                  .fontStyle,
                                        ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(),
                                  child: Column(
                                    children: [
                                      Align(
                                        alignment: Alignment(0.0, 0),
                                        child: TabBar(
                                          labelColor:
                                              FlutterFlowTheme.of(context)
                                                  .alternate,
                                          unselectedLabelColor:
                                              FlutterFlowTheme.of(context)
                                                  .alternate,
                                          labelStyle: FlutterFlowTheme.of(
                                                  context)
                                              .titleMedium
                                              .override(
                                                font: GoogleFonts.poppins(
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .titleMedium
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .titleMedium
                                                          .fontStyle,
                                                ),
                                                letterSpacing: 0.0,
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .titleMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .titleMedium
                                                        .fontStyle,
                                              ),
                                          unselectedLabelStyle: TextStyle(),
                                          indicatorColor:
                                              FlutterFlowTheme.of(context)
                                                  .accent1,
                                          padding: EdgeInsets.all(4.0),
                                          tabs: [
                                            Tab(
                                              text: 'Active Habit',
                                            ),
                                            Tab(
                                              text: 'Explore',
                                            ),
                                          ],
                                          controller: _model.tabBarController,
                                          onTap: (i) async {
                                            [() async {}, () async {}][i]();
                                          },
                                        ),
                                      ),
                                      Expanded(
                                        child: TabBarView(
                                          controller: _model.tabBarController,
                                          children: [
                                            Padding(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(
                                                      20.0, 10.0, 20.0, 0.0),
                                              child: StreamBuilder<
                                                  List<GoalsRecord>>(
                                                stream: queryGoalsRecord(
                                                  queryBuilder: (goalsRecord) =>
                                                      goalsRecord.where(
                                                    'user',
                                                    isEqualTo:
                                                        currentUserReference,
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
                                                      containerGoalsRecordList =
                                                      snapshot.data!;

                                                  return Container(
                                                    decoration: BoxDecoration(),
                                                    child:
                                                        SingleChildScrollView(
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.max,
                                                        children: [
                                                          if (homePageHabitsRecordList
                                                                  .length ==
                                                              0)
                                                            InkWell(
                                                              splashColor: Colors
                                                                  .transparent,
                                                              focusColor: Colors
                                                                  .transparent,
                                                              hoverColor: Colors
                                                                  .transparent,
                                                              highlightColor:
                                                                  Colors
                                                                      .transparent,
                                                              onTap: () async {
                                                                logFirebaseEvent(
                                                                    'HOME_welcomeToolipComponent_ON_TAP');
                                                                logFirebaseEvent(
                                                                    'welcomeToolipComponent_navigate_to');

                                                                context.goNamed(
                                                                  LibraryPageWidget
                                                                      .routeName,
                                                                  extra: <String,
                                                                      dynamic>{
                                                                    '__transition_info__':
                                                                        TransitionInfo(
                                                                      hasTransition:
                                                                          true,
                                                                      transitionType:
                                                                          PageTransitionType
                                                                              .fade,
                                                                      duration: Duration(
                                                                          milliseconds:
                                                                              0),
                                                                    ),
                                                                  },
                                                                );
                                                              },
                                                              child:
                                                                  wrapWithModel(
                                                                model: _model
                                                                    .welcomeToolipComponentModel,
                                                                updateCallback: () =>
                                                                    safeSetState(
                                                                        () {}),
                                                                child:
                                                                    ToolipComponentWidget(
                                                                  imagePath:
                                                                      'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/tiny-habits-jf61nl/assets/z1i7ccf2w5l7/inspiration_icon.png',
                                                                  text:
                                                                      'Welcome! Click here to get started.',
                                                                ),
                                                              ),
                                                            ),
                                                          if (homePageHabitsRecordList
                                                                  .length ==
                                                              1)
                                                            wrapWithModel(
                                                              model: _model
                                                                  .firstHabitLeftToolipComponentModel,
                                                              updateCallback: () =>
                                                                  safeSetState(
                                                                      () {}),
                                                              child:
                                                                  ToolipComponentWidget(
                                                                imagePath:
                                                                    'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/tiny-habits-jf61nl/assets/8me8rb986pev/swipe_icon.png',
                                                                text:
                                                                    'This is your first habit. Swipe left to complete.',
                                                              ),
                                                            ),
                                                          Container(
                                                            decoration:
                                                                BoxDecoration(),
                                                          ),
                                                          if (homePageHabitsRecordList
                                                                  .length ==
                                                              0)
                                                            Container(
                                                              width: double
                                                                  .infinity,
                                                              height: 98.0,
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: Colors
                                                                    .transparent,
                                                              ),
                                                              child: Column(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .max,
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .end,
                                                                children: [
                                                                  Text(
                                                                    'No Active Habits',
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.poppins(
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              FlutterFlowTheme.of(context).alternate,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
                                                                  ),
                                                                  Text(
                                                                    'Create a new habit. Tap on \"+\"',
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.poppins(
                                                                            fontWeight:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              FlutterFlowTheme.of(context).alternate,
                                                                          letterSpacing:
                                                                              0.0,
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
                                                          Builder(
                                                            builder: (context) {
                                                              final containerVar =
                                                                  containerGoalsRecordList
                                                                      .toList();

                                                              return Column(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .max,
                                                                children: List.generate(
                                                                    containerVar
                                                                        .length,
                                                                    (containerVarIndex) {
                                                                  final containerVarItem =
                                                                      containerVar[
                                                                          containerVarIndex];
                                                                  return Builder(
                                                                    builder:
                                                                        (context) =>
                                                                            GoalHabitListItemWidget(
                                                                      key: Key(
                                                                          'Key310_${containerVarIndex}_of_${containerVar.length}'),
                                                                      goal:
                                                                          containerVarItem,
                                                                      showFinishedSnackbarAction:
                                                                          () async {
                                                                        logFirebaseEvent(
                                                                            'HOME_Container_310gtu9u_CALLBACK');
                                                                        logFirebaseEvent(
                                                                            'goalHabitListItem_bottom_sheet');
                                                                        await showModalBottomSheet(
                                                                          isScrollControlled:
                                                                              true,
                                                                          backgroundColor:
                                                                              Colors.transparent,
                                                                          enableDrag:
                                                                              false,
                                                                          context:
                                                                              context,
                                                                          builder:
                                                                              (context) {
                                                                            return Padding(
                                                                              padding: MediaQuery.viewInsetsOf(context),
                                                                              child: HabitCompletedSnackBarWidget(
                                                                                title: 'Habit Removed!',
                                                                                isCompletedType: false,
                                                                                addNotesCallback: () async {
                                                                                  logFirebaseEvent('_bottom_sheet');
                                                                                  Navigator.pop(context);
                                                                                  logFirebaseEvent('_alert_dialog');
                                                                                  await showDialog(
                                                                                    barrierDismissible: false,
                                                                                    context: context,
                                                                                    builder: (dialogContext) {
                                                                                      return Dialog(
                                                                                        elevation: 0,
                                                                                        insetPadding: EdgeInsets.zero,
                                                                                        backgroundColor: Colors.transparent,
                                                                                        alignment: AlignmentDirectional(0.0, 0.0).resolve(Directionality.of(context)),
                                                                                        child: NotesModalComponentWidget(
                                                                                          activityRef: FFAppState().tempActivityRef!,
                                                                                        ),
                                                                                      );
                                                                                    },
                                                                                  );
                                                                                },
                                                                              ),
                                                                            );
                                                                          },
                                                                        ).then((value) =>
                                                                            safeSetState(() {}));
                                                                      },
                                                                      showCompletedSnackbarAction:
                                                                          () async {
                                                                        logFirebaseEvent(
                                                                            'HOME_Container_310gtu9u_CALLBACK');
                                                                        logFirebaseEvent(
                                                                            'goalHabitListItem_bottom_sheet');
                                                                        await showModalBottomSheet(
                                                                          isScrollControlled:
                                                                              true,
                                                                          backgroundColor:
                                                                              Colors.transparent,
                                                                          enableDrag:
                                                                              false,
                                                                          context:
                                                                              context,
                                                                          builder:
                                                                              (context) {
                                                                            return Padding(
                                                                              padding: MediaQuery.viewInsetsOf(context),
                                                                              child: HabitCompletedSnackBarWidget(
                                                                                title: 'Habit Completed!',
                                                                                isCompletedType: true,
                                                                                addNotesCallback: () async {
                                                                                  logFirebaseEvent('_bottom_sheet');
                                                                                  Navigator.pop(context);
                                                                                  logFirebaseEvent('_alert_dialog');
                                                                                  await showDialog(
                                                                                    barrierDismissible: false,
                                                                                    context: context,
                                                                                    builder: (dialogContext) {
                                                                                      return Dialog(
                                                                                        elevation: 0,
                                                                                        insetPadding: EdgeInsets.zero,
                                                                                        backgroundColor: Colors.transparent,
                                                                                        alignment: AlignmentDirectional(0.0, 0.0).resolve(Directionality.of(context)),
                                                                                        child: NotesModalComponentWidget(
                                                                                          activityRef: FFAppState().tempActivityRef!,
                                                                                        ),
                                                                                      );
                                                                                    },
                                                                                  );
                                                                                },
                                                                              ),
                                                                            );
                                                                          },
                                                                        ).then((value) =>
                                                                            safeSetState(() {}));
                                                                      },
                                                                    ),
                                                                  );
                                                                }),
                                                              );
                                                            },
                                                          ),
                                                          Align(
                                                            alignment:
                                                                AlignmentDirectional(
                                                                    -1.0, 0.0),
                                                            child: Padding(
                                                              padding:
                                                                  EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          0.0,
                                                                          40.0,
                                                                          0.0,
                                                                          0.0),
                                                              child: Text(
                                                                'Daily Lesson',
                                                                style: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .override(
                                                                      font: GoogleFonts
                                                                          .poppins(
                                                                        fontWeight: FlutterFlowTheme.of(context)
                                                                            .bodyMedium
                                                                            .fontWeight,
                                                                        fontStyle: FlutterFlowTheme.of(context)
                                                                            .bodyMedium
                                                                            .fontStyle,
                                                                      ),
                                                                      color: FlutterFlowTheme.of(
                                                                              context)
                                                                          .alternate,
                                                                      fontSize:
                                                                          13.0,
                                                                      letterSpacing:
                                                                          0.0,
                                                                      fontWeight: FlutterFlowTheme.of(
                                                                              context)
                                                                          .bodyMedium
                                                                          .fontWeight,
                                                                      fontStyle: FlutterFlowTheme.of(
                                                                              context)
                                                                          .bodyMedium
                                                                          .fontStyle,
                                                                    ),
                                                              ),
                                                            ),
                                                          ),
                                                          Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .max,
                                                            children: [
                                                              Padding(
                                                                padding:
                                                                    EdgeInsetsDirectional
                                                                        .fromSTEB(
                                                                            0.0,
                                                                            0.0,
                                                                            0.0,
                                                                            10.0),
                                                                child: InkWell(
                                                                  splashColor:
                                                                      Colors
                                                                          .transparent,
                                                                  focusColor: Colors
                                                                      .transparent,
                                                                  hoverColor: Colors
                                                                      .transparent,
                                                                  highlightColor:
                                                                      Colors
                                                                          .transparent,
                                                                  onTap:
                                                                      () async {
                                                                    logFirebaseEvent(
                                                                        'HOME_PAGE_PAGE_Container_dg5kahah_ON_TAP');
                                                                  },
                                                                  child:
                                                                      Container(
                                                                    width: double
                                                                        .infinity,
                                                                    height:
                                                                        50.0,
                                                                    decoration:
                                                                        BoxDecoration(
                                                                      color: Color(
                                                                          0xFF69849F),
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              valueOrDefault<double>(
                                                                        FFAppConstants
                                                                            .borderRadius,
                                                                        0.0,
                                                                      )),
                                                                    ),
                                                                    alignment:
                                                                        AlignmentDirectional(
                                                                            -1.0,
                                                                            0.0),
                                                                    child: Row(
                                                                      mainAxisSize:
                                                                          MainAxisSize
                                                                              .max,
                                                                      mainAxisAlignment:
                                                                          MainAxisAlignment
                                                                              .center,
                                                                      children: [
                                                                        if (false)
                                                                          FFButtonWidget(
                                                                            onPressed: (_model.weekIndex == 0)
                                                                                ? null
                                                                                : () async {
                                                                                    logFirebaseEvent('HOME_PAGE_PAGE__BTN_ON_TAP');
                                                                                  },
                                                                            text:
                                                                                '',
                                                                            icon:
                                                                                Icon(
                                                                              Icons.arrow_circle_left_outlined,
                                                                              size: 30.0,
                                                                            ),
                                                                            options:
                                                                                FFButtonOptions(
                                                                              width: 30.0,
                                                                              height: 30.0,
                                                                              padding: EdgeInsetsDirectional.fromSTEB(2.0, 0.0, 0.0, 0.0),
                                                                              iconPadding: EdgeInsetsDirectional.fromSTEB(6.0, 0.0, 0.0, 0.0),
                                                                              iconColor: _model.weekIndex == 0 ? Color(0x80FFFFFF) : FlutterFlowTheme.of(context).alternate,
                                                                              color: Colors.transparent,
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
                                                                              borderRadius: BorderRadius.circular(20.0),
                                                                              disabledColor: Color(0x002A405D),
                                                                              disabledTextColor: FlutterFlowTheme.of(context).primaryText,
                                                                            ),
                                                                          ),
                                                                        Align(
                                                                          alignment: AlignmentDirectional(
                                                                              -1.0,
                                                                              0.0),
                                                                          child:
                                                                              Text(
                                                                            _model.weekIndex > 4
                                                                                ? 'Lessons'
                                                                                : 'Week ${_model.weekIndex.toString()}',
                                                                            style: FlutterFlowTheme.of(context).titleMedium.override(
                                                                                  font: GoogleFonts.poppins(
                                                                                    fontWeight: FlutterFlowTheme.of(context).titleMedium.fontWeight,
                                                                                    fontStyle: FlutterFlowTheme.of(context).titleMedium.fontStyle,
                                                                                  ),
                                                                                  letterSpacing: 0.0,
                                                                                  fontWeight: FlutterFlowTheme.of(context).titleMedium.fontWeight,
                                                                                  fontStyle: FlutterFlowTheme.of(context).titleMedium.fontStyle,
                                                                                ),
                                                                          ),
                                                                        ),
                                                                        if (false)
                                                                          Padding(
                                                                            padding: EdgeInsetsDirectional.fromSTEB(
                                                                                10.0,
                                                                                0.0,
                                                                                10.0,
                                                                                0.0),
                                                                            child:
                                                                                FFButtonWidget(
                                                                              onPressed: (_model.weekIndex == functions.lastIndex(homePageHabitsRecordList.length))
                                                                                  ? null
                                                                                  : () async {
                                                                                      logFirebaseEvent('HOME_PAGE_PAGE__BTN_ON_TAP');
                                                                                    },
                                                                              text: '',
                                                                              icon: Icon(
                                                                                Icons.arrow_circle_right_outlined,
                                                                                size: 30.0,
                                                                              ),
                                                                              options: FFButtonOptions(
                                                                                width: 30.0,
                                                                                height: 30.0,
                                                                                padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                                                                                iconPadding: EdgeInsetsDirectional.fromSTEB(6.0, 0.0, 0.0, 0.0),
                                                                                iconColor: _model.weekIndex == functions.lastIndex(homePageHabitsRecordList.length) ? Color(0x80FFFFFF) : FlutterFlowTheme.of(context).alternate,
                                                                                color: Colors.transparent,
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
                                                                                borderRadius: BorderRadius.circular(20.0),
                                                                              ),
                                                                            ),
                                                                          ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                              Builder(
                                                                builder:
                                                                    (context) {
                                                                  if (_model
                                                                          .weekIndex <
                                                                      4) {
                                                                    return StreamBuilder<
                                                                        List<
                                                                            CategoriesRecord>>(
                                                                      stream:
                                                                          queryCategoriesRecord(
                                                                        queryBuilder: (categoriesRecord) => categoriesRecord
                                                                            .where(
                                                                              'lesson',
                                                                              isEqualTo: containerLessonsRecordList.elementAtOrNull(_model.weekIndex)?.reference,
                                                                            )
                                                                            .orderBy('order'),
                                                                      ),
                                                                      builder:
                                                                          (context,
                                                                              snapshot) {
                                                                        // Customize what your widget looks like when it's loading.
                                                                        if (!snapshot
                                                                            .hasData) {
                                                                          return Center(
                                                                            child:
                                                                                SizedBox(
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
                                                                        List<CategoriesRecord>
                                                                            columnCategoriesRecordList =
                                                                            snapshot.data!;

                                                                        return Column(
                                                                          mainAxisSize:
                                                                              MainAxisSize.max,
                                                                          children: List.generate(
                                                                              columnCategoriesRecordList.length,
                                                                              (columnIndex) {
                                                                            final columnCategoriesRecord =
                                                                                columnCategoriesRecordList[columnIndex];
                                                                            return LessonCategoryListItemWidget(
                                                                              key: Key('Keyxfe_${columnIndex}_of_${columnCategoriesRecordList.length}'),
                                                                              category: columnCategoriesRecord,
                                                                            );
                                                                          }).divide(
                                                                              SizedBox(height: 5.0)),
                                                                        );
                                                                      },
                                                                    );
                                                                  } else {
                                                                    return Align(
                                                                      alignment:
                                                                          AlignmentDirectional(
                                                                              0.0,
                                                                              0.0),
                                                                      child:
                                                                          InkWell(
                                                                        splashColor:
                                                                            Colors.transparent,
                                                                        focusColor:
                                                                            Colors.transparent,
                                                                        hoverColor:
                                                                            Colors.transparent,
                                                                        highlightColor:
                                                                            Colors.transparent,
                                                                        onTap:
                                                                            () async {
                                                                          logFirebaseEvent(
                                                                              'HOME_PAGE_PAGE_Container_22c9l46d_ON_TAP');
                                                                          logFirebaseEvent(
                                                                              'Container_navigate_to');

                                                                          context
                                                                              .goNamed(
                                                                            LibraryPageWidget.routeName,
                                                                            extra: <String,
                                                                                dynamic>{
                                                                              '__transition_info__': TransitionInfo(
                                                                                hasTransition: true,
                                                                                transitionType: PageTransitionType.fade,
                                                                                duration: Duration(milliseconds: 0),
                                                                              ),
                                                                            },
                                                                          );
                                                                        },
                                                                        child:
                                                                            Container(
                                                                          width:
                                                                              double.infinity,
                                                                          height:
                                                                              50.0,
                                                                          decoration:
                                                                              BoxDecoration(
                                                                            color:
                                                                                FlutterFlowTheme.of(context).tertiary,
                                                                            borderRadius:
                                                                                BorderRadius.circular(valueOrDefault<double>(
                                                                              FFAppConstants.borderRadius,
                                                                              0.0,
                                                                            )),
                                                                          ),
                                                                          child:
                                                                              Align(
                                                                            alignment:
                                                                                AlignmentDirectional(0.0, 0.0),
                                                                            child:
                                                                                Text(
                                                                              'View All Lessons',
                                                                              style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                    font: GoogleFonts.poppins(
                                                                                      fontWeight: FontWeight.w500,
                                                                                      fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                    ),
                                                                                    letterSpacing: 0.0,
                                                                                    fontWeight: FontWeight.w500,
                                                                                    fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                  ),
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    );
                                                                  }
                                                                },
                                                              ),
                                                            ],
                                                          ),
                                                        ].addToEnd(SizedBox(
                                                            height: 120.0)),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                            Padding(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(
                                                      20.0, 10.0, 20.0, 0.0),
                                              child: wrapWithModel(
                                                model: _model
                                                    .exploreHabitComponentModel,
                                                updateCallback: () =>
                                                    safeSetState(() {}),
                                                child:
                                                    ExploreHabitComponentWidget(),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Align(
                            alignment: AlignmentDirectional(0.0, 1.0),
                            child: Container(
                              height: 110.0,
                              decoration: BoxDecoration(),
                              child: Visibility(
                                visible: !(isWeb
                                    ? MediaQuery.viewInsetsOf(context).bottom >
                                        0
                                    : _isKeyboardVisible),
                                child: wrapWithModel(
                                  model: _model.bottomNavBarComponentModel,
                                  updateCallback: () => safeSetState(() {}),
                                  child: BottomNavBarComponentWidget(
                                    selectedPageIndex: 1,
                                    hidden: false,
                                    plusButtonVisible: true,
                                    plusButtonAction: () async {
                                      logFirebaseEvent(
                                          'HOME_Container_5bh43yxg_CALLBACK');
                                      logFirebaseEvent(
                                          'bottomNavBarComponent_navigate_to');

                                      context.pushNamed(
                                          CreateHabitPageWidget.routeName);
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (false == true)
                            Text(
                              'build: ${_model.buildNumber}',
                              style: FlutterFlowTheme.of(context)
                                  .headlineMedium
                                  .override(
                                    font: GoogleFonts.poppins(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .headlineMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .headlineMedium
                                          .fontStyle,
                                    ),
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .headlineMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .headlineMedium
                                        .fontStyle,
                                  ),
                            ),
                          wrapWithModel(
                            model: _model.inAppNotificationComponentModel,
                            updateCallback: () => safeSetState(() {}),
                            child: InAppNotificationComponentWidget(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
