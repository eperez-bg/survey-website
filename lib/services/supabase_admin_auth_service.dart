// supabase_admin_auth_service.dart
//
// Responsibility:
// Talks to Supabase Auth for email/password sign-in, restored browser sessions,
// auth-state events, and sign-out. It never owns widget or navigation state.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_session.dart';
import 'admin_auth_service.dart';
import 'admin_session_start_store.dart';

class SupabaseAdminAuthService implements AdminAuthService {
  final SupabaseClient client;
  final AdminSessionStartStore _sessionStartStore;

  SupabaseAdminAuthService({
    required this.client,
    AdminSessionStartStore? sessionStartStore,
  }) : _sessionStartStore =
            sessionStartStore ?? SharedPreferencesAdminSessionStartStore();

  @override
  Future<AdminSession?> restoreSession() => _toAdminSession(
        client.auth.currentSession,
      );

  @override
  Stream<AdminSession?> get sessionChanges =>
      client.auth.onAuthStateChange.asyncMap(
        (state) => _toAdminSession(state.session),
      );

  @override
  Future<AdminSession> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final rawSession = response.session;
      if (rawSession == null || rawSession.user.isAnonymous) {
        throw const AdminAuthException(
          'Supabase did not return a permanent authenticated session.',
        );
      }

      final signedInAt = DateTime.now().toUtc();
      await _sessionStartStore.writeForUser(
        rawSession.user.id,
        signedInAt,
      );
      final session = await _toAdminSession(
        rawSession,
        fallbackSignedInAt: signedInAt,
      );
      if (session == null) {
        throw const AdminAuthException(
          'Supabase did not return a permanent authenticated session.',
        );
      }
      return session;
    } on AdminAuthException {
      rethrow;
    } on AuthException catch (error) {
      throw AdminAuthException(_friendlyAuthMessage(error.message));
    } catch (_) {
      throw const AdminAuthException(
        'The sign-in request could not be completed. Check your internet '
        'connection and try again.',
      );
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await client.auth.signOut();
    } finally {
      await _sessionStartStore.clear();
    }
  }

  Future<AdminSession?> _toAdminSession(
    Session? session, {
    DateTime? fallbackSignedInAt,
  }) async {
    if (session == null || session.user.isAnonymous) {
      return null;
    }

    var signedInAt = await _sessionStartStore.readForUser(session.user.id);
    signedInAt ??= fallbackSignedInAt ??
        DateTime.tryParse(session.user.lastSignInAt ?? '')?.toUtc();
    if (signedInAt == null) {
      return null;
    }
    await _sessionStartStore.writeForUser(session.user.id, signedInAt);

    return AdminSession(
      userId: session.user.id,
      email: session.user.email,
      signedInAt: signedInAt,
    );
  }

  String _friendlyAuthMessage(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('invalid login credentials')) {
      return 'The email or password is incorrect.';
    }
    if (normalized.contains('email not confirmed')) {
      return 'This email address has not been confirmed in Supabase yet.';
    }
    if (normalized.contains('rate limit') ||
        normalized.contains('too many requests')) {
      return 'There have been too many sign-in attempts. Wait a moment and '
          'try again.';
    }
    return message.trim().isEmpty
        ? 'Supabase could not sign in with those credentials.'
        : message;
  }
}
