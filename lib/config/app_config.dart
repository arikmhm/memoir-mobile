/// Application configuration based on environment.
class AppConfig {
  final String apiBaseUrl;
  final String environment; // 'dev' or 'prod'
  final bool enableLogging;

  AppConfig({
    required this.apiBaseUrl,
    required this.environment,
    required this.enableLogging,
  });

  bool get isDev => environment == 'dev';
  bool get isProd => environment == 'prod';

  factory AppConfig.fromEnvironment() {
    const env = String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'dev',
    );

    const baseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue:
          'https://backend-memoir-development.up.railway.app/api/v1',
    );

    const enableLogging = bool.fromEnvironment(
      'ENABLE_LOGGING',
      defaultValue: true,
    );

    return AppConfig(
      apiBaseUrl: baseUrl,
      environment: env,
      enableLogging: enableLogging,
    );
  }
}
