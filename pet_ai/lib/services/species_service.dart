import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pet_ai/models/species.dart';

class SpeciesService {
  static const _cacheKey = 'cached_species';
  static const _cacheTtlKey = 'cached_species_ttl';
  static const _cacheDuration = Duration(days: 7);

  /// Главный метод: интернет → кэш → встроенный список
  Future<List<PetSpecies>> loadSpecies() async {
    // 1. Пробуем загрузить из сети
    try {
      final online = await _fetchFromNetwork();
      if (online != null) {
        await _saveToCache(online);
        return online;
      }
    } catch (_) {
      // Нет сети или ошибка — идём дальше
    }

    // 2. Пробуем отдать актуальный кэш
    final cached = await _loadFromCache();
    if (cached != null) return cached;

    // 3. Встроенный список как последний fallback
    return BuiltInSpecies.all;
  }

  Future<List<PetSpecies>?> _fetchFromNetwork() async {
    // Реализация зависит от выбранного API — см. раздел ниже
    throw UnimplementedError('Выберите API и реализуйте здесь');
  }

  Future<void> _saveToCache(List<PetSpecies> species) async {
    final prefs = SharedPreferencesAsync();
    final encoded = jsonEncode(species.map((s) => s.toJson()).toList());
    await prefs.setString(_cacheKey, encoded);
    await prefs.setInt(
      _cacheTtlKey,
      DateTime.now().add(_cacheDuration).millisecondsSinceEpoch,
    );
  }

  Future<List<PetSpecies>?> _loadFromCache() async {
    final prefs = SharedPreferencesAsync();
    final ttl = await prefs.getInt(_cacheTtlKey);
    if (ttl == null || DateTime.now().millisecondsSinceEpoch > ttl) return null;

    final raw = await prefs.getString(_cacheKey);
    if (raw == null) return null;

    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => PetSpecies.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// Быстрая проверка доступности интернета
  Future<bool> hasInternet() async {
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
