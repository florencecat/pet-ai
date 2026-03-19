import 'package:flutter/material.dart';
import 'package:pet_ai/services/event_service.dart';
import '../../theme/app_colors.dart';
import '../../services/profile_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _clearAppData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить данные?'),
        content: const Text(
          'Будут удалены все данные питомца, события и настройки. '
          'Приложение будет выглядеть как при первом запуске.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ProfileService().clearProfile();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Данные приложения очищены')),
      );
      Navigator.pushReplacementNamed(context, '/registration');
    }
  }

  Future<void> _clearEvents(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить данные?'),
        content: const Text('Будут удалены все события питомца. '),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await EventService().clearEvents();

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('События удалены')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),

          Text('Основные', style: Theme.of(context).textTheme.titleMedium),

          const SizedBox(height: 8),

          Card.outlined(
            shape: cardBorder,
            child: ListTile(
              leading: const Icon(
                Icons.notifications,
                color: ThemeColors.border,
              ),
              title: Text(
                'Уведомления',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              subtitle: Text(
                'Настройка напоминаний и событий',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: ThemeColors.border,
              ),
              onTap: () {
                // TODO: экран уведомлений
              },
            ),
          ),

          /// 🎨 Внешний вид (плейсхолдер)
          Card.outlined(
            shape: cardBorder,
            child: ListTile(
              leading: const Icon(Icons.palette, color: ThemeColors.border),
              title: Text(
                'Внешний вид',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              subtitle: Text(
                'Тема, цвета, оформление',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: ThemeColors.border,
              ),
              onTap: () {
                // TODO: экран темы
              },
            ),
          ),

          /// 🐾 Профиль питомца (плейсхолдер)
          Card.outlined(
            shape: cardBorder,
            child: ListTile(
              leading: const Icon(Icons.pets, color: ThemeColors.border),
              title: Text(
                'Профиль питомца',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              subtitle: Text(
                'Редактирование данных питомца',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: ThemeColors.border,
              ),
              onTap: () {
                // TODO: переход на PetProfilePage
              },
            ),
          ),

          const SizedBox(height: 24),

          /// 🧪 Отладка
          Text('Отладка', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),

          Card.outlined(
            shape: dangerCardBorder,
            child: ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: Text(
                'Очистить данные приложения',
                style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  inherit: true,
                  color: ThemeColors.danger,
                ),
              ),
              subtitle: Text(
                'Сброс SharedPreferences (для отладки)',
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  inherit: true,
                  color: ThemeColors.danger,
                ),
              ),
              onTap: () => _clearAppData(context),
            ),
          ),

          Card.outlined(
            shape: dangerCardBorder,
            child: ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: Text(
                'Очистить все события',
                style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  inherit: true,
                  color: ThemeColors.danger,
                ),
              ),
              subtitle: Text(
                'Удалить все события на устройстве (для отладки)',
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  inherit: true,
                  color: ThemeColors.danger,
                ),
              ),
              onTap: () => _clearEvents(context),
            ),
          ),

          const SizedBox(height: 32),

          /// ℹ️ Версия
          Center(
            child: Text(
              'Pet Health App · MVP\nv0.1.0',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
