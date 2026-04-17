import 'package:flutter/material.dart';
import 'package:pet_ai/pages/secondary_pages/appearance_page.dart';
import 'package:pet_ai/services/ai_service.dart';
import 'package:pet_ai/services/event_service.dart';
import 'package:pet_ai/theme/app_colors.dart';
import 'package:pet_ai/theme/widgets/glass_widgets.dart';
import '../../services/profile_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<bool> _confirmClear(BuildContext context, {
    String title = 'Очистить данные?',
    required String content,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
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
    return confirmed == true;
  }

  Future<void> _clearAppData(BuildContext context) async {
    if (!await _confirmClear(context, content:
      'Будут удалены все данные питомца, события и настройки. '
      'Приложение будет выглядеть как при первом запуске.',
    )) {
      return;
    }

    final profiles = await ProfileService().loadAllProfiles();
    await EventService().clearEventsForAll(profiles.map((p) => p.id).toList());
    await ProfileService().clearAll();
    await AIChatController.clearMessageHistory();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Данные приложения очищены')),
      );
      Navigator.pushReplacementNamed(context, '/registration');
    }
  }

  Future<void> _clearEvents(BuildContext context) async {
    if (!await _confirmClear(context, content: 'Будут удалены все события питомца.')) {
      return;
    }

    final profileId = await ProfileService().getActiveProfileId();
    if (profileId != null) {
      await EventService().clearEvents(profileId);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('События удалены')),
      );
    }
  }

  Future<void> _clearWeightHistory(BuildContext context) async {
    if (!await _confirmClear(context, content: 'Будет удалена вся история веса.')) {
      return;
    }

    final profileId = await ProfileService().getActiveProfileId();
    if (profileId != null) {
      await ProfileService().clearWeightHistory(profileId);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('История веса удалена')),
      );
    }
  }

  Future<void> _clearMoodHistory(BuildContext context) async {
    if (!await _confirmClear(context, content: 'Будет удалена вся история настроения.')) {
      return;
    }

    final profileId = await ProfileService().getActiveProfileId();
    if (profileId != null) {
      await ProfileService().clearMoodHistory(profileId);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('История настроения удалена')),
      );
    }
  }

  Future<void> _clearMessageHistory(BuildContext context) async {
    if (!await _confirmClear(context,
      title: 'Очистить диалог?',
      content: 'Будет удалена вся история общения с ИИ.',
    )) {
      return;
    }

    await AIChatController.clearMessageHistory();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('История сообщений удалена')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: pageGradientDecoration.gradient,
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 125),
          children: [
            const SizedBox(height: 8),

            Text('Основные', style: Theme.of(context).textTheme.titleMedium),

            const SizedBox(height: 8),

            GlassSettingsCard(
              leadingIcon: Icons.notifications,
              title: 'Уведомления',
              subtitle: 'Настройка напоминаний и событий',
              trailingIcon: Icons.chevron_right,
            ),

            GlassSettingsCard(
              leadingIcon: Icons.palette,
              title: 'Внешний вид',
              subtitle: 'Тема, цвета, оформление',
              trailingIcon: Icons.chevron_right,
              callback: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AppearancePage()),
              ),
            ),

            GlassSettingsCard(
              leadingIcon: Icons.pets,
              title: 'Профиль питомца',
              subtitle: 'Редактирование данных питомца',
              trailingIcon: Icons.chevron_right,
            ),

            const SizedBox(height: 24),

            /// 🧪 Отладка
            Text('Отладка', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),

            GlassSettingsCard.debug(
              leadingIcon: Icons.delete_forever,
              title: 'Очистить данные приложения',
              subtitle: 'Сброс SharedPreferences',
              callback: () => _clearAppData(context),
            ),

            GlassSettingsCard.debug(
              leadingIcon: Icons.delete_forever,
              title: 'Очистить все события',
              subtitle: 'Удалить все события на устройстве',
              callback: () => _clearEvents(context),
            ),

            GlassSettingsCard.debug(
              leadingIcon: Icons.delete_forever,
              title: 'Очистить историю веса',
              subtitle: 'Удалить все записи в истории веса',
              callback: () => _clearWeightHistory(context),
            ),

            GlassSettingsCard.debug(
              leadingIcon: Icons.delete_forever,
              title: 'Очистить историю настроения',
              subtitle: 'Удалить все записи в истории настроения',
              callback: () => _clearMoodHistory(context),
            ),

            GlassSettingsCard.debug(
              leadingIcon: Icons.delete_forever,
              title: 'Очистить историю сообщений в чате',
              subtitle: 'Удалить все сообщения',
              callback: () => _clearMessageHistory(context),
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
      ),
    );
  }
}
