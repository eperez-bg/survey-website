// app_config.dart
// Central runtime configuration for the storage-backed admin MVP.

class AppConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static const String surveyBucket = 'survey-submissions';

  // The sample object the user identified for initial testing.
  static const String sampleObjectPath =
      'surveys/NC/w-jefferson/2255/2026-09-02T16-49-21.211618Z-f09bbef1-166e-4edb-9ea8-d12f9a92484c.json';

  static bool get hasSupabaseConfig =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;
}
