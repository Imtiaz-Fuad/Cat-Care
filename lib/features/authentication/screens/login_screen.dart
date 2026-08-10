import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_failure.dart';
import '../../../routes/app_routes.dart';
import '../providers/auth_provider.dart';

/// Email + Google + Guest sign-in screen.
///
/// State machine:
///   * [AuthMode.signIn]   — submit calls `signInWithEmail`.
///   * [AuthMode.signUp]   — submit calls `signUpWithEmail`.
///
/// The error banner lives at the top of the form. The submit button
/// stays enabled while busy so the spinner communicates state, but
/// tapping it again is a no-op until the in-flight call returns.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum AuthMode { signIn, signUp }

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  AuthMode _mode = AuthMode.signIn;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final AuthProvider auth = context.read<AuthProvider>();
    await (_mode == AuthMode.signIn
        ? auth.signInWithEmail(
            email: _email.text.trim(),
            password: _password.text,
          )
        : auth.signUpWithEmail(
            email: _email.text.trim(),
            password: _password.text,
          ));
    if (!mounted) return;
    if (auth.lastError == null) {
      context.go(AppRoutes.home);
    }
  }

  Future<void> _signInWithGoogle() async {
    final AuthProvider auth = context.read<AuthProvider>();
    await auth.signInWithGoogle();
    if (!mounted) return;
    if (auth.lastError == null) {
      context.go(AppRoutes.home);
    }
  }

  Future<void> _signInAsGuest() async {
    final AuthProvider auth = context.read<AuthProvider>();
    await auth.signInAsGuest();
    if (!mounted) return;
    if (auth.lastError == null) {
      context.go(AppRoutes.home);
    }
  }

  Future<void> _resetPassword() async {
    final String value = _email.text.trim();
    final AuthProvider auth = context.read<AuthProvider>();
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email first.')),
      );
      return;
    }
    await auth.sendPasswordReset(email: value);
    if (!mounted) return;
    final AppFailure? err = auth.lastError;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          err == null
              ? 'Password-reset email sent to $value.'
              : 'Couldn\'t send reset email: ${err.message}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Consumer<AuthProvider>(
      builder: (BuildContext context, AuthProvider auth, _) {
        final bool busy = auth.isBusy;
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Icon(Icons.pets, size: 64, color: scheme.primary),
                        const SizedBox(height: 12),
                        Text(
                          AppConstants.appName,
                          textAlign: TextAlign.center,
                          style: text.headlineMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _mode == AuthMode.signIn
                              ? 'Sign in to keep your cats in sync.'
                              : 'Create an account to back up your data.',
                          textAlign: TextAlign.center,
                          style: text.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        if (auth.lastError != null) ...<Widget>[
                          const SizedBox(height: 16),
                          _ErrorBanner(message: auth.lastError!.message),
                        ],
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _email,
                          enabled: !busy,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const <String>[AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.mail_outline),
                          ),
                          validator: (String? value) {
                            final String? v = value?.trim();
                            if (v == null || v.isEmpty) {
                              return 'Enter your email.';
                            }
                            if (!v.contains('@')) return 'Email looks invalid.';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _password,
                          enabled: !busy,
                          obscureText: _obscure,
                          autofillHints: _mode == AuthMode.signIn
                              ? const <String>[AutofillHints.password]
                              : const <String>[
                                  AutofillHints.newPassword,
                                ],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: _obscure ? 'Show' : 'Hide',
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: busy
                                  ? null
                                  : () =>
                                      setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (String? value) {
                            if (value == null || value.isEmpty) {
                              return 'Enter your password.';
                            }
                            if (_mode == AuthMode.signUp && value.length < 8) {
                              return 'Use at least 8 characters.';
                            }
                            return null;
                          },
                        ),
                        if (_mode == AuthMode.signIn) ...<Widget>[
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: TextButton(
                              onPressed: busy ? null : _resetPassword,
                              child: const Text('Forgot password?'),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: busy ? null : _submit,
                          child: busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _mode == AuthMode.signIn
                                      ? 'Sign in'
                                      : 'Create account',
                                ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: busy ? null : _signInWithGoogle,
                          icon: const Icon(Icons.account_circle_outlined),
                          label: const Text('Continue with Google'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: busy ? null : _signInAsGuest,
                          child: const Text('Continue as guest'),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => setState(() {
                                    _mode = _mode == AuthMode.signIn
                                        ? AuthMode.signUp
                                        : AuthMode.signIn;
                                  }),
                          child: Text(
                            _mode == AuthMode.signIn
                                ? 'New here? Create an account'
                                : 'Already have an account? Sign in',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}