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
    final TextTheme text = Theme.of(context).textTheme;
    return Consumer<AuthProvider>(
      builder: (BuildContext context, AuthProvider auth, _) {
        final bool busy = auth.isBusy;
        const Color terracotta = Color(0xFFA5482A);
        const Color ink = Color(0xFF241F1D);
        return Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xFFFFFDFC),
                  Color(0xFFF9EFEC),
                  Color(0xFFF0F7F4),
                ],
                stops: <double>[0, 0.48, 1],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 28,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        inputDecorationTheme: InputDecorationTheme(
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.82),
                          labelStyle: const TextStyle(color: Color(0xFF6D5750)),
                          floatingLabelStyle: const TextStyle(color: terracotta),
                          prefixIconColor: terracotta,
                          suffixIconColor: terracotta,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFE7C8BE),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: terracotta,
                              width: 1.5,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFD9534F)),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFD9534F),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Center(
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6E3DE),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: const Icon(
                              Icons.pets,
                              size: 34,
                              color: terracotta,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          AppConstants.appName,
                          textAlign: TextAlign.center,
                          style: text.headlineMedium?.copyWith(
                            color: ink,
                            fontSize: 30,
                            letterSpacing: -0.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _mode == AuthMode.signIn
                              ? 'Sign in to keep your cats in sync.'
                              : 'Create an account to back up your data.',
                          textAlign: TextAlign.center,
                          style: text.bodyMedium?.copyWith(
                            color: const Color(0xFF4D403B),
                          ),
                        ),
                        if (auth.lastError != null) ...<Widget>[
                          const SizedBox(height: 16),
                          _ErrorBanner(message: auth.lastError!.message),
                        ],
                        const SizedBox(height: 30),
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
                              style: TextButton.styleFrom(
                                foregroundColor: terracotta,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 8,
                                ),
                              ),
                              child: const Text('Forgot password?'),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        FilledButton(
                          onPressed: busy ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: terracotta,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(52),
                            elevation: 2,
                            shadowColor: terracotta.withValues(alpha: 0.28),
                            shape: const StadiumBorder(),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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
                        const SizedBox(height: 16),
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
                            style: const TextStyle(color: terracotta),
                          ),
                        ),
                      ],
                    ),
                      ),
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
