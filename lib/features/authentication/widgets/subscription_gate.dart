import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/subscription_provider.dart';
import '../screens/subscription_screen.dart';

/// Prevents construction of the protected application until bdApps confirms
/// an active subscription.
class SubscriptionGate extends StatelessWidget {
  const SubscriptionGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionProvider>(
      child: child,
      builder:
          (BuildContext context, SubscriptionProvider subscription, child) {
            if (subscription.hasAccess) return child!;
            return MaterialApp(
              title: AppConstants.appName,
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: ThemeMode.light,
              home: const SubscriptionScreen(),
            );
          },
    );
  }
}
