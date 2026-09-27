// HAND-WRITTEN. Not FlutterFlow output, so S3 has nothing to adopt.
//
// The Quiet Room entry screens. These are a rebuild rather than a re-skin, and the
// reason is worth recording because it is not obvious:
//
// The generated login/signup pages paint EVERYTHING in `tertiary` -- field labels,
// borders, input text and the primary button fill -- against a `primary` ground. That
// two-tone scheme is self-consistent in both themes, which is exactly why no single
// token swap can fix it. In Nightfall `tertiary` resolves dark (#23303C), so the ground
// is forced light (#7FA8C6) for the scheme to hold, and you get a pale blue wall. Make
// the ground dark and the button disappears into it. The colours are not the bug; the
// role assignment is.
//
// So these screens follow the direction instead: the room is quiet (canvas ground,
// surface fields, hairline borders) and exactly one object is loud -- the primary
// action, carrying a brand fill at full strength. [§1]
//
// The auth flow is preserved verbatim from the generated page: validate, prepareAuthEvent,
// signInWithEmail, seed UserGroupSearchRecord when absent, then route on.

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/quiet_room.dart';
import '/components/pages/home_page/home_page_widget.dart';
import '/components/pages/signup_page/signup_page_widget.dart';
import '/components/pages/forgot_password/forgot_password_widget.dart';

/// 🚨 DEBUG ONLY. `kDebugMode` is a compile-time const, so Dart's tree shaker removes this
/// branch -- and these strings -- from any release build. Never reference it outside a
/// `if (kDebugMode)` guard, or the credentials ship.
///
/// This is a throwaway account on the live Firebase project, created for design review. It is
/// not a back door: it still performs a real sign-in, so nothing about the auth path is skipped
/// or faked, and a release build sees none of it.
const _devEmail = 'quietroomtest1@example.com';
const _devPassword = 'QuietRoom2026';

/// Shared chrome so login and the launch screen cannot drift apart.
class _Shell extends StatelessWidget {
  const _Shell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = QuietRoomTokens.of(context);
    return Scaffold(
      backgroundColor: t.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

Widget _mark(QuietRoomTokens t, {double size = 64}) => Column(
      children: [
        Image.asset('assets/images/Habit_Craft_Logo_File-09.png',
            width: size, height: size, fit: BoxFit.contain),
        const SizedBox(height: 10),
        Text(
          'HabitCrafts',
          style: GoogleFonts.fraunces(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 18 * -0.005,
            color: t.inkMuted,
          ),
        ),
      ],
    );

/// The one loud object. Brand fill at full strength, label from `onBrand` so it inverts
/// correctly: white on the Daylight blue, canvas-dark on the Nightfall tint.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton(
      {required this.label, required this.onPressed, this.busy = false});
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = QuietRoomTokens.of(context);
    return SizedBox(
      width: double.infinity,
      height: QuietRoomMetrics.targetMin,
      child: ElevatedButton(
        onPressed: busy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: t.brand600,
          disabledBackgroundColor: t.brand400,
          foregroundColor: t.onBrand,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(QuietRoomMetrics.radiusSm)),
        ),
        child: busy
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(t.onBrand)),
              )
            : Text(label,
                style: GoogleFonts.schibstedGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: t.onBrand)),
      ),
    );
  }
}

/// Quiet by construction: surface fill, hairline border, no shadow at rest. The border IS
/// the affordance, so it uses borderControl rather than the softer card hairline.
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    final t = QuietRoomTokens.of(context);
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
          borderSide: BorderSide(color: c, width: w),
          borderRadius: BorderRadius.circular(QuietRoomMetrics.radiusSm),
        );

    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: GoogleFonts.schibstedGrotesk(fontSize: 15, color: t.ink),
      cursorColor: t.brand600,
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            GoogleFonts.schibstedGrotesk(fontSize: 14, color: t.inkMuted),
        floatingLabelStyle:
            GoogleFonts.schibstedGrotesk(fontSize: 13, color: t.brand600),
        filled: true,
        fillColor: t.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
        enabledBorder: border(t.borderControl, QuietRoomMetrics.strokeControl),
        focusedBorder: border(t.borderFocus, QuietRoomMetrics.strokeFocus),
        errorBorder: border(t.clay600, QuietRoomMetrics.strokeControl),
        focusedErrorBorder: border(t.clay600, QuietRoomMetrics.strokeFocus),
        errorStyle:
            GoogleFonts.schibstedGrotesk(fontSize: 12.5, color: t.clay600),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class QuietRoomLaunchWidget extends StatelessWidget {
  const QuietRoomLaunchWidget({super.key});

  static String routeName = 'quietRoomLaunch';
  static String routePath = '/quietRoomLaunch';

  @override
  Widget build(BuildContext context) {
    final t = QuietRoomTokens.of(context);
    return _Shell(
      child: Column(
        children: [
          _mark(t, size: 88),
          const SizedBox(height: 28),
          Text(
            'Small things, kept.',
            textAlign: TextAlign.center,
            style: GoogleFonts.fraunces(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              letterSpacing: 26 * -0.015,
              height: 1.15,
              color: t.inkStrong,
            ),
          ),
          const SizedBox(height: 40),
          _PrimaryButton(
            label: 'Log in',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const QuietRoomLoginWidget()),
            ),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: QuietRoomMetrics.targetMin,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const QuietRoomLoginWidget(autoSubmit: true),
                )),
                icon: Icon(Icons.bolt_outlined, size: 18, color: t.amber700),
                label: Text('Dev sign-in',
                    style: GoogleFonts.schibstedGrotesk(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: t.amber700)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: t.amber700, width: 1),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(QuietRoomMetrics.radiusSm)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: QuietRoomMetrics.targetMin,
            child: OutlinedButton(
              onPressed: () => context.pushNamed(SignupPageWidget.routeName),
              style: OutlinedButton.styleFrom(
                foregroundColor: t.ink,
                side: BorderSide(
                    color: t.borderControl,
                    width: QuietRoomMetrics.strokeControl),
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(QuietRoomMetrics.radiusSm)),
              ),
              child: Text('Sign up',
                  style: GoogleFonts.schibstedGrotesk(
                      fontSize: 15, fontWeight: FontWeight.w600, color: t.ink)),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class QuietRoomLoginWidget extends StatefulWidget {
  const QuietRoomLoginWidget({super.key, this.autoSubmit = false});

  /// Debug only: sign in as soon as the screen mounts, so a design pass costs no typing.
  final bool autoSubmit;

  static String routeName = 'quietRoomLogin';
  static String routePath = '/quietRoomLogin';

  @override
  State<QuietRoomLoginWidget> createState() => _QuietRoomLoginWidgetState();
}

class _QuietRoomLoginWidgetState extends State<QuietRoomLoginWidget> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      _email.text = _devEmail;
      _password.text = _devPassword;
      if (widget.autoSubmit) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _submit());
      }
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      GoRouter.of(context).prepareAuthEvent();
      final user = await authManager.signInWithEmail(
        context,
        _email.text.trim(),
        _password.text,
      );
      // authManager surfaces its own message on failure and returns null. Returning
      // here rather than throwing keeps that single reporting path.
      if (user == null) return;

      FFAppState().showOnboard = true;

      // Preserved from the generated page: the search index row is created on first
      // sign-in when it is missing, otherwise the user is invisible to group search.
      final count = await queryUserGroupSearchRecordCount(
        queryBuilder: (r) => r.where('user', isEqualTo: currentUserReference),
      );
      if (count <= 0) {
        await UserGroupSearchRecord.collection.doc().set(
              createUserGroupSearchRecordData(
                searchTerm: currentUserDisplayName,
                user: currentUserReference,
              ),
            );
      }

      if (mounted) {
        // The nav swap points the existing `homePage` ROUTE at QuietRoomTodayWidget;
        // there is no separate 'quietRoomToday' route name to go to. Naming one that
        // is not registered makes GoRouter throw and the button look inert.
        context.goNamed(HomePageWidget.routeName);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = QuietRoomTokens.of(context);
    return _Shell(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _mark(t),
            const SizedBox(height: 26),
            Text(
              'Welcome back',
              textAlign: TextAlign.center,
              style: GoogleFonts.fraunces(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                letterSpacing: 26 * -0.015,
                height: 1.15,
                color: t.inkStrong,
              ),
            ),
            const SizedBox(height: 26),
            _Field(
              controller: _email,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return 'Enter your email address.';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) {
                  return 'That does not look like an email address.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _Field(
              controller: _password,
              label: 'Password',
              obscure: true,
              textInputAction: TextInputAction.done,
              validator: (v) =>
                  (v ?? '').isEmpty ? 'Enter your password.' : null,
            ),
            const SizedBox(height: 20),
            _PrimaryButton(label: 'Log in', busy: _busy, onPressed: _submit),
            const SizedBox(height: 14),
            Center(
              child: TextButton(
                onPressed: () =>
                    context.pushNamed(ForgotPasswordWidget.routeName),
                child: Text('Forgot your password?',
                    style: GoogleFonts.schibstedGrotesk(
                        fontSize: 13.5, color: t.brand600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
