import 'dart:convert';

import 'package:get_it/get_it.dart';
import 'package:pet_satellite/models/user_profile.dart';
import 'package:pet_satellite/services/authentification_service.dart';
import 'package:pet_satellite/services/pb_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages local persistence of [UserProfile] and delegates remote auth
/// operations to [AuthService].
class UserProfileService {
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
    // Persist locally.
    final prefs = SharedPreferencesAsync();
    await prefs.setString(_key, jsonEncode(profile.toJson()));

    // Sync editable fields to PocketBase (only when authenticated and id is set).
    if (profile.id.isEmpty) return;
    final pb = GetIt.instance<PocketBaseService>().pb;
    if (!pb.authStore.isValid) return;
    try {
      await pb.collection('users').update(profile.id, body: {
        'name': profile.name,
        'city': profile.city,
      });
    } catch (_) {
      // Non-fatal: local save already succeeded.
    }
  }

  Future<void> delete() async {
    final prefs = SharedPreferencesAsync();
    await prefs.remove(_key);
  }

  Future<bool> hasProfile() async => (await load()) != null;

  // ── Remote auth ───────────────────────────────────────────────────────────

  /// Unified sign-in / sign-up: creates account if [email] is new,
  /// then sends an OTP. [AuthResult.isNewUser] indicates a fresh account.
  Future<AuthResult> requestAccess(String email) =>
      GetIt.instance<AuthService>().requestAccess(email);

  /// Updates the display name of the currently authenticated user in PocketBase.
  Future<void> updateName(String name) =>
      GetIt.instance<AuthService>().updateName(name);

  /// Verifies the OTP code. On success, [AuthService.pb].authStore is
  /// populated with the session token and user record.
  Future<AuthResult> verifyOTP({
    required String otpId,
    required String code,
  }) =>
      GetIt.instance<AuthService>().verifyOTP(otpId: otpId, code: code);

  /// Requests a new OTP (resend).
  Future<AuthResult> resendOTP(String email) =>
      GetIt.instance<AuthService>().resendOTP(email);

  /// Permanently deletes the remote account (users record) and clears the
  /// session. Local data must be cleared separately by the caller.
  /// Rethrows on failure so the caller can avoid a false "deleted" state.
  Future<void> deleteAccount() =>
      GetIt.instance<AuthService>().deleteAccount();
}
