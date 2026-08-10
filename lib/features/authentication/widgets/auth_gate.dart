import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../routes/app_routes.dart';
import '../models/auth_state.dart';
import '../providers/auth_provider.dart';

/// Auth gate helpers. The router owns the actual redirect policy.
///
/// Two pieces:
///   * [buildRedirect] — pure function consumed by `GoRouter`'s
///     `redirect` callback. It consults the latest [AuthState]
///     captured in a closure (rather than reading the provider from
///     `context`, which isn't available inside `redirect`).
///   * [refreshListenable] — the [AuthProvider] instance, so go_router
///     re-runs the redirect on every auth transition.
class AuthGate {
  AuthGate._();

  /// Builds the redirect callback for `GoRouter.redirect`. The
  /// provider is captured by reference so the closure always reads
  /// the latest state when go_router invokes it.
  static String Function(BuildContext, GoRouterState) buildRedirect(
    AuthProvider provider,
  ) {
    return (BuildContext context, GoRouterState state) {
      final AuthState current = provider.state;
      final String loc = state.matchedLocation;

      // 1. While Firebase is still resolving, force every navigation
      //    through the splash screen (which owns its own loading UI).
      if (current is AuthStateUnknown) {
        return loc == AppRoutes.splash ? loc : AppRoutes.splash;
      }

      final bool authed =
          current is AuthStateAuthenticated || current is AuthStateGuest;

      // 2. Unauthenticated user trying to reach a protected route:
      //    bounce to /login (but keep /splash so we don't fight
      //    itself on cold-start).
      if (!authed &&
          loc != AppRoutes.login &&
          loc != AppRoutes.splash) {
        return AppRoutes.login;
      }

      // 3. Authenticated user hitting the login screen: send them
      //    home. Same for splash.
      if (authed &&
          (loc == AppRoutes.login || loc == AppRoutes.splash)) {
        return AppRoutes.home;
      }

      return loc;
    };
  }
}