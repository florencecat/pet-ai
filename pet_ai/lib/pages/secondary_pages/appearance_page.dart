import 'package:flutter/material.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:pet_satellite/theme/widgets/glass_widgets.dart';
import 'package:pet_satellite/theme/widgets/settings_widgets.dart';
import 'package:pet_satellite/theme/widgets/switch.dart';
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
                      trailing: OutlinedSwitch(
                        value: appearance.usePetColor,
                        onChanged: (v) async => await context
                            .read<AppearanceController>()
                            .setUsePetColor(v),
                      ),
                      iconColor: appearance.petColor,
                    ),
                    const SettingsCardDivider(),
                    SettingsRow(
                      icon: Icons.vertical_align_top,
                      label: 'Закреплённый заголовок',
                      subtitle:
                          'Заголовок страницы остаётся на месте — скроллится только содержимое',
                      trailing: OutlinedSwitch(
                        value: appearance.pinnedHeader,
                        onChanged: (v) async => await context
                            .read<AppearanceController>()
                            .setPinnedHeader(v),
                      ),
                      iconColor: appearance.petColor,
                      last: true,
                    ),
                  ],
                ),

                if (appearance.usePetColor) ...[
                  const SizedBox(height: 12),
                  InfoGlassPlate(
                    label: 'Изменить цвет питомца можно в его профиле.',
                    color: appearance.petColor,
                  ),
                ],
              ],
            ),
    );
  }
}
