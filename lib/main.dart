// main.dart
//
// Responsibility:
// Initializes Supabase for the browser and starts the internal survey website.
// Authentication is intentionally NOT implemented in this test build.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/survey_admin_app.dart';
import 'config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();

  SupabaseClient? client;
  if (config.isConfigured) {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabasePublishableKey,
    );
    client = Supabase.instance.client;
  }

  runApp(SurveyAdminApp(config: config, client: client));
}
