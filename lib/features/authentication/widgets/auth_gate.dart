import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../routes/app_routes.dart';
import '../../cats/providers/cat_provider.dart';
import '../models/auth_state.dart';
import '../providers/auth_provider.dart';

/// Auth gate helpers. The router owns the actual redirect policy.
///
/// Two pieces:
///   * [buildRedirect] - pure function consumed by `GoRouter`'s
///     `redirect` callback. It consults the latest [AuthState] and
///     [CatProvider] state captured in a closure (rather than reading
///     the providers from `context`, which isn't available inside
///     `redirect`).
///   * [refreshListenable] - the [AuthProvider] (and on Phase 3, the
///     [CatProvider]) instance, so go_router re-runs the redirect on
///     every auth / cat-list transition.
class AuthGate {
  AuthGate._();

  /// Builds the redirect callback for `GoRouter.redirect`. The
  /// providers are captured by reference so the closure always reads
  /// the latest state when go_router invokes it.
  static String Function(BuildContext, GoRouterState) buildRedirect({
    required AuthProvider authProvider,
    required CatProvider catProvider,
  }) {
    return (BuildContext context, GoRouterState state) {
      final AuthState current = authProvider.state;
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

      // 4. First-time users with zero cats are funneled through
      //    onboarding. The /onboarding route itself is exempt so the
      //    flow can complete; /cats/switch and /cats/:id are also
      //    exempt - the user may have just added a cat and the
      //    snapshot hasn't refreshed yet.
      if (authed &&
          catProvider.hasLoaded &&
          catProvider.cats.isEmpty &&
          loc != AppRoutes.onboarding &&
          loc != AppRoutes.catSwitch &&
          !loc.startsWith('/cats/')) {
        return AppRoutes.onboarding;
      }

      return loc;
    };
  }
}