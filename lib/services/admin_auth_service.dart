// admin_auth_service.dart
//
// Responsibility:
// Defines the authentication boundary used by the controller. Keeping this
// interface independent from widgets makes session behavior easy to test.

import '../models/admin_session.dart';

abstract interface class AdminAuthService {
  Future<AdminSession?> restoreSession();

  Stream<AdminSession?> get sessionChanges;

  Future<AdminSession> signIn({
    required String email,
    required String password,
  });

  Future<void> signOut();
}

class AdminAuthException implements Exception {
  final String message;

  const AdminAuthException(this.message);

  @override
  String toString() => message;
}
