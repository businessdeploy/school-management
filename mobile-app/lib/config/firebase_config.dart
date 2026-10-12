class FirebaseConfig {
  FirebaseConfig._();

  static const String projectId = 'smart-school-2023';

  /// These getters read compiler/environment overrides so secrets are never
  /// checked into source control. Make sure to provide the same via
  /// `--dart-define=FIREBASE_CLIENT_EMAIL=...`.
  static String get clientEmail => const String.fromEnvironment(
        'FIREBASE_CLIENT_EMAIL',
        defaultValue: '<USE_ENV_VARIABLE>',
      );

  static String get privateKey => const String.fromEnvironment(
        'FIREBASE_PRIVATE_KEY',
        defaultValue: '<USE_ENV_VARIABLE>',
      );

  static bool get hasValidSecrets =>
      clientEmail != '<USE_ENV_VARIABLE>' &&
      privateKey != '<USE_ENV_VARIABLE>';
}

