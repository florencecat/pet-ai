import 'package:flutter/material.dart';
import 'package:pet_ai/services/appearance_service.dart';
import 'package:pet_ai/services/profile_service.dart';
import 'package:pet_ai/theme/app_colors.dart';
import 'package:pet_ai/theme/widgets/glass_widgets.dart';

/// Страница настроек внешнего вида.
class AppearancePage extends StatefulWidget {
  const AppearancePage({super.key});

  @override
  State<AppearancePage> createState() => _AppearancePageState();
}

class _AppearancePageState extends State<AppearancePage> {
  bool _usePetColor = false;
  Color _petColor = ThemeColors.primary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final usePetColor = await AppearanceService().getUsePetColor();
    final profile = await ProfileService().loadActiveProfile();
    if (mounted) {
      setState(() {
        _usePetColor = usePetColor;
        _petColor = profile?.color ?? ThemeColors.primary;
        _loading = false;
      });
    }
  }

  Future<void> _toggle(bool value) async {
    setState(() => _usePetColor = value);
    await AppearanceService().setUsePetColor(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColors.background,
      appBar: AppBar(
        title: const Text('Внешний вид'),
        backgroundColor: ThemeColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, _usePetColor),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Тема',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                GlassPlate(
                  child: SwitchListTile(
                    value: _usePetColor,
                    onChanged: _toggle,
                    activeTrackColor: _petColor,
                    activeThumbColor: _petColor,
                    title: const Text('Использовать цвет питомца'),
                    subtitle: Text(
                      'Применяет цвет профиля активного питомца'
                      ' как основной цвет приложения',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    secondary: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _usePetColor ? _petColor : ThemeColors.primary,
                        border: Border.all(
                          color: Colors.white.withAlpha(120),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_usePetColor ? _petColor : ThemeColors.primary)
                                .withAlpha(80),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                if (_usePetColor) ...[
                  const SizedBox(height: 12),
                  GlassPlate(
                    color: _petColor.withAlpha(30),
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 18,
                              color: _petColor),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Изменить цвет питомца можно в его профиле. '
                              'Перезапустите приложение, чтобы применить новый цвет.',
                              style:
                                  Theme.of(context).textTheme.bodySmall!.copyWith(
                                        color: ThemeColors.textPrimary,
                                      ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
