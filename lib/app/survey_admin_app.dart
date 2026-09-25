// survey_admin_app.dart
//
// Responsibility:
// Composes dependencies once at the app boundary and gates the existing admin
// workspace behind a permanent Supabase email/password session.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../controllers/admin_auth_controller.dart';
import '../controllers/survey_admin_controller.dart';
import '../repositories/survey_metadata_repository.dart';
import '../repositories/survey_storage_repository.dart';
import '../screens/login_screen.dart';
import '../screens/store_list_screen.dart';
import '../services/supabase_admin_auth_service.dart';

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
          : _AuthBootstrap(config: config, client: client!),
    );
  }
}

class _AuthBootstrap extends StatefulWidget {
  final AppConfig config;
  final SupabaseClient client;

  const _AuthBootstrap({required this.config, required this.client});

  @override
  State<_AuthBootstrap> createState() => _AuthBootstrapState();
}

class _AuthBootstrapState extends State<_AuthBootstrap> {
  late final AdminAuthController _authController;

  @override
  void initState() {
    super.initState();
    _authController = AdminAuthController(
      authService: SupabaseAdminAuthService(client: widget.client),
    );
    _authController.addListener(_rebuild);
    unawaited(_authController.initialize());
  }

  @override
  void dispose() {
    _authController.removeListener(_rebuild);
    _authController.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (!mounted) {
      return;
    }
    if (!_authController.isAuthenticated) {
      // The map editor is pushed as a full-screen route. Remove every pushed
      // admin route when a user signs out or the seven-day session expires so
      // an already-open editor cannot remain visible above the login screen.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    switch (_authController.status) {
      case AdminAuthStatus.checking:
        return const _SessionLoadingScreen();
      case AdminAuthStatus.signedOut:
        return LoginScreen(controller: _authController);
      case AdminAuthStatus.authenticated:
        return _AdminBootstrap(
          config: widget.config,
          client: widget.client,
          authController: _authController,
        );
    }
  }
}

class _AdminBootstrap extends StatefulWidget {
  final AppConfig config;
  final SupabaseClient client;
  final AdminAuthController authController;

  const _AdminBootstrap({
    required this.config,
    required this.client,
    required this.authController,
  });

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
    return StoreListScreen(
      controller: _controller,
      signedInEmail: widget.authController.signedInEmail,
      onSignOut: widget.authController.signOut,
    );
  }
}

class _SessionLoadingScreen extends StatelessWidget {
  const _SessionLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Checking sign-in session...'),
          ],
        ),
      ),
    );
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
                    'Flutter web project. The publishable key is correct here; '
                    'Supabase Auth and Row Level Security protect the survey '
                    'data.',
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
