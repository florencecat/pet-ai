import 'package:shared_preferences/shared_preferences.dart';

/// Сервис настроек внешнего вида приложения.
class AppearanceService {
  static const _usePetColorKey = 'appearance_use_pet_color';

  Future<bool> getUsePetColor() async {
    return (await SharedPreferencesAsync().getBool(_usePetColorKey)) ?? false;
  }

  Future<void> setUsePetColor(bool value) async {
    await SharedPreferencesAsync().setBool(_usePetColorKey, value);
  }
}
