import 'package:flutter/foundation.dart';

import '../services/api_service.dart';

enum AuthStatus { loading, loggedOut, loggedIn }

class AuthProvider extends ChangeNotifier {
  AuthStatus status = AuthStatus.loading;
  Map<String, dynamic>? user;

  Map<String, dynamic>? get resident =>
      user?['resident'] as Map<String, dynamic>?;
  String get verificationStatus =>
      (resident?['verification_status'] ?? 'Pending').toString();

  String _errorText(Object e) => e.toString().replaceFirst('Exception: ', '');

  /// Called once at startup: if a saved token exists, load the profile.
  Future<void> tryAutoLogin() async {
    final token = await ApiService.getToken();
    if (token == null || token.isEmpty) {
      status = AuthStatus.loggedOut;
      notifyListeners();
      return;
    }
    try {
      // ApiService clears the token itself if the server answers 401.
      await refreshUser();
      status = AuthStatus.loggedIn;
    } catch (_) {
      status = AuthStatus.loggedOut;
    }
    notifyListeners();
  }

  Future<void> refreshUser() async {
    final data = await ApiService.getMe();
    user = Map<String, dynamic>.from(data['user'] as Map);
    notifyListeners();
  }

  /// Returns null on success, or an error message.
  Future<String?> login(String email, String password) async {
    try {
      // ApiService saves the token after a successful login.
      final data = await ApiService.login(
        email: email.trim(),
        password: password,
      );
      user = Map<String, dynamic>.from(data['user'] as Map);
      status = AuthStatus.loggedIn;
      notifyListeners();
      return null;
    } catch (e) {
      return _errorText(e);
    }
  }

  Future<void> logout() async {
    // Clears the token even if the server can't be reached.
    await ApiService.logout();
    user = null;
    status = AuthStatus.loggedOut;
    notifyListeners();
  }
}