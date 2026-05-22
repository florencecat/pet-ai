import 'dart:convert';

import 'package:pet_satellite/models/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  static const _key = 'user_profile_v1';

  Future<UserProfile?> load() async {
    final prefs = SharedPreferencesAsync();
    final raw = await prefs.getString(_key);
    if (raw == null) return null;
    try {
      return UserProfile.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
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
}
