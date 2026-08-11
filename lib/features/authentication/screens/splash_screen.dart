import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../routes/app_routes.dart';
import '../providers/auth_provider.dart';

/// Splash. Displayed while Firebase Auth is still resolving the
/// persisted session (i.e. while [AuthProvider.state] is
/// [AuthStateUnknown]). Once `isReady` flips, we let the router
/// `redirect` decide between `/login` and the shell.
///
/// The widget itself never decides where to go — it only surfaces
/// the loading state. This keeps auth gating in a single place
/// (the router) instead of every splash screen fighting the
/// navigator.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _navigated = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (BuildContext context, AuthProvider auth, _) {
        // Once Firebase has reported, let the router's redirect kick
        // in. We do it here (rather than only via redirect) to avoid
        // a visible flash of the splash when the user lands directly
        // on `/` with a cached session.
        if (auth.isReady && !_navigated) {
          _navigated = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final String target = auth.isAuthenticated
                ? AppRoutes.home
                : AppRoutes.login;
            if (context.mounted) context.go(target);
          });
        }
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.pets, size: 72),
                SizedBox(height: 16),
                CircularProgressIndicator(),
              ],
            ),
          ),
        );
      },
    );
  }
}