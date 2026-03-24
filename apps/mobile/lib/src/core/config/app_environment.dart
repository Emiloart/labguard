abstract final class AppEnvironment {
  static const appName = 'LabGuard';
  static const brandAttribution = 'Built by Emilo Labs';
  static const releaseTrack = String.fromEnvironment(
    'LABGUARD_RELEASE_TRACK',
    defaultValue: 'internal',
  );
  static const environment = String.fromEnvironment(
    'LABGUARD_ENV',
    defaultValue: 'development',
  );
  static const apiBaseUrl = String.fromEnvironment(
    'LABGUARD_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );
  static const appVersion = String.fromEnvironment(
    'LABGUARD_APP_VERSION',
    defaultValue: '1.0.0+1',
  );
}
