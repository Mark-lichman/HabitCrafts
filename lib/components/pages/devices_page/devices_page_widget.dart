// HAND-WRITTEN. Not FlutterFlow output, so S3 has nothing to adopt.
//
// The devices page (plan 2026-11-19, Task 7, D8, End state 9). It lists each device that synced
// the learner's study record, read from `users/{uid}/devices` through `JpRemote.devices()`
// (jp_remote.dart): a plain device name and the last sync time, newest sync first. `JpSync`
// (jp_sync.dart) writes those documents at the end of each run.
//
// The page reads the server, never a cache. Offline it says so instead of showing an old list.
// Signed out or anonymous, nothing syncs, so it asks the learner to sign in.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '/auth/base_auth_user_provider.dart';
import '/flutter_flow/quiet_room.dart';
import '../quiet_room_grammar/jp_study_kit.dart';
import '../quiet_room_mastery/jp_remote.dart';
import '../quiet_room_mastery/jp_remote_firestore.dart';
import '../quiet_room_mastery/review_page.dart' show qrLoadingOr;

/// The page title, and the profile page's entry to it.
const String kDevicesTitle = 'Signed-in devices';

/// The list with no device in it.
const String kDevicesEmpty =
    'No device has synced yet. Your devices show here after their first sync.';

/// The remote could not be reached.
const String kDevicesOffline =
    'Could not reach the server. Connect to the internet to see your devices.';

/// Nobody is signed in, or the user is anonymous: nothing syncs.
const String kDevicesSignedOut =
    'Sign in to see the devices that sync your study record.';

/// The row's last sync line, in this device's local time. Pure.
String deviceLastSyncLabel(DateTime lastSyncUtc) =>
    'Last synced ${DateFormat('d MMM yyyy, HH:mm').format(lastSyncUtc.toLocal())}';

/// [devices] in list order: the newest sync first, a tie by device id. Pure.
List<JpDevice> devicesNewestFirst(Iterable<JpDevice> devices) =>
    devices.toList()
      ..sort((a, b) {
        final at = b.lastSyncUtc.compareTo(a.lastSyncUtc);
        return at != 0 ? at : a.deviceId.compareTo(b.deviceId);
      });

/// The remote of the signed-in, non-anonymous user; null when nobody is signed in.
JpRemote? signedInJpRemote() {
  final uid = currentUser?.uid;
  if (!loggedIn || uid == null || uid.isEmpty) return null;
  return JpRemoteFirestore(firestore: FirebaseFirestore.instance, uid: uid);
}

class DevicesPageWidget extends StatefulWidget {
  const DevicesPageWidget({super.key, this.remote});

  static String routeName = 'DevicesPage';
  static String routePath = '/devicesPage';

  /// Null uses the signed-in user's Firestore remote ([signedInJpRemote]).
  final JpRemote? remote;

  @override
  State<DevicesPageWidget> createState() => _DevicesPageWidgetState();
}

class _DevicesPageWidgetState extends State<DevicesPageWidget> {
  List<JpDevice>? _devices;
  Object? _error;
  bool _signedOut = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final remote = widget.remote ?? signedInJpRemote();
      if (remote == null) {
        if (mounted) setState(() => _signedOut = true);
        return;
      }
      final devices = devicesNewestFirst(await remote.devices());
      if (mounted) setState(() => _devices = devices);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = QuietRoomTokens.of(context);
    final devices = _devices;
    final error = _error;
    final String? message = _signedOut
        ? kDevicesSignedOut
        : error is JpRemoteUnavailable ||
                (error is FirebaseException && error.code == 'unavailable')
            ? kDevicesOffline
            : devices != null && devices.isEmpty
                ? kDevicesEmpty
                : null;
    if (devices == null && message == null) {
      return QrStudyScaffold(
          child: qrLoadingOr(context, error, 'Could not open the devices:'));
    }
    return QrStudyScaffold(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        children: [
          Text(kDevicesTitle, style: qrTitle(t, size: 28)),
          const SizedBox(height: 12),
          if (message != null)
            Text(message, style: qrText(t, size: 14, color: t.inkMuted)),
          for (final d in devices ?? const <JpDevice>[]) _row(t, d),
        ],
      ),
    );
  }

  Widget _row(QuietRoomTokens t, JpDevice d) => Padding(
        key: ValueKey('device-${d.deviceId}'),
        padding: const EdgeInsets.only(bottom: 10),
        child: QrCard(
          child: Row(children: [
            Icon(Icons.devices_outlined, size: 20, color: t.inkMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.name,
                        style: qrText(t,
                            size: 15.5,
                            weight: FontWeight.w600,
                            color: t.inkStrong)),
                    Text(deviceLastSyncLabel(d.lastSyncUtc),
                        style: qrText(t, size: 12.5, color: t.inkMuted)),
                  ]),
            ),
          ]),
        ),
      );
}
