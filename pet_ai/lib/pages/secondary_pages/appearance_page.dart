import 'package:flutter/material.dart';
import 'package:pet_ai/services/appearance_controller.dart';
import 'package:pet_ai/theme/app_colors.dart';
import 'package:pet_ai/theme/widgets/glass_widgets.dart';
import 'package:provider/provider.dart';

/// Страница настроек внешнего вида.
class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final appearance = context.watch<AppearanceController>();
    return Scaffold(
      backgroundColor: ThemeColors.background,
      appBar: AppBar(
        title: const Text('Внешний вид'),
        backgroundColor: ThemeColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: !appearance.loaded
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
                    value: appearance.usePetColor,
                    onChanged: (v) =>
                        context.read<AppearanceController>().setUsePetColor(v),
                    activeTrackColor: appearance.petColor,
                    activeThumbColor: appearance.petColor,
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
                        color: appearance.usePetColor
                            ? appearance.petColor
                            : ThemeColors.primary,
                        border: Border.all(
                          color: Colors.white.withAlpha(120),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (appearance.usePetColor
                                    ? appearance.petColor
                                    : ThemeColors.primary)
                                .withAlpha(80),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                if (appearance.usePetColor) ...[
                  const SizedBox(height: 12),
                  GlassPlate(
                    color: appearance.petColor.withAlpha(30),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 18, color: appearance.petColor),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Изменить цвет питомца можно в его профиле.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall!
                                  .copyWith(color: ThemeColors.textPrimary),
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
