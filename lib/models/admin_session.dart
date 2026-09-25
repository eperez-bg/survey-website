// admin_session.dart
//
// Responsibility:
// Represents the small amount of authenticated-user state the admin website
// needs. Supabase-specific token objects stay in the auth service.

class AdminSession {
  final String userId;
  final String? email;
  final DateTime signedInAt;

  const AdminSession({
    required this.userId,
    required this.email,
    required this.signedInAt,
  });

  DateTime expiresAt(Duration maximumAge) =>
      signedInAt.toUtc().add(maximumAge);

  bool isExpiredAt(DateTime now, Duration maximumAge) =>
      !expiresAt(maximumAge).isAfter(now.toUtc());
}
