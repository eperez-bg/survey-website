// admin_session_start_store.dart
//
// Responsibility:
// Persists the original start time for this browser's admin session. Supabase
// refreshes short-lived tokens, so token issue/expiry times cannot represent the
// requested seven-day maximum login window.

import 'package:shared_preferences/shared_preferences.dart';

abstract interface class AdminSessionStartStore {
  Future<DateTime?> readForUser(String userId);

  Future<void> writeForUser(String userId, DateTime signedInAt);

  Future<void> clear();
}

class SharedPreferencesAdminSessionStartStore
    implements AdminSessionStartStore {
  static const String _userIdKey = 'survey_admin.auth.user_id';
  static const String _signedInAtKey = 'survey_admin.auth.signed_in_at';

  final SharedPreferencesAsync _preferences;

  SharedPreferencesAdminSessionStartStore({
    SharedPreferencesAsync? preferences,
  }) : _preferences = preferences ?? SharedPreferencesAsync();

  @override
  Future<DateTime?> readForUser(String userId) async {
    final storedUserId = await _preferences.getString(_userIdKey);
    if (storedUserId != userId) {
      return null;
    }
    final rawDate = await _preferences.getString(_signedInAtKey);
    return DateTime.tryParse(rawDate ?? '')?.toUtc();
  }

  @override
  Future<void> writeForUser(String userId, DateTime signedInAt) async {
    await _preferences.setString(_userIdKey, userId);
    await _preferences.setString(
      _signedInAtKey,
      signedInAt.toUtc().toIso8601String(),
    );
  }

  @override
  Future<void> clear() async {
    await _preferences.remove(_userIdKey);
    await _preferences.remove(_signedInAtKey);
  }
}
