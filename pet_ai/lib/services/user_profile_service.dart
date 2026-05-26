import 'dart:convert';

import 'package:pet_satellite/models/user_profile.dart';
import 'package:pet_satellite/services/authentification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages local persistence of [UserProfile] and delegates remote auth
/// operations to [AuthService].
class UserService {
  static const _key = 'user_profile_v1';

  // ── Local storage ─────────────────────────────────────────────────────────

  Future<UserProfile?> load() async {
    final prefs = SharedPreferencesAsync();
    final raw = await prefs.getString(_key);
    if (raw == null) return null;
    try {
      return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(UserProfile profile) async {
    final prefs = SharedPreferencesAsync();
    await prefs.setString(_key, jsonEncode(profile.toJson()));
  }

  Future<void> delete() async {
    final prefs = SharedPreferencesAsync();
    await prefs.remove(_key);
  }

  Future<bool> hasProfile() async => (await load()) != null;

  // ── Remote auth ───────────────────────────────────────────────────────────

  /// Registers a new account and requests an OTP for email verification.
  ///
  /// On success, the returned [AuthResult.otpId] must be passed to
  /// [verifyOTP] to complete registration.
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirm,
  }) =>
      AuthService().register(
        name: name,
        email: email,
        password: password,
        passwordConfirm: passwordConfirm,
      );

  /// Verifies the OTP code. On success, [AuthService.pb].authStore is
  /// populated with the session token and user record.
  Future<AuthResult> verifyOTP({
    required String otpId,
    required String code,
  }) =>
      AuthService().verifyOTP(otpId: otpId, code: code);

  /// Requests a new OTP (resend).
  Future<AuthResult> resendOTP(String email) =>
      AuthService().resendOTP(email);

  /// Signs in with [email] and [password].
  ///
  /// On success, [AuthService.pb].authStore holds the session and user record.
  Future<AuthResult> login({
    required String email,
    required String password,
  }) =>
      AuthService().login(email: email, password: password);

  /// Sends a password-reset link to [email].
  Future<AuthResult> requestPasswordReset(String email) =>
      AuthService().requestPasswordReset(email);
}
