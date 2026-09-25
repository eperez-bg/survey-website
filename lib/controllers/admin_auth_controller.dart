// admin_auth_controller.dart
//
// Responsibility:
// Coordinates startup session restoration, login, logout, error state, and the
// admin website's seven-day maximum session age.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/admin_session.dart';
import '../services/admin_auth_service.dart';

enum AdminAuthStatus {
  checking,
  signedOut,
  authenticated,
}

typedef AdminSessionClock = DateTime Function();

class AdminAuthController extends ChangeNotifier {
  static const Duration defaultSessionLifetime = Duration(days: 7);

  final AdminAuthService _authService;
  final Duration sessionLifetime;
  final AdminSessionClock _clock;

  StreamSubscription<AdminSession?>? _sessionSubscription;
  Timer? _expirationTimer;
  AdminAuthStatus _status = AdminAuthStatus.checking;
  AdminSession? _session;
  String? _errorMessage;
  String? _noticeMessage;
  bool _isSubmitting = false;
  bool _isInitialized = false;
  bool _isExpiring = false;
  bool _isDisposed = false;

  AdminAuthController({
    required AdminAuthService authService,
    this.sessionLifetime = defaultSessionLifetime,
    AdminSessionClock? clock,
  })  : _authService = authService,
        _clock = clock ?? DateTime.now;

  AdminAuthStatus get status => _status;
  AdminSession? get session => _session;
  String? get signedInEmail => _session?.email;
  String? get errorMessage => _errorMessage;
  String? get noticeMessage => _noticeMessage;
  bool get isSubmitting => _isSubmitting;
  bool get isAuthenticated => _status == AdminAuthStatus.authenticated;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }
    _isInitialized = true;
    _sessionSubscription = _authService.sessionChanges.listen(
      (session) => unawaited(_acceptSession(session)),
      onError: (Object error, StackTrace stackTrace) {
        if (_isDisposed) {
          return;
        }
        _errorMessage =
            'The sign-in session could not be refreshed. Check your internet '
            'connection and reload the page.';
        notifyListeners();
      },
    );
    try {
      await _acceptSession(await _authService.restoreSession());
    } catch (_) {
      if (_isDisposed) {
        return;
      }
      _status = AdminAuthStatus.signedOut;
      _session = null;
      _errorMessage =
          'The saved sign-in session could not be restored. Sign in again.';
      notifyListeners();
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    if (_isSubmitting) {
      return;
    }

    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || password.isEmpty) {
      _errorMessage = 'Enter both your email and password.';
      _noticeMessage = null;
      notifyListeners();
      return;
    }

    _isSubmitting = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();

    try {
      final nextSession = await _authService.signIn(
        email: normalizedEmail,
        password: password,
      );
      if (_isDisposed) {
        return;
      }
      _isSubmitting = false;
      await _acceptSession(nextSession);
    } on AdminAuthException catch (error) {
      if (_isDisposed) {
        return;
      }
      _isSubmitting = false;
      _status = AdminAuthStatus.signedOut;
      _session = null;
      _errorMessage = error.message;
      notifyListeners();
    } catch (_) {
      if (_isDisposed) {
        return;
      }
      _isSubmitting = false;
      _status = AdminAuthStatus.signedOut;
      _session = null;
      _errorMessage = 'Sign in failed. Please try again.';
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    if (_isSubmitting) {
      return;
    }

    _isSubmitting = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();

    try {
      await _authService.signOut();
    } catch (_) {
      if (_isDisposed) {
        return;
      }
      _errorMessage =
          'Supabase could not complete sign out, but this browser has been '
          'returned to the login screen.';
    } finally {
      if (!_isDisposed) {
        _expirationTimer?.cancel();
        _session = null;
        _status = AdminAuthStatus.signedOut;
        _isSubmitting = false;
        notifyListeners();
      }
    }
  }

  void clearMessage() {
    if (_errorMessage == null && _noticeMessage == null) {
      return;
    }
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();
  }

  Future<void> _acceptSession(AdminSession? candidate) async {
    if (_isDisposed) {
      return;
    }

    _expirationTimer?.cancel();
    if (candidate == null) {
      _session = null;
      _status = AdminAuthStatus.signedOut;
      _isSubmitting = false;
      notifyListeners();
      return;
    }

    final now = _clock().toUtc();
    if (candidate.isExpiredAt(now, sessionLifetime)) {
      await _expireSession();
      return;
    }

    _session = candidate;
    _status = AdminAuthStatus.authenticated;
    _errorMessage = null;
    _noticeMessage = null;
    _scheduleExpiration(candidate, now);
    notifyListeners();
  }

  void _scheduleExpiration(AdminSession candidate, DateTime now) {
    final remaining = candidate.expiresAt(sessionLifetime).difference(now);
    _expirationTimer = Timer(
      remaining,
      () => unawaited(_expireSession()),
    );
  }

  Future<void> _expireSession() async {
    if (_isExpiring || _isDisposed) {
      return;
    }
    _isExpiring = true;
    _expirationTimer?.cancel();
    _session = null;
    _status = AdminAuthStatus.signedOut;
    _isSubmitting = false;
    _errorMessage = null;
    _noticeMessage =
        'Your seven-day session expired. Sign in again to continue.';
    notifyListeners();

    try {
      await _authService.signOut();
    } catch (_) {
      // The dashboard is already gated locally. Supabase will reject the
      // restored session once the optional server-side timebox is configured.
    } finally {
      _isExpiring = false;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _expirationTimer?.cancel();
    unawaited(_sessionSubscription?.cancel());
    super.dispose();
  }
}
