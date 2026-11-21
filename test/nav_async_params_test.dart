// A route whose document is named in the URL loads that document once per page (plan
// 2026-11-19, Task 14 carried defect, operator ruling 2026-11-21). go_router calls every
// page's pageBuilder again on each rebuild, so a push or a pop over a reload-opened
// URL-document route re-runs it. The route underneath must keep its loaded document and
// its state, with no second load and no placeholder in between.
//
// The routes here are built by the app's own `FFRoute.toRoute`, so the test runs the real
// pageBuilder. Firebase core and Messaging are faked at the platform interface because
// `PushNotificationsHandler` wraps every page.
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:firebase_messaging_platform_interface/firebase_messaging_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:habit_craft/auth/base_auth_user_provider.dart';
import 'package:habit_craft/flutter_flow/nav/nav.dart';

class _FakeApp extends FirebaseAppPlatform {
  _FakeApp(String name)
      : super(
            name,
            const FirebaseOptions(
                apiKey: 'key',
                appId: '1:1:web:1',
                messagingSenderId: '1',
                projectId: 'nav-project'));
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

class _FakeMessaging extends FirebaseMessagingPlatform
    with MockPlatformInterfaceMixin {
  @override
  FirebaseMessagingPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseMessagingPlatform setInitialValues({bool? isAutoInitEnabled}) => this;

  @override
  bool get isAutoInitEnabled => false;

  @override
  Future<RemoteMessage?> getInitialMessage() async => null;
}

class _FakeUser extends BaseAuthUser {
  @override
  bool get loggedIn => true;
  @override
  bool get emailVerified => true;
  @override
  AuthUserInfo get authUserInfo => const AuthUserInfo(uid: 'nav-user');
  @override
  Future? delete() => null;
  @override
  Future? updateEmail(String email) => null;
  @override
  Future? updatePassword(String newPassword) => null;
  @override
  Future? sendEmailVerification() => null;
}

/// A screen with state of its own: a tap count that a fresh build would reset.
class _DocScreen extends StatefulWidget {
  const _DocScreen({required this.doc});
  final String? doc;

  @override
  State<_DocScreen> createState() => _DocScreenState();
}

class _DocScreenState extends State<_DocScreen> {
  var _taps = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(children: [
          Text('doc: ${widget.doc}'),
          Text('taps: $_taps'),
          TextButton(
              onPressed: () => setState(() => _taps++),
              child: const Text('tap')),
        ]),
      );
}

void main() {
  setUpAll(() async {
    FirebasePlatform.instance = _FakeCore();
    await Firebase.initializeApp();
    FirebaseMessagingPlatform.instance = _FakeMessaging();
    AppStateNotifier.instance
      ..update(_FakeUser())
      ..stopShowingSplashImage();
  });

  testWidgets(
      'a URL-document route keeps its document and state when a screen is pushed over it',
      (tester) async {
    var loads = 0;
    final appState = AppStateNotifier.instance;
    final router = GoRouter(
      initialLocation: '/docPage?doc=abc',
      routes: [
        FFRoute(
          name: 'docPage',
          path: '/docPage',
          asyncParams: {
            'doc': (id) async {
              loads++;
              return 'loaded:$id';
            },
          },
          builder: (context, params) =>
              _DocScreen(doc: params.getParam('doc', ParamType.String)),
        ).toRoute(appState),
        FFRoute(
          name: 'topPage',
          path: '/topPage',
          builder: (context, params) =>
              const Scaffold(body: Text('top screen')),
        ).toRoute(appState),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('doc: loaded:abc'), findsOneWidget);
    expect(loads, 1);

    await tester.tap(find.text('tap'));
    await tester.pump();
    expect(find.text('taps: 1'), findsOneWidget);

    router.push('/topPage');
    await tester.pumpAndSettle();
    expect(find.text('top screen'), findsOneWidget);
    expect(find.text('taps: 1', skipOffstage: false), findsOneWidget,
        reason: 'the route underneath keeps its state while covered');

    router.pop();
    await tester.pump();
    expect(find.text('taps: 1'), findsOneWidget,
        reason: 'no placeholder replaces the route after the pop');
    await tester.pumpAndSettle();
    expect(find.text('doc: loaded:abc'), findsOneWidget);
    expect(find.text('taps: 1'), findsOneWidget,
        reason: 'the route underneath keeps its state after the pop');
    expect(loads, 1, reason: 'the document loads once per page');

    router.go('/docPage?doc=xyz');
    await tester.pumpAndSettle();
    expect(find.text('doc: loaded:xyz'), findsOneWidget,
        reason: 'a new document id in the URL loads the new document');
    expect(loads, 2);
  });
}
