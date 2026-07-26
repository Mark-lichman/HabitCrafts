import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/actions/actions.dart' as action_blocks;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'friends_view_component_model.dart';
export 'friends_view_component_model.dart';

class FriendsViewComponentWidget extends StatefulWidget {
  const FriendsViewComponentWidget({
    super.key,
    required this.groupRef,
    required this.contacts,
    required this.invitedCallback,
  });

  final DocumentReference? groupRef;
  final List<DocumentReference>? contacts;
  final Future Function()? invitedCallback;

  @override
  State<FriendsViewComponentWidget> createState() =>
      _FriendsViewComponentWidgetState();
}

class _FriendsViewComponentWidgetState
    extends State<FriendsViewComponentWidget> {
  late FriendsViewComponentModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => FriendsViewComponentModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.transparent,
      ),
      child: Builder(
        builder: (context) {
          if (widget!.contacts != null && (widget!.contacts)!.isNotEmpty) {
            return Builder(
              builder: (context) {
                final contacts = widget!.contacts!.toList();

                return Wrap(
                  spacing: 5.0,
                  runSpacing: 0.0,
                  alignment: WrapAlignment.start,
                  crossAxisAlignment: WrapCrossAlignment.start,
                  direction: Axis.horizontal,
                  runAlignment: WrapAlignment.start,
                  verticalDirection: VerticalDirection.down,
                  clipBehavior: Clip.none,
                  children: List.generate(contacts.length, (contactsIndex) {
                    final contactsItem = contacts[contactsIndex];
                    return Container(
                      width: 34.0,
                      height: 34.0,
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).secondaryBackground,
                        shape: BoxShape.circle,
                      ),
                      child: StreamBuilder<UsersRecord>(
                        stream: UsersRecord.getDocument(contactsItem),
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

                          final imageUsersRecord = snapshot.data!;

                          return InkWell(
                            splashColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            onTap: () async {
                              logFirebaseEvent(
                                  'FRIENDS_VIEW_COMPONENT_Image_e5g92xto_ON');
                              logFirebaseEvent('Image_action_block');
                              _model.didInvite =
                                  await action_blocks.inviteFriendToGroup(
                                context,
                                userToInvite: imageUsersRecord,
                                groupRef: widget!.groupRef,
                              );
                              if (_model.didInvite!) {
                                logFirebaseEvent('Image_execute_callback');
                                await widget.invitedCallback?.call();
                              }

                              safeSetState(() {});
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(17.0),
                              child: Image.network(
                                imageUsersRecord.photoUrl,
                                width: 34.0,
                                height: 34.0,
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }),
                );
              },
            );
          } else {
            return Text(
              'You don\'t have any contacts that use HabitCraft!',
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    font: GoogleFonts.poppins(
                      fontWeight:
                          FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                    ),
                    fontSize: 10.0,
                    letterSpacing: 0.0,
                    fontWeight:
                        FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                  ),
            );
          }
        },
      ),
    );
  }
}
