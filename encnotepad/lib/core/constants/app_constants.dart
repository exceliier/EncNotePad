class AppConstants {
  static const String appName = 'EncNotePad';
  static const String appVersion = '1.0.0';
  static const String fileExtension = 'enp';
  static const String fileTypeFilter = 'enp';

  // Inactivity auto-lock default: 5 minutes (in seconds)
  static const int defaultAutoLockTimeoutSeconds = 300;

  // Debounced auto-save duration: 10 seconds
  static const Duration autoSaveDebounceDuration = Duration(seconds: 10);

  // Maximum retained shadow copies
  static const int maxShadowCopies = 15;

  // Milestone snapshot interval (15 minutes of active editing)
  static const Duration milestoneSnapshotInterval = Duration(minutes: 15);
}
