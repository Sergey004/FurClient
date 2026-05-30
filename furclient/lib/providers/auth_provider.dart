import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/auth_service.dart';

/// Auth Provider for managing authentication state
///
/// Handles:
/// - Login/logout
/// - Session persistence
/// - Authentication status
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  // ── State ────────────────────────────────────────────────────────
  bool _isAuthenticated = false;
  bool _isLoading = false;
  UserSession? _currentSession;
  String? _error;

  // ── Getters ──────────────────────────────────────────────────────
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  UserSession? get currentSession => _currentSession;
  String? get error => _error;
  String? get username => _currentSession?.username;

  // ── Initialization ───────────────────────────────────────────────

  /// Initialize auth state from storage
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.loadSavedSession();
      final session = _authService.currentSession;
      if (session != null && session.isLoggedIn) {
        _currentSession = session;
        _isAuthenticated = true;
        debugPrint('=== AuthProvider: Session restored for ${session.username}');
      }
    } catch (e) {
      debugPrint('=== AuthProvider: Error initializing: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Authentication ───────────────────────────────────────────────

  /// Login with session data
  Future<bool> login(UserSession session) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.saveSession(session);
      _currentSession = session;
      _isAuthenticated = true;

      debugPrint('=== AuthProvider: Login successful for ${session.username}');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('=== AuthProvider: Login failed: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Logout
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.logout();
      _currentSession = null;
      _isAuthenticated = false;

      debugPrint('=== AuthProvider: Logout successful');
    } catch (e) {
      debugPrint('=== AuthProvider: Logout error: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Session management ───────────────────────────────────────────

  /// Update session data
  Future<void> updateSession(UserSession session) async {
    _currentSession = session;
    await _authService.saveSession(session);
    notifyListeners();
  }

  /// Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
