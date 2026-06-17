/// App-wide configuration.
class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'CBT_API_URL',
    defaultValue: 'http://localhost:8080',
  );

  /// LMS backend API URL (bio-api on port 4000).
  static const String lmsApiUrl = String.fromEnvironment(
    'LMS_API_URL',
    defaultValue: 'http://localhost:4000',
  );

  static const String encryptionKey = String.fromEnvironment(
    'CBT_ENCRYPTION_KEY',
    defaultValue: 'this-is-a-32-byte-long-key-1234',
  );

  static const String masterSecret = String.fromEnvironment(
    'CBT_MASTER_SECRET',
    defaultValue: 'change-me-in-production',
  );

  static const String certPin = String.fromEnvironment(
    'CBT_CERT_PIN',
    defaultValue: '',
  );

  static const int maxNoFaceSeconds = 5;
  static const int maxViolations = 5;
  static const int proctoringIntervalMs = 2000;
}

