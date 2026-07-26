import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/bottom_nav_bar_component_widget.dart';
import '/components/group_components/in_app_notification_component/in_app_notification_component_widget.dart';
import '/components/habit_components/finished_habit_list_item/finished_habit_list_item_widget.dart';
import '/components/lifestyle_list_component_widget.dart';
import '/components/notes_modal_component/notes_modal_component_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/index.dart';
import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'progress_page_model.dart';
export 'progress_page_model.dart';

class ProgressPageWidget extends StatefulWidget {
  const ProgressPageWidget({super.key});

  static String routeName = 'progressPage';
  static String routePath = '/progressPage';

  @override
  State<ProgressPageWidget> createState() => _ProgressPageWidgetState();
}

class _ProgressPageWidgetState extends State<ProgressPageWidget>
    with TickerProviderStateMixin {
  late ProgressPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ProgressPageModel());

    logFirebaseEvent('screen_view',
        parameters: {'screen_name': 'progressPage'});
    _model.tabBarController = TabController(
      vsync: this,
      length: 2,
      initialIndex: 0,
    )..addListener(() => safeSetState(() {}));

    _model.expandableExpandableController =
        ExpandableController(initialExpanded: false)
          ..addListener(() => safeSetState(() {}));
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
        body: Align(
          alignment: AlignmentDirectional(0.0, -1.0),
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
                            logFirebaseEvent('PROGRESS_PAGE_PAGE__BTN_ON_TAP');
                            logFirebaseEvent('Button_navigate_to');

                            context.pushNamed(ProfilePageWidget.routeName);
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
                            iconPadding: EdgeInsetsDirectional.fromSTEB(
                                0.0, 0.0, 0.0, 0.0),
                            iconColor: FlutterFlowTheme.of(context).grayDark,
                            color: FlutterFlowTheme.of(context)
                                .secondaryBackground,
                            textStyle: FlutterFlowTheme.of(context)
                                .titleSmall
                                .override(
                                  font: GoogleFonts.poppins(
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontStyle,
                                  ),
                                  color: Colors.white,
                                  letterSpacing: 0.0,
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
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
                        padding:
                            EdgeInsetsDirectional.fromSTEB(0.0, 30.0, 0.0, 0.0),
                        child: Text(
                          'Progress',
                          style:
                              FlutterFlowTheme.of(context).titleMedium.override(
                                    font: GoogleFonts.poppins(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .fontStyle,
                                    ),
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .fontStyle,
                                  ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(
                            10.0, 0.0, 10.0, 0.0),
                        child: StreamBuilder<List<HabitsRecord>>(
                          stream: queryHabitsRecord(
                            queryBuilder: (habitsRecord) => habitsRecord
                                .where(
                                  'user',
                                  isEqualTo: currentUserReference,
                                )
                                .where(
                                  'is_finished',
                                  isEqualTo: true,
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
                            List<HabitsRecord> tabBarHabitsRecordList =
                                snapshot.data!;

                            return Column(
                              children: [
                                Align(
                                  alignment: Alignment(0.0, 0),
                                  child: TabBar(
                                    labelColor:
                                        FlutterFlowTheme.of(context).alternate,
                                    unselectedLabelColor:
                                        FlutterFlowTheme.of(context).alternate,
                                    labelStyle: FlutterFlowTheme.of(context)
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
                                    unselectedLabelStyle: TextStyle(),
                                    indicatorColor:
                                        FlutterFlowTheme.of(context).accent1,
                                    padding: EdgeInsets.all(4.0),
                                    tabs: [
                                      Tab(
                                        text: 'Summary',
                                      ),
                                      Tab(
                                        text: 'Lifestyle',
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
                                      SingleChildScrollView(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.max,
                                          children: [
                                            Padding(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(
                                                      0.0, 10.0, 0.0, 0.0),
                                              child: StreamBuilder<
                                                  List<HabitsRecord>>(
                                                stream: queryHabitsRecord(
                                                  queryBuilder:
                                                      (habitsRecord) =>
                                                          habitsRecord.where(
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
                                                  List<HabitsRecord>
                                                      progressLineChartWidgetHabitsRecordList =
                                                      snapshot.data!;

                                                  return Container(
                                                    width: double.infinity,
                                                    height: 231.0,
                                                    child: custom_widgets
                                                        .ProgressLineChartWidget(
                                                      width: double.infinity,
                                                      height: 231.0,
                                                      habits:
                                                          progressLineChartWidgetHabitsRecordList,
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                            Builder(
                                              builder: (context) => Padding(
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        0.0, 10.0, 0.0, 0.0),
                                                child: StreamBuilder<
                                                    List<UserActivityRecord>>(
                                                  stream:
                                                      queryUserActivityRecord(
                                                    parent:
                                                        currentUserReference,
                                                    queryBuilder:
                                                        (userActivityRecord) =>
                                                            userActivityRecord
                                                                .orderBy(
                                                                    'created'),
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
                                                    List<UserActivityRecord>
                                                        progressCalendarWidgetUserActivityRecordList =
                                                        snapshot.data!;

                                                    return Container(
                                                      width: double.infinity,
                                                      height: 400.0,
                                                      child: custom_widgets
                                                          .ProgressCalendarWidget(
                                                        width: double.infinity,
                                                        height: 400.0,
                                                        activites:
                                                            progressCalendarWidgetUserActivityRecordList,
                                                        displayNotesCallback:
                                                            () async {
                                                          logFirebaseEvent(
                                                              'PROGRESS_Container_rrisgy8a_CALLBACK');
                                                          logFirebaseEvent(
                                                              'ProgressCalendarWidget_alert_dialog');
                                                          await showDialog(
                                                            context: context,
                                                            builder:
                                                                (dialogContext) {
                                                              return Dialog(
                                                                elevation: 0,
                                                                insetPadding:
                                                                    EdgeInsets
                                                                        .zero,
                                                                backgroundColor:
                                                                    Colors
                                                                        .transparent,
                                                                alignment: AlignmentDirectional(
                                                                        0.0,
                                                                        0.0)
                                                                    .resolve(
                                                                        Directionality.of(
                                                                            context)),
                                                                child:
                                                                    GestureDetector(
                                                                  onTap: () {
                                                                    FocusScope.of(
                                                                            dialogContext)
                                                                        .unfocus();
                                                                    FocusManager
                                                                        .instance
                                                                        .primaryFocus
                                                                        ?.unfocus();
                                                                  },
                                                                  child:
                                                                      NotesModalComponentWidget(
                                                                    activityRef:
                                                                        FFAppState()
                                                                            .tempActivityRef!,
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                          );
                                                        },
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          ].addToEnd(SizedBox(height: 130.0)),
                                        ),
                                      ),
                                      SingleChildScrollView(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Align(
                                              alignment: AlignmentDirectional(
                                                  -1.0, 0.0),
                                              child: Text(
                                                'Hey there!',
                                                style: FlutterFlowTheme.of(
                                                        context)
                                                    .bodyMedium
                                                    .override(
                                                      font: GoogleFonts.poppins(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                      ),
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .accent1,
                                                      letterSpacing: 0.0,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontStyle:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyMedium
                                                              .fontStyle,
                                                    ),
                                              ),
                                            ),
                                            Text(
                                              'Here is where you will see your fulfilled habits. These things have become a part of your everyday lifestyle. Remember, every small step gets you closer to your goals. Give yourself credit for all the efforts you’ve been putting in and see where it takes you!',
                                              style: FlutterFlowTheme.of(
                                                      context)
                                                  .bodyMedium
                                                  .override(
                                                    font: GoogleFonts.poppins(
                                                      fontWeight:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyMedium
                                                              .fontWeight,
                                                      fontStyle:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyMedium
                                                              .fontStyle,
                                                    ),
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .alternate,
                                                    fontSize: 12.0,
                                                    letterSpacing: 0.0,
                                                    fontWeight:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodyMedium
                                                            .fontWeight,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodyMedium
                                                            .fontStyle,
                                                  ),
                                            ),
                                            wrapWithModel(
                                              model: _model
                                                  .lifestyleListComponentModel1,
                                              updateCallback: () =>
                                                  safeSetState(() {}),
                                              child:
                                                  LifestyleListComponentWidget(),
                                            ),
                                            Container(
                                              decoration: BoxDecoration(),
                                              child: Container(
                                                width: double.infinity,
                                                color: Color(0x00000000),
                                                child: ExpandableNotifier(
                                                  controller: _model
                                                      .expandableExpandableController,
                                                  child: ExpandablePanel(
                                                    header: Align(
                                                      alignment:
                                                          AlignmentDirectional(
                                                              -1.0, 0.0),
                                                      child: Text(
                                                        'Removed Habits',
                                                        style:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .override(
                                                                  font: GoogleFonts
                                                                      .poppins(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .fontStyle,
                                                                  ),
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .alternate,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .fontStyle,
                                                                ),
                                                      ),
                                                    ),
                                                    collapsed: Container(),
                                                    expanded: Container(
                                                      decoration:
                                                          BoxDecoration(),
                                                      child: Visibility(
                                                        visible:
                                                            tabBarHabitsRecordList
                                                                .isNotEmpty,
                                                        child: Builder(
                                                          builder: (context) {
                                                            final tabBarVar =
                                                                tabBarHabitsRecordList
                                                                    .toList();

                                                            return Column(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: List.generate(
                                                                      tabBarVar
                                                                          .length,
                                                                      (tabBarVarIndex) {
                                                                final tabBarVarItem =
                                                                    tabBarVar[
                                                                        tabBarVarIndex];
                                                                return FinishedHabitListItemWidget(
                                                                  key: Key(
                                                                      'Keyyno_${tabBarVarIndex}_of_${tabBarVar.length}'),
                                                                  habit:
                                                                      tabBarVarItem,
                                                                );
                                                              })
                                                                  .divide(SizedBox(
                                                                      height:
                                                                          10.0))
                                                                  .addToStart(
                                                                      SizedBox(
                                                                          height:
                                                                              10.0))
                                                                  .addToEnd(SizedBox(
                                                                      height:
                                                                          60.0)),
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
                                                          ExpandablePanelHeaderAlignment
                                                              .center,
                                                      hasIcon: true,
                                                      iconColor:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .tertiary,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ].addToEnd(SizedBox(height: 120.0)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    if (responsiveVisibility(
                      context: context,
                      phone: false,
                      tablet: false,
                      tabletLandscape: false,
                      desktop: false,
                    ))
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          height: 100.0,
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context).primary,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Container(
                                    width: () {
                                      if (MediaQuery.sizeOf(context).width <
                                          kBreakpointSmall) {
                                        return (MediaQuery.sizeOf(context)
                                                .width *
                                            0.5);
                                      } else if (MediaQuery.sizeOf(context)
                                              .width <
                                          kBreakpointMedium) {
                                        return (MediaQuery.sizeOf(context)
                                                .width *
                                            0.5);
                                      } else if (MediaQuery.sizeOf(context)
                                              .width <
                                          kBreakpointLarge) {
                                        return (MediaQuery.sizeOf(context)
                                                .width *
                                            0.5);
                                      } else {
                                        return (MediaQuery.sizeOf(context)
                                                .width *
                                            0.5);
                                      }
                                    }(),
                                    height: 400.0,
                                    decoration: BoxDecoration(),
                                    child: Builder(
                                      builder: (context) => Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            0.0, 10.0, 0.0, 0.0),
                                        child: StreamBuilder<
                                            List<UserActivityRecord>>(
                                          stream: queryUserActivityRecord(
                                            parent: currentUserReference,
                                            queryBuilder:
                                                (userActivityRecord) =>
                                                    userActivityRecord
                                                        .orderBy('created'),
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
                                            List<UserActivityRecord>
                                                progressCalendarWidgetUserActivityRecordList =
                                                snapshot.data!;

                                            return Container(
                                              width: double.infinity,
                                              height: 400.0,
                                              child: custom_widgets
                                                  .ProgressCalendarWidget(
                                                width: double.infinity,
                                                height: 400.0,
                                                activites:
                                                    progressCalendarWidgetUserActivityRecordList,
                                                displayNotesCallback: () async {
                                                  logFirebaseEvent(
                                                      'PROGRESS_Container_2hh4pfmu_CALLBACK');
                                                  logFirebaseEvent(
                                                      'ProgressCalendarWidget_alert_dialog');
                                                  await showDialog(
                                                    context: context,
                                                    builder: (dialogContext) {
                                                      return Dialog(
                                                        elevation: 0,
                                                        insetPadding:
                                                            EdgeInsets.zero,
                                                        backgroundColor:
                                                            Colors.transparent,
                                                        alignment:
                                                            AlignmentDirectional(
                                                                    0.0, 0.0)
                                                                .resolve(
                                                                    Directionality.of(
                                                                        context)),
                                                        child: GestureDetector(
                                                          onTap: () {
                                                            FocusScope.of(
                                                                    dialogContext)
                                                                .unfocus();
                                                            FocusManager
                                                                .instance
                                                                .primaryFocus
                                                                ?.unfocus();
                                                          },
                                                          child:
                                                              NotesModalComponentWidget(
                                                            activityRef:
                                                                FFAppState()
                                                                    .tempActivityRef!,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  );
                                                },
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: () {
                                      if (MediaQuery.sizeOf(context).width <
                                          kBreakpointSmall) {
                                        return (MediaQuery.sizeOf(context)
                                                .width *
                                            0.5);
                                      } else if (MediaQuery.sizeOf(context)
                                              .width <
                                          kBreakpointMedium) {
                                        return (MediaQuery.sizeOf(context)
                                                .width *
                                            0.5);
                                      } else if (MediaQuery.sizeOf(context)
                                              .width <
                                          kBreakpointLarge) {
                                        return (MediaQuery.sizeOf(context)
                                                .width *
                                            0.5);
                                      } else {
                                        return (MediaQuery.sizeOf(context)
                                                .width *
                                            0.5);
                                      }
                                    }(),
                                    height: 400.0,
                                    decoration: BoxDecoration(),
                                    child: Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          0.0, 10.0, 0.0, 0.0),
                                      child: StreamBuilder<List<HabitsRecord>>(
                                        stream: queryHabitsRecord(
                                          queryBuilder: (habitsRecord) =>
                                              habitsRecord.where(
                                            'user',
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
                                                child:
                                                    CircularProgressIndicator(
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                          Color>(
                                                    FlutterFlowTheme.of(context)
                                                        .primary,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }
                                          List<HabitsRecord>
                                              progressLineChartWidgetHabitsRecordList =
                                              snapshot.data!;

                                          return Container(
                                            width: () {
                                              if (MediaQuery.sizeOf(context)
                                                      .width <
                                                  kBreakpointSmall) {
                                                return (MediaQuery.sizeOf(
                                                            context)
                                                        .width *
                                                    0.5);
                                              } else if (MediaQuery.sizeOf(
                                                          context)
                                                      .width <
                                                  kBreakpointMedium) {
                                                return (MediaQuery.sizeOf(
                                                            context)
                                                        .width *
                                                    0.5);
                                              } else if (MediaQuery.sizeOf(
                                                          context)
                                                      .width <
                                                  kBreakpointLarge) {
                                                return (MediaQuery.sizeOf(
                                                            context)
                                                        .width *
                                                    0.5);
                                              } else {
                                                return (MediaQuery.sizeOf(
                                                            context)
                                                        .width *
                                                    0.5);
                                              }
                                            }(),
                                            height: 231.0,
                                            child: custom_widgets
                                                .ProgressLineChartWidget(
                                              width: () {
                                                if (MediaQuery.sizeOf(context)
                                                        .width <
                                                    kBreakpointSmall) {
                                                  return (MediaQuery.sizeOf(
                                                              context)
                                                          .width *
                                                      0.5);
                                                } else if (MediaQuery.sizeOf(
                                                            context)
                                                        .width <
                                                    kBreakpointMedium) {
                                                  return (MediaQuery.sizeOf(
                                                              context)
                                                          .width *
                                                      0.5);
                                                } else if (MediaQuery.sizeOf(
                                                            context)
                                                        .width <
                                                    kBreakpointLarge) {
                                                  return (MediaQuery.sizeOf(
                                                              context)
                                                          .width *
                                                      0.5);
                                                } else {
                                                  return (MediaQuery.sizeOf(
                                                              context)
                                                          .width *
                                                      0.5);
                                                }
                                              }(),
                                              height: 231.0,
                                              habits:
                                                  progressLineChartWidgetHabitsRecordList,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    20.0, 0.0, 20.0, 0.0),
                                child: Container(
                                  width: () {
                                    if (MediaQuery.sizeOf(context).width <
                                        kBreakpointSmall) {
                                      return (MediaQuery.sizeOf(context).width *
                                          0.4);
                                    } else if (MediaQuery.sizeOf(context)
                                            .width <
                                        kBreakpointMedium) {
                                      return (MediaQuery.sizeOf(context).width *
                                          0.4);
                                    } else if (MediaQuery.sizeOf(context)
                                            .width <
                                        kBreakpointLarge) {
                                      return (MediaQuery.sizeOf(context).width *
                                          0.4);
                                    } else {
                                      return (MediaQuery.sizeOf(context).width *
                                          0.4);
                                    }
                                  }(),
                                  height: double.infinity,
                                  decoration: BoxDecoration(),
                                  child: wrapWithModel(
                                    model: _model.lifestyleListComponentModel2,
                                    updateCallback: () => safeSetState(() {}),
                                    child: LifestyleListComponentWidget(),
                                  ),
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
                    child: wrapWithModel(
                      model: _model.bottomNavBarComponentModel,
                      updateCallback: () => safeSetState(() {}),
                      child: BottomNavBarComponentWidget(
                        selectedPageIndex: 2,
                        hidden: false,
                        plusButtonVisible: true,
                        plusButtonAction: () async {
                          logFirebaseEvent(
                              'PROGRESS_Container_mbql4eji_CALLBACK');
                          logFirebaseEvent('bottomNavBarComponent_navigate_to');

                          context.pushNamed(CreateHabitPageWidget.routeName);
                        },
                      ),
                    ),
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
        ),
      ),
    );
  }
}
