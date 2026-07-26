import '/backend/backend.dart';
import '/components/bottom_nav_bar_component_widget.dart';
import '/components/group_components/in_app_notification_component/in_app_notification_component_widget.dart';
import '/components/lesson_category_list_item_widget.dart';
import '/components/resources_list_item/resources_list_item_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:async';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/index.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:text_search/text_search.dart';
import 'library_page_model.dart';
export 'library_page_model.dart';

class LibraryPageWidget extends StatefulWidget {
  const LibraryPageWidget({super.key});

  static String routeName = 'libraryPage';
  static String routePath = '/libraryPage';

  @override
  State<LibraryPageWidget> createState() => _LibraryPageWidgetState();
}

class _LibraryPageWidgetState extends State<LibraryPageWidget>
    with TickerProviderStateMixin {
  late LibraryPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  late StreamSubscription<bool> _keyboardVisibilitySubscription;
  bool _isKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => LibraryPageModel());

    logFirebaseEvent('screen_view', parameters: {'screen_name': 'libraryPage'});
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

    _model.textController ??= TextEditingController();
    _model.textFieldFocusNode ??= FocusNode();

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
                            logFirebaseEvent('LIBRARY_PAGE_PAGE__BTN_ON_TAP');
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
                    Padding(
                      padding:
                          EdgeInsetsDirectional.fromSTEB(0.0, 30.0, 0.0, 0.0),
                      child: Text(
                        'Library',
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
                    Expanded(
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment(0.0, 0),
                            child: TabBar(
                              labelColor:
                                  FlutterFlowTheme.of(context).alternate,
                              unselectedLabelColor:
                                  FlutterFlowTheme.of(context).secondaryText,
                              labelStyle: FlutterFlowTheme.of(context)
                                  .titleMedium
                                  .override(
                                    font: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w800,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .fontStyle,
                                    ),
                                    fontSize: 16.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w800,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .fontStyle,
                                  ),
                              unselectedLabelStyle: TextStyle(),
                              indicatorColor:
                                  FlutterFlowTheme.of(context).accent1,
                              padding: EdgeInsets.all(4.0),
                              tabs: [
                                Tab(
                                  text: 'Lessons',
                                ),
                                Tab(
                                  text: 'Resources',
                                ),
                              ],
                              controller: _model.tabBarController,
                              onTap: (i) async {
                                [
                                  () async {
                                    logFirebaseEvent(
                                        'LIBRARY_PAGE_PAGE_Tab_wqiyxvvv_ON_TAP');
                                    logFirebaseEvent('Tab_custom_action');
                                    await actions.hideKeyboard();
                                  },
                                  () async {}
                                ][i]();
                              },
                            ),
                          ),
                          Expanded(
                            child: TabBarView(
                              controller: _model.tabBarController,
                              children: [
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 10.0, 0.0, 0.0),
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
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                FlutterFlowTheme.of(context)
                                                    .primary,
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                      List<LessonsRecord>
                                          containerLessonsRecordList =
                                          snapshot.data!;

                                      return Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(),
                                        child: Padding(
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  20.0, 0.0, 20.0, 0.0),
                                          child: SingleChildScrollView(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.max,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding: EdgeInsetsDirectional
                                                      .fromSTEB(
                                                          0.0, 0.0, 0.0, 10.0),
                                                  child: Container(
                                                    width: double.infinity,
                                                    height: 50.0,
                                                    decoration: BoxDecoration(
                                                      color: Color(0xFF69849F),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8.0),
                                                    ),
                                                    alignment:
                                                        AlignmentDirectional(
                                                            -1.0, 0.0),
                                                    child: Padding(
                                                      padding:
                                                          EdgeInsetsDirectional
                                                              .fromSTEB(
                                                                  10.0,
                                                                  0.0,
                                                                  10.0,
                                                                  0.0),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.max,
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          Opacity(
                                                            opacity:
                                                                _model.weekIndex ==
                                                                        0
                                                                    ? 0.5
                                                                    : 1.0,
                                                            child:
                                                                FFButtonWidget(
                                                              onPressed: (_model
                                                                          .weekIndex ==
                                                                      0)
                                                                  ? null
                                                                  : () async {
                                                                      logFirebaseEvent(
                                                                          'LIBRARY_PAGE_PAGE__BTN_ON_TAP');
                                                                      logFirebaseEvent(
                                                                          'Button_update_page_state');
                                                                      _model.weekIndex =
                                                                          _model.weekIndex +
                                                                              -1;
                                                                      safeSetState(
                                                                          () {});
                                                                    },
                                                              text: '',
                                                              icon: Icon(
                                                                Icons
                                                                    .arrow_circle_left_outlined,
                                                                size: 30.0,
                                                              ),
                                                              options:
                                                                  FFButtonOptions(
                                                                width: 30.0,
                                                                height: 30.0,
                                                                padding:
                                                                    EdgeInsets
                                                                        .all(
                                                                            0.0),
                                                                iconPadding:
                                                                    EdgeInsetsDirectional
                                                                        .fromSTEB(
                                                                            0.0,
                                                                            0.0,
                                                                            0.0,
                                                                            0.0),
                                                                iconColor: FlutterFlowTheme.of(
                                                                        context)
                                                                    .alternate,
                                                                color: Colors
                                                                    .transparent,
                                                                textStyle: FlutterFlowTheme.of(
                                                                        context)
                                                                    .titleSmall
                                                                    .override(
                                                                      font: GoogleFonts
                                                                          .poppins(
                                                                        fontWeight: FlutterFlowTheme.of(context)
                                                                            .titleSmall
                                                                            .fontWeight,
                                                                        fontStyle: FlutterFlowTheme.of(context)
                                                                            .titleSmall
                                                                            .fontStyle,
                                                                      ),
                                                                      color: Colors
                                                                          .white,
                                                                      letterSpacing:
                                                                          0.0,
                                                                      fontWeight: FlutterFlowTheme.of(
                                                                              context)
                                                                          .titleSmall
                                                                          .fontWeight,
                                                                      fontStyle: FlutterFlowTheme.of(
                                                                              context)
                                                                          .titleSmall
                                                                          .fontStyle,
                                                                    ),
                                                                elevation: 0.0,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            20.0),
                                                                disabledColor:
                                                                    Color(
                                                                        0x002A405D),
                                                                disabledTextColor:
                                                                    FlutterFlowTheme.of(
                                                                            context)
                                                                        .primaryText,
                                                              ),
                                                            ),
                                                          ),
                                                          Align(
                                                            alignment:
                                                                AlignmentDirectional(
                                                                    -1.0, 0.0),
                                                            child: Text(
                                                              valueOrDefault<
                                                                  String>(
                                                                containerLessonsRecordList
                                                                    .elementAtOrNull(
                                                                        _model
                                                                            .weekIndex)
                                                                    ?.title,
                                                                'title',
                                                              ),
                                                              style: FlutterFlowTheme
                                                                      .of(context)
                                                                  .titleMedium
                                                                  .override(
                                                                    font: GoogleFonts
                                                                        .poppins(
                                                                      fontWeight: FlutterFlowTheme.of(
                                                                              context)
                                                                          .titleMedium
                                                                          .fontWeight,
                                                                      fontStyle: FlutterFlowTheme.of(
                                                                              context)
                                                                          .titleMedium
                                                                          .fontStyle,
                                                                    ),
                                                                    letterSpacing:
                                                                        0.0,
                                                                    fontWeight: FlutterFlowTheme.of(
                                                                            context)
                                                                        .titleMedium
                                                                        .fontWeight,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .titleMedium
                                                                        .fontStyle,
                                                                  ),
                                                            ),
                                                          ),
                                                          Opacity(
                                                            opacity: _model
                                                                        .weekIndex ==
                                                                    (containerLessonsRecordList
                                                                            .length -
                                                                        1)
                                                                ? 0.5
                                                                : 1.0,
                                                            child:
                                                                FFButtonWidget(
                                                              onPressed: (_model
                                                                          .weekIndex ==
                                                                      (containerLessonsRecordList
                                                                              .length -
                                                                          1))
                                                                  ? null
                                                                  : () async {
                                                                      logFirebaseEvent(
                                                                          'LIBRARY_PAGE_PAGE__BTN_ON_TAP');
                                                                      logFirebaseEvent(
                                                                          'Button_update_page_state');
                                                                      _model.weekIndex =
                                                                          _model.weekIndex +
                                                                              1;
                                                                      safeSetState(
                                                                          () {});
                                                                    },
                                                              text: '',
                                                              icon: Icon(
                                                                Icons
                                                                    .arrow_circle_right_outlined,
                                                                size: 30.0,
                                                              ),
                                                              options:
                                                                  FFButtonOptions(
                                                                width: 30.0,
                                                                height: 30.0,
                                                                padding:
                                                                    EdgeInsetsDirectional
                                                                        .fromSTEB(
                                                                            0.0,
                                                                            0.0,
                                                                            0.0,
                                                                            0.0),
                                                                iconPadding:
                                                                    EdgeInsetsDirectional
                                                                        .fromSTEB(
                                                                            0.0,
                                                                            0.0,
                                                                            0.0,
                                                                            0.0),
                                                                iconColor: FlutterFlowTheme.of(
                                                                        context)
                                                                    .alternate,
                                                                color: Colors
                                                                    .transparent,
                                                                textStyle: FlutterFlowTheme.of(
                                                                        context)
                                                                    .titleSmall
                                                                    .override(
                                                                      font: GoogleFonts
                                                                          .poppins(
                                                                        fontWeight: FlutterFlowTheme.of(context)
                                                                            .titleSmall
                                                                            .fontWeight,
                                                                        fontStyle: FlutterFlowTheme.of(context)
                                                                            .titleSmall
                                                                            .fontStyle,
                                                                      ),
                                                                      color: Colors
                                                                          .white,
                                                                      letterSpacing:
                                                                          0.0,
                                                                      fontWeight: FlutterFlowTheme.of(
                                                                              context)
                                                                          .titleSmall
                                                                          .fontWeight,
                                                                      fontStyle: FlutterFlowTheme.of(
                                                                              context)
                                                                          .titleSmall
                                                                          .fontStyle,
                                                                    ),
                                                                elevation: 0.0,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            20.0),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                StreamBuilder<
                                                    List<CategoriesRecord>>(
                                                  stream: queryCategoriesRecord(
                                                    queryBuilder:
                                                        (categoriesRecord) =>
                                                            categoriesRecord
                                                                .where(
                                                                  'lesson',
                                                                  isEqualTo: containerLessonsRecordList
                                                                      .elementAtOrNull(
                                                                          _model
                                                                              .weekIndex)
                                                                      ?.reference,
                                                                )
                                                                .orderBy(
                                                                    'order'),
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
                                                    List<CategoriesRecord>
                                                        columnCategoriesRecordList =
                                                        snapshot.data!;

                                                    return Column(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      children: List.generate(
                                                              columnCategoriesRecordList
                                                                  .length,
                                                              (columnIndex) {
                                                        final columnCategoriesRecord =
                                                            columnCategoriesRecordList[
                                                                columnIndex];
                                                        return LessonCategoryListItemWidget(
                                                          key: Key(
                                                              'Key3au_${columnIndex}_of_${columnCategoriesRecordList.length}'),
                                                          category:
                                                              columnCategoriesRecord,
                                                        );
                                                      })
                                                          .divide(SizedBox(
                                                              height: 5.0))
                                                          .addToEnd(SizedBox(
                                                              height: 120.0)),
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      20.0, 10.0, 20.0, 0.0),
                                  child: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        Padding(
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  0.0, 0.0, 0.0, 10.0),
                                          child: TextFormField(
                                            controller: _model.textController,
                                            focusNode:
                                                _model.textFieldFocusNode,
                                            onChanged: (_) =>
                                                EasyDebounce.debounce(
                                              '_model.textController',
                                              Duration(milliseconds: 2000),
                                              () async {
                                                logFirebaseEvent(
                                                    'LIBRARY_TextField_bfj7wirc_ON_TEXTFIELD_');
                                                if (_model
                                                        .textController.text ==
                                                    '') {
                                                  logFirebaseEvent(
                                                      'TextField_update_page_state');
                                                  _model.isShowFullList = true;
                                                  safeSetState(() {});
                                                } else {
                                                  logFirebaseEvent(
                                                      'TextField_update_page_state');
                                                  _model.isShowFullList = false;
                                                  safeSetState(() {});
                                                  logFirebaseEvent(
                                                      'TextField_simple_search');
                                                  await queryCategoriesRecordOnce()
                                                      .then(
                                                        (records) => _model
                                                                .simpleSearchResults =
                                                            TextSearch(
                                                          records
                                                              .map(
                                                                (record) =>
                                                                    TextSearchItem
                                                                        .fromTerms(
                                                                            record,
                                                                            [
                                                                      record
                                                                          .description!
                                                                    ]),
                                                              )
                                                              .toList(),
                                                        )
                                                                .search(_model
                                                                    .textController
                                                                    .text)
                                                                .map((r) =>
                                                                    r.object)
                                                                .toList(),
                                                      )
                                                      .onError((_, __) => _model
                                                              .simpleSearchResults =
                                                          [])
                                                      .whenComplete(() =>
                                                          safeSetState(() {}));
                                                }
                                              },
                                            ),
                                            autofocus: false,
                                            obscureText: false,
                                            decoration: InputDecoration(
                                              isDense: true,
                                              alignLabelWithHint: true,
                                              hintText: 'Search',
                                              hintStyle: FlutterFlowTheme.of(
                                                      context)
                                                  .labelMedium
                                                  .override(
                                                    font: GoogleFonts.poppins(
                                                      fontWeight:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .labelMedium
                                                              .fontWeight,
                                                      fontStyle:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .labelMedium
                                                              .fontStyle,
                                                    ),
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .tertiary,
                                                    fontSize: 14.0,
                                                    letterSpacing: 0.0,
                                                    fontWeight:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .labelMedium
                                                            .fontWeight,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .labelMedium
                                                            .fontStyle,
                                                  ),
                                              enabledBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .alternate,
                                                  width: 2.0,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12.0),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .tertiary,
                                                  width: 2.0,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12.0),
                                              ),
                                              errorBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .error,
                                                  width: 2.0,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12.0),
                                              ),
                                              focusedErrorBorder:
                                                  OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .error,
                                                  width: 2.0,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12.0),
                                              ),
                                              prefixIcon: Icon(
                                                Icons.search,
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .tertiary,
                                                size: 20.0,
                                              ),
                                              suffixIcon: _model.textController!
                                                      .text.isNotEmpty
                                                  ? InkWell(
                                                      onTap: () async {
                                                        _model.textController
                                                            ?.clear();
                                                        logFirebaseEvent(
                                                            'LIBRARY_TextField_bfj7wirc_ON_TEXTFIELD_');
                                                        if (_model
                                                                .textController
                                                                .text ==
                                                            '') {
                                                          logFirebaseEvent(
                                                              'TextField_update_page_state');
                                                          _model.isShowFullList =
                                                              true;
                                                          safeSetState(() {});
                                                        } else {
                                                          logFirebaseEvent(
                                                              'TextField_update_page_state');
                                                          _model.isShowFullList =
                                                              false;
                                                          safeSetState(() {});
                                                          logFirebaseEvent(
                                                              'TextField_simple_search');
                                                          await queryCategoriesRecordOnce()
                                                              .then(
                                                                (records) => _model
                                                                        .simpleSearchResults =
                                                                    TextSearch(
                                                                  records
                                                                      .map(
                                                                        (record) => TextSearchItem.fromTerms(
                                                                            record,
                                                                            [
                                                                              record.description!
                                                                            ]),
                                                                      )
                                                                      .toList(),
                                                                )
                                                                        .search(_model
                                                                            .textController
                                                                            .text)
                                                                        .map((r) =>
                                                                            r.object)
                                                                        .toList(),
                                                              )
                                                              .onError((_,
                                                                      __) =>
                                                                  _model.simpleSearchResults =
                                                                      [])
                                                              .whenComplete(() =>
                                                                  safeSetState(
                                                                      () {}));
                                                        }

                                                        safeSetState(() {});
                                                      },
                                                      child: Icon(
                                                        Icons.clear,
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .tertiary,
                                                        size: 20.0,
                                                      ),
                                                    )
                                                  : null,
                                            ),
                                            style: FlutterFlowTheme.of(context)
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
                                            cursorColor:
                                                FlutterFlowTheme.of(context)
                                                    .tertiary,
                                            validator: _model
                                                .textControllerValidator
                                                .asValidator(context),
                                          ),
                                        ),
                                        Builder(
                                          builder: (context) {
                                            if (_model.isShowFullList) {
                                              return StreamBuilder<
                                                  List<CategoriesRecord>>(
                                                stream: queryCategoriesRecord(
                                                  queryBuilder:
                                                      (categoriesRecord) =>
                                                          categoriesRecord
                                                              .where(
                                                                'parentCategory',
                                                                isEqualTo:
                                                                    FFAppState()
                                                                        .noParentCategory,
                                                              )
                                                              .orderBy('order'),
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
                                                  List<CategoriesRecord>
                                                      columnCategoriesRecordList =
                                                      snapshot.data!;

                                                  return Column(
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    children: List.generate(
                                                            columnCategoriesRecordList
                                                                .length,
                                                            (columnIndex) {
                                                      final columnCategoriesRecord =
                                                          columnCategoriesRecordList[
                                                              columnIndex];
                                                      return Container(
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .transparent,
                                                        ),
                                                        child:
                                                            ResourcesListItemWidget(
                                                          key: Key(
                                                              'Key4cb_${columnIndex}_of_${columnCategoriesRecordList.length}'),
                                                          category:
                                                              columnCategoriesRecord,
                                                        ),
                                                      );
                                                    })
                                                        .divide(SizedBox(
                                                            height: 5.0))
                                                        .addToEnd(SizedBox(
                                                            height: 80.0)),
                                                  );
                                                },
                                              );
                                            } else {
                                              return Builder(
                                                builder: (context) {
                                                  final searchResults = _model
                                                      .simpleSearchResults
                                                      .toList();

                                                  return Column(
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    children: List.generate(
                                                            searchResults
                                                                .length,
                                                            (searchResultsIndex) {
                                                      final searchResultsItem =
                                                          searchResults[
                                                              searchResultsIndex];
                                                      return Container(
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .transparent,
                                                        ),
                                                        child:
                                                            ResourcesListItemWidget(
                                                          key: Key(
                                                              'Key1je_${searchResultsIndex}_of_${searchResults.length}'),
                                                          category:
                                                              searchResultsItem,
                                                        ),
                                                      );
                                                    })
                                                        .divide(SizedBox(
                                                            height: 5.0))
                                                        .addToEnd(SizedBox(
                                                            height: 100.0)),
                                                  );
                                                },
                                              );
                                            }
                                          },
                                        ),
                                      ].addToEnd(SizedBox(height: 100.0)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: AlignmentDirectional(0.0, 1.0),
                  child: Container(
                    height: 120.0,
                    decoration: BoxDecoration(),
                    child: Visibility(
                      visible: !(isWeb
                          ? MediaQuery.viewInsetsOf(context).bottom > 0
                          : _isKeyboardVisible),
                      child: wrapWithModel(
                        model: _model.bottomNavBarComponentModel,
                        updateCallback: () => safeSetState(() {}),
                        child: BottomNavBarComponentWidget(
                          selectedPageIndex: 4,
                          hidden: false,
                          plusButtonVisible: true,
                          plusButtonAction: () async {
                            logFirebaseEvent(
                                'LIBRARY_Container_rtmx6w46_CALLBACK');
                            logFirebaseEvent(
                                'bottomNavBarComponent_navigate_to');

                            context.pushNamed(CreateHabitPageWidget.routeName);
                          },
                        ),
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
