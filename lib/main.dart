// main.dart
// App bootstrap. Initializes Supabase with public client credentials supplied
// through --dart-define and starts the admin website.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/store_list_screen.dart';
import 'utils/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConfig.hasSupabaseConfig) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
  }

  runApp(const SurveyAdminApp());
}

class SurveyAdminApp extends StatelessWidget {
  const SurveyAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Survey Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: AppConfig.hasSupabaseConfig
          ? const StoreListScreen()
          : const _MissingConfigScreen(),
    );
  }
}

class _MissingConfigScreen extends StatelessWidget {
  const _MissingConfigScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: const Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Supabase configuration is missing',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                Text(
                  'Run Flutter with SUPABASE_URL and SUPABASE_ANON_KEY as '
                  '--dart-define values. Do not use a Supabase service-role key '
                  'inside Flutter Web.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
