import 'package:flutter/material.dart';
import 'package:pet_ai/services/event_service.dart';
import 'package:pet_ai/theme/widgets/outlined_cards.dart';
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

  Future<void> _clearWeightHistory(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить данные?'),
        content: const Text('Будут удалены вся история веса. '),
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

    await ProfileService().clearWeightHistory();

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('История веса удалена')));
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

          SettingsCard(
            leadingIcon: Icons.notifications,
            title: 'Уведомления',
            subtitle: 'Настройка напоминаний и событий',
            trailingIcon: Icons.chevron_right,
          ),

          SettingsCard(
            leadingIcon: Icons.palette,
            title: 'Внешний вид',
            subtitle: 'Тема, цвета, оформление',
            trailingIcon: Icons.chevron_right,
          ),

          SettingsCard(
            leadingIcon: Icons.pets,
            title: 'Профиль питомца',
            subtitle: 'Редактирование данных питомца',
            trailingIcon: Icons.chevron_right,
          ),

          const SizedBox(height: 24),

          /// 🧪 Отладка
          Text('Отладка', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),

          SettingsCard.debug(
            leadingIcon: Icons.delete_forever,
            title: 'Очистить данные приложения',
            subtitle: 'Сброс SharedPreferences',
            callback: () => _clearAppData(context),
          ),

          SettingsCard.debug(
            leadingIcon: Icons.delete_forever,
            title: 'Очистить все события',
            subtitle: 'Удалить все события на устройстве',
            callback: () => _clearEvents(context),
          ),

          SettingsCard.debug(
            leadingIcon: Icons.delete_forever,
            title: 'Очистить историю веса',
            subtitle: 'Удалить все записи в истории веса',
            callback: () => _clearWeightHistory(context),
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
