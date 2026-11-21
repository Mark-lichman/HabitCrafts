// The whole app opens every route in Chrome with no uncaught error (plan 2026-11-19,
// Task 14, End state 6, PIN-5, PIN-15, A9). Run it with `--platform chrome`; the VM run of
// `flutter test` skips this file.
//
// Firebase is faked at the platform interface, so the real app code runs unchanged: core,
// Auth (a signed-in user), Firestore (an empty project plus the documents a route's URL
// names), Analytics, Messaging and Functions. The routes come from the app's own router, so
// a route added to `nav.dart` is opened here without editing this file.
//
// The same file proves the two web guards of Task 14: the contacts fetch returns nothing on
// the web, and the Notifications row asks the browser for permission.
@TestOn('browser')
library;

import 'dart:async';

import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
import 'package:cloud_functions_platform_interface/cloud_functions_platform_interface.dart';
import 'package:firebase_analytics_platform_interface/firebase_analytics_platform_interface.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:firebase_messaging_platform_interface/firebase_messaging_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:habit_craft/app_state.dart';
import 'package:habit_craft/backend/push_notifications/push_notifications_handler.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_memory.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_sqlite.dart'
    show debugSetSharedJpStore;
import 'package:habit_craft/custom_code/actions/index.dart' as actions;
import 'package:habit_craft/flutter_flow/nav/nav.dart';
import 'package:habit_craft/index.dart'
    show
        Chat2DetailsWidget,
        Chat2InviteUsersWidget,
        ImageDetailsWidget,
        LibraryDetailPageWidget;
import 'package:habit_craft/main.dart';

const _uid = 'smoke-user';

// ---------------------------------------------------------------------------------------------
// Core

class _FakeApp extends FirebaseAppPlatform {
  _FakeApp(String name)
      : super(
            name,
            const FirebaseOptions(
                apiKey: 'key',
                appId: '1:1:web:1',
                messagingSenderId: '1',
                projectId: 'smoke-project'));
}

class _FakeCore extends FirebasePlatform with MockPlatformInterfaceMixin {
  final _apps = <String, FirebaseAppPlatform>{};

  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) =>
      _apps.putIfAbsent(name, () => _FakeApp(name));

  @override
  List<FirebaseAppPlatform> get apps => _apps.values.toList();

  @override
  Future<FirebaseAppPlatform> initializeApp(
          {String? name, FirebaseOptions? options}) async =>
      app(name ?? defaultFirebaseAppName);
}

// ---------------------------------------------------------------------------------------------
// Auth: one signed-in, email-verified user.

class _FakeMultiFactor extends MultiFactorPlatform {
  _FakeMultiFactor(super.auth);
}

class _FakeUser extends UserPlatform {
  _FakeUser(FirebaseAuthPlatform auth)
      : super(
            auth,
            _FakeMultiFactor(auth),
            PigeonUserDetails(
                userInfo: PigeonUserInfo(
                    uid: _uid,
                    email: 'smoke@example.com',
                    displayName: 'Smoke',
                    isAnonymous: false,
                    isEmailVerified: true,
                    creationTimestamp: 0,
                    lastSignInTimestamp: 0),
                providerData: const []));

  @override
  Future<String?> getIdToken(bool forceRefresh) async => 'token';

  @override
  Future<void> reload() async {}
}

class _FakeAuth extends FirebaseAuthPlatform with MockPlatformInterfaceMixin {
  _FakeAuth() {
    user = _FakeUser(this);
  }

  UserPlatform? user;

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues(
          {PigeonUserDetails? currentUser, String? languageCode}) =>
      this;

  @override
  UserPlatform? get currentUser => user;

  @override
  set currentUser(UserPlatform? userPlatform) => user = userPlatform;

  @override
  Stream<UserPlatform?> authStateChanges() => Stream.value(user);

  @override
  Stream<UserPlatform?> idTokenChanges() => Stream.value(user);

  @override
  Stream<UserPlatform?> userChanges() => Stream.value(user);

  @override
  Future<void> setPersistence(Persistence persistence) async {}

  @override
  Future<void> signOut() async {}
}

// ---------------------------------------------------------------------------------------------
// Firestore: every query is empty, as a brand-new account on the web sees it. Every document
// exists. The ones the URL of a route names carry the fields the app always writes to them;
// any other document has no fields.

final _metadata = SnapshotMetadataPlatform(false, false);

/// A one-pixel PNG, so the image screen draws a picture without a network fetch.
const _pixel = 'data:image/png;base64,'
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

String _normal(String path) => path.startsWith('/') ? path.substring(1) : path;

/// The documents named in [_routeQueries], by path.
Map<String, Map<String, dynamic>> _seed(FirebaseFirestorePlatform firestore) {
  DocumentReferencePlatform ref(String path) => _FakeDoc(firestore, path);
  final now = Timestamp.fromDate(DateTime(2026, 11, 21, 9));
  return {
    'users/$_uid': {
      'uid': _uid,
      'email': 'smoke@example.com',
      'display_name': 'Smoke',
      'photo_url': _pixel,
    },
    'users/friend': {
      'uid': 'friend',
      'email': 'friend@example.com',
      'display_name': 'Friend',
      'photo_url': _pixel,
    },
    'chats/chat1': {
      'users': [ref('users/$_uid'), ref('users/friend')],
      'user_a': ref('users/$_uid'),
      'user_b': ref('users/friend'),
      'group': ref('groups/group1'),
      'last_message': 'See you tomorrow',
      'last_message_time': now,
      'last_message_sent_by': ref('users/friend'),
    },
    'groups/group1': {
      'name': 'Morning walkers',
      'chat': ref('chats/chat1'),
      'creator': ref('users/$_uid'),
    },
    'chat_messages/message1': {
      'user': ref('users/friend'),
      'chat': ref('chats/chat1'),
      'text': 'A photo from the walk',
      'image': _pixel,
      'timestamp': now,
    },
    'articles/article1': {'title': 'Start small'},
  };
}

class _FakeFirestore extends FirebaseFirestorePlatform
    with MockPlatformInterfaceMixin {
  _FakeFirestore({super.appInstance});

  @override
  FirebaseFirestorePlatform delegateFor(
          {required FirebaseApp app, required String databaseId}) =>
      _FakeFirestore(appInstance: app);

  @override
  CollectionReferencePlatform collection(String collectionPath) =>
      _FakeCollection(this, collectionPath);

  @override
  QueryPlatform collectionGroup(String collectionPath) =>
      _FakeCollection(this, collectionPath);

  @override
  DocumentReferencePlatform doc(String documentPath) =>
      _FakeDoc(this, documentPath);

  @override
  WriteBatchPlatform batch() => _FakeBatch();

  @override
  Settings get settings => const Settings();

  @override
  set settings(Settings settings) {}

  @override
  Future<void> enablePersistence([PersistenceSettings? settings]) async {}

  @override
  Future<void> clearPersistence() async {}

  @override
  Future<void> enableNetwork() async {}

  @override
  Future<void> disableNetwork() async {}

  @override
  Future<void> waitForPendingWrites() async {}

  @override
  Future<void> terminate() async {}
}

QuerySnapshotPlatform _emptyQuery() =>
    QuerySnapshotPlatform(const [], const [], _metadata);

var _nextDocId = 0;

/// The modifiers of a query with none applied. `cloud_firestore` reads them before it adds
/// one, and a real collection starts from these.
final _noModifiers = Map<String, dynamic>.unmodifiable({
  'where': const <List<dynamic>>[],
  'orderBy': const <List<dynamic>>[],
  'startAt': null,
  'startAfter': null,
  'endAt': null,
  'endBefore': null,
  'limit': null,
  'limitToLast': null,
});

/// A collection, and every query on it: a modifier returns the same empty result.
class _FakeCollection extends CollectionReferencePlatform
    with MockPlatformInterfaceMixin {
  _FakeCollection(super.firestore, super.path);

  @override
  Map<String, dynamic> get parameters => _noModifiers;

  @override
  bool get isCollectionGroupQuery => false;

  @override
  DocumentReferencePlatform doc([String? path]) =>
      _FakeDoc(firestore, '${this.path}/${path ?? 'auto${_nextDocId++}'}');

  @override
  QueryPlatform where(List<List<dynamic>> conditions) => this;

  @override
  QueryPlatform whereFilter(FilterPlatformInterface filter) => this;

  @override
  QueryPlatform orderBy(Iterable<List<dynamic>> orders) => this;

  @override
  QueryPlatform limit(int limit) => this;

  @override
  QueryPlatform limitToLast(int limit) => this;

  @override
  QueryPlatform startAfter(Iterable<dynamic> fields) => this;

  @override
  QueryPlatform startAfterDocument(
          List<dynamic> orders, List<dynamic> values) =>
      this;

  @override
  QueryPlatform startAt(Iterable<dynamic> fields) => this;

  @override
  QueryPlatform startAtDocument(
          Iterable<dynamic> orders, Iterable<dynamic> values) =>
      this;

  @override
  QueryPlatform endAt(Iterable<dynamic> fields) => this;

  @override
  QueryPlatform endAtDocument(List<dynamic> orders, List<dynamic> values) =>
      this;

  @override
  QueryPlatform endBefore(Iterable<dynamic> fields) => this;

  @override
  QueryPlatform endBeforeDocument(
          Iterable<dynamic> orders, Iterable<dynamic> values) =>
      this;

  @override
  AggregateQueryPlatform count() => _FakeCount(this);

  @override
  Future<QuerySnapshotPlatform> get(
          [GetOptions options = const GetOptions()]) async =>
      _emptyQuery();

  @override
  Stream<QuerySnapshotPlatform> snapshots(
          {bool includeMetadataChanges = false,
          required ListenSource listenSource}) =>
      Stream.value(_emptyQuery());
}

class _FakeCount extends AggregateQueryPlatform
    with MockPlatformInterfaceMixin {
  _FakeCount(super.query);

  @override
  Future<AggregateQuerySnapshotPlatform> get(
          {required AggregateSource source}) async =>
      AggregateQuerySnapshotPlatform(
          count: 0, sum: const [], average: const []);
}

class _FakeDoc extends DocumentReferencePlatform
    with MockPlatformInterfaceMixin {
  _FakeDoc(super.firestore, super.path);

  DocumentSnapshotPlatform _snapshot() => DocumentSnapshotPlatform(
      firestore,
      path,
      _seed(firestore)[_normal(path)] ?? <String, dynamic>{},
      PigeonSnapshotMetadata(hasPendingWrites: false, isFromCache: false));

  @override
  CollectionReferencePlatform collection(String collectionPath) =>
      _FakeCollection(firestore, '$path/$collectionPath');

  @override
  Future<DocumentSnapshotPlatform> get(
          [GetOptions options = const GetOptions()]) async =>
      _snapshot();

  @override
  Stream<DocumentSnapshotPlatform> snapshots(
          {bool includeMetadataChanges = false,
          required ListenSource listenSource}) =>
      Stream.value(_snapshot());

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {}

  @override
  Future<void> update(Map<FieldPath, dynamic> data) async {}

  @override
  Future<void> delete() async {}
}

class _FakeBatch extends WriteBatchPlatform with MockPlatformInterfaceMixin {
  @override
  Future<void> commit() async {}

  @override
  void delete(String document) {}

  @override
  void set(String document, Map<String, dynamic> data, [SetOptions? options]) {}

  @override
  void update(String document, Map<String, dynamic> data) {}
}

// ---------------------------------------------------------------------------------------------
// Analytics, Messaging and Functions

class _FakeAnalytics extends FirebaseAnalyticsPlatform
    with MockPlatformInterfaceMixin {
  @override
  FirebaseAnalyticsPlatform delegateFor(
          {required FirebaseApp app, Map<String, dynamic>? webOptions}) =>
      this;

  @override
  Future<void> logEvent(
      {required String name,
      Map<String, Object?>? parameters,
      AnalyticsCallOptions? callOptions}) async {}

  @override
  Future<void> setUserId(
      {String? id, AnalyticsCallOptions? callOptions}) async {}

  @override
  Future<void> setCurrentScreen(
      {String? screenName,
      String? screenClassOverride,
      AnalyticsCallOptions? callOptions}) async {}
}

const _granted = NotificationSettings(
  alert: AppleNotificationSetting.enabled,
  announcement: AppleNotificationSetting.notSupported,
  authorizationStatus: AuthorizationStatus.authorized,
  badge: AppleNotificationSetting.enabled,
  carPlay: AppleNotificationSetting.notSupported,
  lockScreen: AppleNotificationSetting.enabled,
  notificationCenter: AppleNotificationSetting.enabled,
  showPreviews: AppleShowPreviewSetting.always,
  timeSensitive: AppleNotificationSetting.notSupported,
  criticalAlert: AppleNotificationSetting.notSupported,
  sound: AppleNotificationSetting.enabled,
  providesAppNotificationSettings: AppleNotificationSetting.notSupported,
);

class _FakeMessaging extends FirebaseMessagingPlatform
    with MockPlatformInterfaceMixin {
  /// How many times the app asked for notification permission.
  var permissionRequests = 0;

  @override
  FirebaseMessagingPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseMessagingPlatform setInitialValues({bool? isAutoInitEnabled}) => this;

  @override
  bool get isAutoInitEnabled => false;

  @override
  Future<RemoteMessage?> getInitialMessage() async => null;

  @override
  Future<NotificationSettings> requestPermission(
      {bool alert = true,
      bool announcement = false,
      bool badge = true,
      bool carPlay = false,
      bool criticalAlert = false,
      bool provisional = false,
      bool sound = true,
      bool providesAppNotificationSettings = false}) async {
    permissionRequests++;
    return _granted;
  }

  @override
  Future<NotificationSettings> getNotificationSettings() async => _granted;

  @override
  Future<String?> getToken({String? vapidKey}) async => 'web-token';

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();

  /// Whether this browser has the Notification API. A test that clears it restores it.
  var supported = true;

  @override
  Future<bool> isSupported() async => supported;
}

class _FakeCallable extends HttpsCallablePlatform {
  _FakeCallable(FirebaseFunctionsPlatform functions, String name)
      : super(functions, null, name, HttpsCallableOptions(), null);

  @override
  Future<dynamic> call([dynamic parameters]) async => <String, dynamic>{};
}

class _FakeFunctions extends FirebaseFunctionsPlatform
    with MockPlatformInterfaceMixin {
  _FakeFunctions() : super(null, 'us-central1');

  @override
  FirebaseFunctionsPlatform delegateFor(
          {FirebaseApp? app, required String region}) =>
      this;

  @override
  HttpsCallablePlatform httpsCallable(
          String? origin, String name, HttpsCallableOptions options) =>
      _FakeCallable(this, name);
}

late _FakeMessaging _messaging;

Future<void> _fakeFirebase() async {
  FirebasePlatform.instance = _FakeCore();
  FirebaseAuthPlatform.instance = _FakeAuth();
  FirebaseFirestorePlatform.instance = _FakeFirestore();
  FirebaseAnalyticsPlatform.instance = _FakeAnalytics();
  FirebaseMessagingPlatform.instance = _messaging = _FakeMessaging();
  FirebaseFunctionsPlatform.instance = _FakeFunctions();
  await Firebase.initializeApp();
}

/// Every path the app's router registers, read from the router itself.
List<String> _routerPaths() {
  final router = createRouter(AppStateNotifier.instance);
  final paths = router.configuration.routes
      .whereType<GoRoute>()
      .map((r) => r.path)
      .toList();
  router.dispose();
  return paths;
}

/// The query each route needs, as the app writes it into the URL. A screen about one chat,
/// article or message has nothing to show without it, and the app never opens it bare. On
/// the web the URL is all a reload keeps, so these go through the address, not `extra`.
const _routeQueries = <String, Map<String, String>>{
  '/libraryDetailPage': {'articleRef': 'article1'},
  '/chat2Details': {'chatRef': 'chat1', 'group': 'group1'},
  '/chat2InviteUsers': {'chatRef': 'chat1'},
  '/imageDetails': {'chatMessage': 'message1'},
};

/// The screen each route in [_routeQueries] builds, keyed by the screen's own route path.
/// Some of these routes wait for their URL document behind a blank placeholder inside
/// [PushNotificationsHandler], so the handler alone does not prove the screen was built.
final _routeScreens = <String, Type>{
  LibraryDetailPageWidget.routePath: LibraryDetailPageWidget,
  Chat2DetailsWidget.routePath: Chat2DetailsWidget,
  Chat2InviteUsersWidget.routePath: Chat2InviteUsersWidget,
  ImageDetailsWidget.routePath: ImageDetailsWidget,
};

/// A layout overflow is a debug paint warning, not a thrown error, and the test font draws
/// every glyph as a wide box, so text that fits in a real browser overflows here. Every
/// other report fails the test.
bool _isOverflowWarning(FlutterErrorDetails details) =>
    details.exceptionAsString().startsWith('A RenderFlex overflowed');

/// Opens the whole app, waits out the launch splash, then goes to [path].
Future<void> _openRoute(WidgetTester tester, String path) async {
  final reportError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (!_isOverflowWarning(details)) reportError!(details);
  };
  addTearDown(() => FlutterError.onError = reportError);
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  debugSetSharedJpStore(JpStoreMemory());
  addTearDown(() => debugSetSharedJpStore(null));

  final appState = FFAppState();
  await tester.runAsync(appState.initializePersistedState);

  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: appState,
    child: MyApp(),
  ));
  await tester.pump(const Duration(milliseconds: 1100));
  expect(AppStateNotifier.instance.loading, isFalse,
      reason: 'the launch splash never ended, so no route screen was built');

  final query = _routeQueries[path];
  final location =
      Uri(path: path, queryParameters: query?.isEmpty ?? true ? null : query);
  GoRouter.of(appNavigatorKey.currentContext!).go(location.toString());
  // Real time passes too, because the browser decodes images and answers storage outside
  // the test's fake clock.
  for (var i = 0; i < 5; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 400));
  }

  final router = GoRouter.of(appNavigatorKey.currentContext!);
  expect(router.routerDelegate.currentConfiguration.uri.path, path,
      reason: '$path did not stay open');
  // The notifier is shared by every test, so its flag can stay clear from an earlier test.
  // The widget tree is this test's own proof: the route page wraps its screen in this
  // handler, and the splash logo replaces both.
  expect(find.byType(PushNotificationsHandler), findsWidgets,
      reason: '$path showed the launch splash, not its screen');
  final screen = _routeScreens[path];
  if (screen != null) {
    expect(find.byType(screen), findsOneWidget,
        reason: '$path showed its loading placeholder, not $screen');
  }

  // Unmount the app so no screen's timer outlives the test.
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_fakeFirebase);

  group('web guards', () {
    test('the contacts fetch returns no one on the web', () async {
      expect(await actions.fetchContactsAction(const []), isEmpty);
    });

    test('the Notifications row asks the browser for permission', () async {
      final before = _messaging.permissionRequests;
      await actions.openNotificationSettings();
      expect(_messaging.permissionRequests, before + 1);
    });

    test(
        'the Notifications row asks nothing of a browser with no Notification API',
        () async {
      _messaging.supported = false;
      addTearDown(() => _messaging.supported = true);
      final before = _messaging.permissionRequests;
      await actions.openNotificationSettings();
      expect(_messaging.permissionRequests, before);
    });
  });

  group('every route opens', () {
    final paths = _routerPaths();

    test('the router registers the app routes', () {
      expect(paths.length, greaterThanOrEqualTo(36));
      expect(paths.toSet().length, paths.length,
          reason: 'a path is registered twice');
    });

    test('every route with a URL query names the screen it builds', () {
      expect(_routeScreens.keys.toSet(), _routeQueries.keys.toSet());
      for (final path in _routeQueries.keys) {
        expect(paths, contains(path), reason: '$path is not a router path');
      }
    });

    for (final path in paths) {
      testWidgets(path, (tester) => _openRoute(tester, path));
    }
  });
}
