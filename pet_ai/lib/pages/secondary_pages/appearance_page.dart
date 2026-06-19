import 'package:flutter/material.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:pet_satellite/theme/widgets/glass_widgets.dart';
import 'package:pet_satellite/theme/widgets/settings_widgets.dart';
import 'package:provider/provider.dart';

/// Страница настроек внешнего вида.
class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appearance = context.watch<AppearanceController>();
    return Scaffold(
      backgroundColor: ThemeColors.background,
      appBar: AppBar(
        title: Text('Внешний вид', style: theme.textTheme.titleMedium),
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
                SettingsSectionLabel(title: 'Тема'),
                const SizedBox(height: 8),

                SettingsCard(
                  children: [
                    SettingsRow(
                      icon: Icons.notifications_outlined,
                      label: 'Использовать цвет питомца',
                      subtitle:
                          'Применяет цвет профиля активного питомца как основной цвет приложения',
                      trailing: Switch(
                        inactiveThumbColor: appearance.petColor,
                        trackOutlineColor:
                            WidgetStateProperty.resolveWith<Color?>((
                              Set<WidgetState> states,
                            ) {
                              if (states.contains(WidgetState.selected)) {
                                return Colors
                                    .transparent; // Border color when ON
                              }
                              return appearance
                                  .petColor; // Border color when OFF
                            }),
                        value: appearance.usePetColor,
                        activeThumbColor: appearance.petColor,
                        onChanged: (v) async => await context
                            .read<AppearanceController>()
                            .setUsePetColor(v),
                      ),
                      iconColor: appearance.petColor,
                    ),
                  ],
                ),

                if (appearance.usePetColor) ...[
                  const SizedBox(height: 12),
                  SoftGlassPlate(
                    color: appearance.petColor.withAlpha(30),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: appearance.petColor,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Изменить цвет питомца можно в его профиле.',
                              style: Theme.of(context).textTheme.bodySmall,
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
