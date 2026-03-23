abstract final class AppEnvironment {
  static const appName = 'LabGuard';
  static const brandAttribution = 'Built by Emilo Labs';
  static const environment = String.fromEnvironment(
    'LABGUARD_ENV',
    defaultValue: 'development',
  );
  static const apiBaseUrl = String.fromEnvironment(
    'LABGUARD_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );
  static const appVersion = '0.1.0';
}
