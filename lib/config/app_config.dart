// app_config.dart
//
// Responsibility:
// Centralizes compile-time configuration for the web app. Keeping Supabase
// values here makes it easy to switch between test and production projects
// without hard-coding credentials in source control.

class AppConfig {
  static const defaultSampleObjectPath =
      'w-jefferson/2255/'
      '2026-09-02T16-49-21.211618Z-f09bbef1-166e-4edb-9ea8-d12f9a92484c.json';

  final String supabaseUrl;
  final String supabasePublishableKey;
  final String surveyBucket;
  final String sampleObjectPath;

  const AppConfig({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    required this.surveyBucket,
    required this.sampleObjectPath,
  });

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
      supabasePublishableKey: String.fromEnvironment(
        'SUPABASE_PUBLISHABLE_KEY',
      ),
      surveyBucket: String.fromEnvironment(
        'SUPABASE_SURVEY_BUCKET',
        defaultValue: 'survey-submissions',
      ),
      sampleObjectPath: String.fromEnvironment(
        'SAMPLE_SURVEY_OBJECT_PATH',
        defaultValue: defaultSampleObjectPath,
      ),
    );
  }

  bool get isConfigured =>
      supabaseUrl.trim().isNotEmpty && supabasePublishableKey.trim().isNotEmpty;
}
