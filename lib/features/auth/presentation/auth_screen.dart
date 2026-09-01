import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../application/auth_actions.dart';
import '../data/auth_repository.dart';
import 'widgets/google_web_sign_in_button.dart';
import '../../../core/constants/app_icons.dart';

enum _AuthMode { signIn, signUp }

// The router redirects to /dashboard automatically once FirebaseAuth reports
// a signed-in user (see app/router/app_router.dart), so this screen only
// needs to trigger sign-in/sign-up and surface errors — no manual navigation.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  _AuthMode _mode = _AuthMode.signIn;
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  bool _isGoogleSubmitting = false;
  String? _errorMessage;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _googleAuthSub;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      // Web has no imperative authenticate() call (see auth_repository.dart)
      // — Google's own rendered button (below) drives sign-in, and the
      // result arrives here instead of as a return value.
      _googleAuthSub = GoogleSignIn.instance.authenticationEvents.listen(
        _handleGoogleAuthEvent,
        onError: (Object e) => setState(
          () => _errorMessage = 'Google sign-in failed. Please try again.',
        ),
      );
    }
  }

  @override
  void dispose() {
    _googleAuthSub?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleAuthEvent(
    GoogleSignInAuthenticationEvent event,
  ) async {
    if (event is! GoogleSignInAuthenticationEventSignIn) return;
    setState(() {
      _isGoogleSubmitting = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authActionsProvider).signInWithGoogle(account: event.user);
      // On success, authStateChangesProvider fires and the router redirects.
    } on AuthException catch (e) {
      // `mounted` is checked here too: on the success path the router
      // redirects and disposes this screen while _bootstrapProfileIfNeeded
      // may still be awaiting Firestore, so a late failure would otherwise
      // call setState on a dead State.
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (e) {
      // Bootstrap failures (profile/subscription doc writes, Firestore
      // rules rejections, ...) land here rather than as AuthException —
      // logged so they're diagnosable from the browser/device console
      // instead of just showing the same generic message for every cause.
      debugPrint('Google sign-in bootstrap failed: $e');
      if (mounted)
        setState(
          () => _errorMessage = 'Google sign-in failed. Please try again.',
        );
    } finally {
      if (mounted) setState(() => _isGoogleSubmitting = false);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      final actions = ref.read(authActionsProvider);
      if (_mode == _AuthMode.signUp) {
        await actions.signUp(email: email, password: password);
      } else {
        await actions.signIn(email: email, password: password);
      }
      // On success, authStateChangesProvider fires and the router redirects.
    } on AuthException catch (e) {
      // `mounted` is checked here too: on the success path the router
      // redirects and disposes this screen while _bootstrapProfileIfNeeded
      // may still be awaiting Firestore, so a late failure would otherwise
      // call setState on a dead State.
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (e) {
      debugPrint('Email auth bootstrap failed: $e');
      if (mounted)
        setState(
          () => _errorMessage = 'Something went wrong. Please try again.',
        );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _continueWithGoogle() async {
    setState(() {
      _isGoogleSubmitting = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authActionsProvider).signInWithGoogle();
      // On success, authStateChangesProvider fires and the router redirects.
    } on AuthException catch (e) {
      // `mounted` is checked here too: on the success path the router
      // redirects and disposes this screen while _bootstrapProfileIfNeeded
      // may still be awaiting Firestore, so a late failure would otherwise
      // call setState on a dead State.
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (e) {
      debugPrint('Google sign-in bootstrap failed: $e');
      if (mounted)
        setState(
          () => _errorMessage = 'Google sign-in failed. Please try again.',
        );
    } finally {
      if (mounted) setState(() => _isGoogleSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSignUp = _mode == _AuthMode.signUp;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isSignUp ? 'Create your account' : 'Welcome back',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'Sign in to keep your progress in sync.',
                      style: TextStyle(color: AppColors.subtleText),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (_errorMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusMd,
                          ),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.isEmpty) return 'Enter your email';
                        if (!v.contains('@') || !v.contains('.'))
                          return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      autofillHints: [
                        isSignUp
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? AppIcons.eye
                                : AppIcons.eyeSlash,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      validator: (value) {
                        final v = value ?? '';
                        if (v.isEmpty) return 'Enter your password';
                        if (isSignUp && v.length < 6)
                          return 'Use at least 6 characters';
                        return null;
                      },
                      onFieldSubmitted: (_) => _isSubmitting ? null : _submit(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: _isSubmitting
                          ? 'Please wait...'
                          : (isSignUp ? 'Create account' : 'Continue'),
                      expand: true,
                      onPressed: _isSubmitting ? null : _submit,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Center(
                      child: TextButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => setState(() {
                                _mode = isSignUp
                                    ? _AuthMode.signIn
                                    : _AuthMode.signUp;
                                _errorMessage = null;
                              }),
                        child: Text(
                          isSignUp
                              ? 'Already have an account? Sign in'
                              : "Don't have an account? Create one",
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: const [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                          ),
                          child: Text(
                            'or',
                            style: TextStyle(color: AppColors.subtleText),
                          ),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (kIsWeb)
                      // Google Identity Services requires its own rendered
                      // button on web (GoogleSignIn.authenticate() throws
                      // there) — see google_web_sign_in_button.dart.
                      SizedBox(
                        height: 44,
                        width: double.infinity,
                        child: _isGoogleSubmitting
                            ? const Center(child: CircularProgressIndicator())
                            : renderGoogleWebButton(),
                      )
                    else
                      AppButton(
                        label: _isGoogleSubmitting
                            ? 'Please wait...'
                            : 'Continue with Google',
                        variant: AppButtonVariant.secondary,
                        icon: AppIcons.googleLogo,
                        expand: true,
                        onPressed: (_isSubmitting || _isGoogleSubmitting)
                            ? null
                            : _continueWithGoogle,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
