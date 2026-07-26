import '/backend/backend.dart';
import '/components/habit_components/category_list_display/category_list_display_widget.dart';
import '/components/resource_article_list_item/resource_article_list_item_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'resources_list_item_model.dart';
export 'resources_list_item_model.dart';

class ResourcesListItemWidget extends StatefulWidget {
  const ResourcesListItemWidget({
    super.key,
    required this.category,
  });

  final CategoriesRecord? category;

  @override
  State<ResourcesListItemWidget> createState() =>
      _ResourcesListItemWidgetState();
}

class _ResourcesListItemWidgetState extends State<ResourcesListItemWidget> {
  late ResourcesListItemModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ResourcesListItemModel());

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
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        Container(
          width: double.infinity,
          color: FlutterFlowTheme.of(context).primary,
          child: ExpandableNotifier(
            controller: _model.expandableExpandableController,
            child: ExpandablePanel(
              header: wrapWithModel(
                model: _model.categoryListDisplayModel,
                updateCallback: () => safeSetState(() {}),
                child: CategoryListDisplayWidget(
                  category: widget!.category!,
                ),
              ),
              collapsed: Container(),
              expanded: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(0.0, 2.0, 0.0, 0.0),
                child: StreamBuilder<List<ArticlesRecord>>(
                  stream: queryArticlesRecord(
                    queryBuilder: (articlesRecord) => articlesRecord.where(
                      'category',
                      isEqualTo: widget!.category?.reference,
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
                    List<ArticlesRecord> columnArticlesRecordList =
                        snapshot.data!;

                    return Column(
                      mainAxisSize: MainAxisSize.max,
                      children: List.generate(columnArticlesRecordList.length,
                          (columnIndex) {
                        final columnArticlesRecord =
                            columnArticlesRecordList[columnIndex];
                        return ResourceArticleListItemWidget(
                          key: Key(
                              'Keycax_${columnIndex}_of_${columnArticlesRecordList.length}'),
                          article: columnArticlesRecord,
                        );
                      }).divide(SizedBox(height: 5.0)),
                    );
                  },
                ),
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
        ),
      ],
    );
  }
}
