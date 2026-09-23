// survey_admin_app.dart
//
// Responsibility:
// Composes dependencies once at the app boundary and keeps authentication out of
// this prototype. When auth is added later, this is the natural place to gate
// the admin workspace behind an authenticated session.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../controllers/survey_admin_controller.dart';
import '../repositories/survey_metadata_repository.dart';
import '../repositories/survey_storage_repository.dart';
import '../screens/store_list_screen.dart';

class SurveyAdminApp extends StatelessWidget {
  final AppConfig config;
  final SupabaseClient? client;

  const SurveyAdminApp({
    super.key,
    required this.config,
    required this.client,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Survey Production Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2563EB),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      home: client == null
          ? const _ConfigurationScreen()
          : _AdminBootstrap(config: config, client: client!),
    );
  }
}

class _AdminBootstrap extends StatefulWidget {
  final AppConfig config;
  final SupabaseClient client;

  const _AdminBootstrap({required this.config, required this.client});

  @override
  State<_AdminBootstrap> createState() => _AdminBootstrapState();
}

class _AdminBootstrapState extends State<_AdminBootstrap> {
  late final SurveyAdminController _controller;

  @override
  void initState() {
    super.initState();
    final storageRepository = SurveyStorageRepository(
      client: widget.client,
      bucketName: widget.config.surveyBucket,
    );
    final metadataRepository = SurveyMetadataRepository(
      client: widget.client,
    );
    _controller = SurveyAdminController(
      storageRepository: storageRepository,
      metadataRepository: metadataRepository,
    );
    _controller.addListener(_rebuild);
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.removeListener(_rebuild);
    _controller.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return StoreListScreen(controller: _controller);
  }
}

class _ConfigurationScreen extends StatelessWidget {
  const _ConfigurationScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Supabase configuration needed',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Create dart_defines.local.json from the included example, '
                    'add your project URL and publishable key, then run:',
                  ),
                  const SizedBox(height: 14),
                  const SelectableText(
                    'flutter run -d chrome '
                    '--dart-define-from-file=dart_defines.local.json',
                    style: TextStyle(fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Do not put a Supabase service-role/secret key in this '
                    'Flutter web project. This prototype intentionally has no '
                    'login, so Storage policies must temporarily allow the anon '
                    'role to select and insert survey-submissions objects.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
