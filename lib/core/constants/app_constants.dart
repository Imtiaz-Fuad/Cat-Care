/// App-wide constants. Cross-platform (Android + iOS).
class AppConstants {
  AppConstants._();

  static const String appName = 'CatCare BD';

  // Firestore collection paths (single source of truth for paths).
  static const String usersCollection = 'users';
  static const String catsSubcollection = 'cats';
  static const String routinesSubcollection = 'routines';
  static const String feedingsSubcollection = 'feedings';
  static const String waterSubcollection = 'water';
  static const String contentCollection = 'content';
  static const String vetClinicsCollection = 'vet_clinics';

  // SharedPreferences keys (UI-only settings; never auth).
  static const String themeModeKey = 'pref.theme_mode';
  static const String localeKey = 'pref.locale';
  static const String accentOverrideKey = 'pref.accent_override';
  static const String firstLaunchKey = 'pref.first_launch';
  static const String guestDeviceIdKey = 'pref.guest_device_id';
  static const String activeCatIdKey = 'pref.active_cat_id';

  // Notification channels (Android). iOS uses the same logical IDs.
  static const String notificationsChannelRoutine = 'catcare_routine';
  static const String notificationsChannelVaccines = 'catcare_vaccines';
  static const String notificationsChannelMedications = 'catcare_medications';
  static const String notificationsChannelWater = 'catcare_water';
  static const String notificationsChannelWeight = 'catcare_weight';
  static const String notificationsChannelDeworming = 'catcare_deworming';
}
