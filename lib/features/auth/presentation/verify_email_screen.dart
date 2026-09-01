import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../application/auth_actions.dart';
import '../application/auth_providers.dart';
import '../data/auth_repository.dart';
import '../../../core/constants/app_icons.dart';

/// Shown to a signed-in email/password user until they click the link from
/// their verification email — the router redirects here based on
/// `User.emailVerified` (see app_router.dart). Google accounts skip this
/// entirely since Google already verifies the email.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _isChecking = false;
  bool _isResending = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    // Covers verifying in a different tab (or on another device) and then
    // coming back to/reopening this one — the cached User here has no way
    // to know that happened without an explicit check. Silent: this isn't
    // the user asking, so don't scold them with "not verified yet" if it's
    // still pending.
    _checkVerified(silent: true);
  }

  Future<void> _checkVerified({bool silent = false}) async {
    setState(() {
      _isChecking = true;
      _message = null;
    });
    final verified = await ref.read(authActionsProvider).checkEmailVerified();
    if (!mounted) return;
    setState(() {
      _isChecking = false;
      if (!verified && !silent) {
        _message = "Still not verified — click the link in the email first, then try again.";
      }
      // If verified, authStateChangesProvider was refreshed and the
      // router's redirect takes it from here.
    });
  }

  Future<void> _resend() async {
    setState(() {
      _isResending = true;
      _message = null;
    });
    try {
      await ref.read(authActionsProvider).resendVerificationEmail();
      if (mounted) setState(() => _message = 'Verification email sent.');
    } on AuthException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email =
        ref.watch(authStateChangesProvider).valueOrNull?.email ?? 'your email';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    AppIcons.envelopeSimple,
                    size: 48,
                    color: AppColors.deepGreen,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Verify your email',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    "We sent a verification link to $email. Click it, then come back and tap "
                    "\"I've verified\" below.",
                    style: const TextStyle(color: AppColors.subtleText),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.deepGreen.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                        border: Border.all(
                          color: AppColors.deepGreen.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _message!,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: _isChecking ? 'Checking...' : "I've verified",
                    expand: true,
                    onPressed: _isChecking ? null : _checkVerified,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: _isResending ? 'Sending...' : 'Resend email',
                    variant: AppButtonVariant.secondary,
                    expand: true,
                    onPressed: _isResending ? null : _resend,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Center(
                    child: TextButton(
                      onPressed: () => ref.read(authActionsProvider).signOut(),
                      child: const Text('Sign out'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
