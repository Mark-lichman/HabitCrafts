import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/components/group_components/group_list_contents/group_list_contents_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'group_list_item_model.dart';
export 'group_list_item_model.dart';

class GroupListItemWidget extends StatefulWidget {
  const GroupListItemWidget({
    super.key,
    required this.group,
  });

  final GroupsRecord? group;

  @override
  State<GroupListItemWidget> createState() => _GroupListItemWidgetState();
}

class _GroupListItemWidgetState extends State<GroupListItemWidget> {
  late GroupListItemModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => GroupListItemModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return wrapWithModel(
      model: _model.groupListContentsModel,
      updateCallback: () => safeSetState(() {}),
      child: GroupListContentsWidget(
        group: widget!.group!,
      ),
    );
  }
}
