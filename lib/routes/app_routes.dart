/// Route path constants. Centralized so they can be referenced from tests,
/// deep-link config, and analytics.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String onboarding = '/onboarding';
  static const String catSwitch = '/cats/switch';
  static const String catProfilePattern = '/cats/:id';
  static String catProfile(String id) => '/cats/$id';

  // Bottom-nav shell children.
  static const String home = '/home';
  static const String routine = '/routine';
  static const String nutrition = '/nutrition';
  static const String profile = '/profile';

  // Top-level secondary destinations.
  static const String healthRecords = '/health-records';
  static const String medications = '/medications';
  static const String vaccinations = '/vaccinations';
  static const String vetFinder = '/vet-finder';
  static const String aiAssistant = '/ai';
  static const String settings = '/settings';
  static const String reminders = '/reminders';
  static const String addFeeding = '/nutrition/add';
  static const String nutritionReport = '/nutrition/report';
  static const String weightTrend = '/weight';
  static const String emergencyGuidance = '/emergency';
  static const String weeklyReport = '/weekly-report';
  static const String faq = '/faq';
  static const String foodLabel = '/food-label';
  static const String grooming = '/grooming';
  static const String foodGuide = '/guides/food';
  static const String catSafety = '/guides/safety';
  static const String careGuides = '/guides/care';
  static const String kittenCare = '/guides/kitten';
}
