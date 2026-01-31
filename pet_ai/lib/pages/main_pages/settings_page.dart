import 'package:flutter/material.dart';
import '../../theme/app_styles.dart';
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          /// 🔔 Уведомления (плейсхолдер)
          Card.outlined(
            shape: cardBorder,
            child: ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Уведомления'),
              subtitle: const Text('Настройка напоминаний и событий'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: экран уведомлений
              },
            ),
          ),

          /// 🎨 Внешний вид (плейсхолдер)
          Card.outlined(
            shape: cardBorder,
            child: ListTile(
              leading: const Icon(Icons.palette),
              title: const Text('Внешний вид'),
              subtitle: const Text('Тема, цвета, оформление'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: экран темы
              },
            ),
          ),

          /// 🐾 Профиль питомца (плейсхолдер)
          Card.outlined(
            shape: cardBorder,
            child: ListTile(
              leading: const Icon(Icons.pets),
              title: const Text('Профиль питомца'),
              subtitle: const Text('Редактирование данных питомца'),
              trailing: const Icon(Icons.chevron_right),
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
              title: const Text(
                'Очистить данные приложения',
                style: TextStyle(color: Colors.red),
              ),
              subtitle: const Text('Сброс SharedPreferences (для отладки)'),
              onTap: () => _clearAppData(context),
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
