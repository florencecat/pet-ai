import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/services/event_service.dart';
import 'package:pet_satellite/services/notification_service.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:pet_satellite/theme/widgets/settings_widgets.dart';
import 'package:pet_satellite/theme/widgets/skeleton.dart';
import 'package:provider/provider.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationsPage> {
  // Настройки уведомлений (персистентные).
  NotificationSettings _notificationSettings = const NotificationSettings();
  // Пока настройки не загружены из SharedPreferences — не рисуем тумблеры, чтобы
  // они не мигали из дефолтного состояния в реальное (как в AppearancePage).
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    final notificationSettings = await NotificationSettings.load();
    if (mounted) {
      setState(() {
        _notificationSettings = notificationSettings;
        _loaded = true;
      });
    }
  }

  // ── Notifications ───────────────────────────────────────────────────────────

  /// Сохраняет настройку, при необходимости пересоздаёт канал и пересобирает
  /// всё расписание уведомлений под новые параметры.
  Future<void> _updateNotif(
      NotificationSettings next, {
        bool channelChanged = false,
      }) async {
    await next.save();
    if (channelChanged) {
      await NotificationService().applyChannelSettings(next);
    }
    await EventService().rescheduleAllNotifications();
    if (mounted) setState(() => _notificationSettings = next);
  }

  Future<void> _pickQuietTime(bool isStart) async {
    final current = isStart ? _notificationSettings.quietStartMinutes : _notificationSettings.quietEndMinutes;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked == null) return;
    final minutes = picked.hour * 60 + picked.minute;
    await _updateNotif(
      isStart
          ? _notificationSettings.copyWith(quietStartMinutes: minutes)
          : _notificationSettings.copyWith(quietEndMinutes: minutes),
    );
  }

  Future<void> _pickAllDayTime() async {
    final current = _notificationSettings.allDayReminderMinutes;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked == null) return;
    await _updateNotif(
      _notificationSettings.copyWith(
        allDayReminderMinutes: picked.hour * 60 + picked.minute,
      ),
    );
  }

  String _fmtMinutes(int m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}:'
          '${(m % 60).toString().padLeft(2, '0')}';

  /// На MIUI/HyperOS (Xiaomi, Redmi и др.) всплывающие уведомления гейтятся
  /// отдельным системным тумблером, который приложение включить не может, —
  /// поэтому при включении «Важных уведомлений» подсказываем пользователю.
  void _showHeadsUpHint() {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          showCloseIcon: true,
          duration: Duration(seconds: 6),
          content: Text(
            'На некоторых устройствах (Xiaomi, Redmi и др.) всплывающие '
            'уведомления нужно дополнительно включить в системных настройках.',
          ),
        ),
      );
  }

  Switch _notifSwitch(
      AppearanceController ac,
      bool value,
      ValueChanged<bool> onChanged,
      ) {
    return Switch(
      inactiveThumbColor: ac.primaryColor,
      trackOutlineColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.selected)) return Colors.transparent;
        return ac.primaryColor;
      }),
      value: value,
      activeThumbColor: ac.primaryColor,
      onChanged: onChanged,
    );
  }

  /// Скелетон-заглушка на время загрузки настроек — повторяет раскладку
  /// карточки с тумблерами, поэтому контент не «прыгает» при появлении.
  Widget _loadingPlaceholder() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SettingsSectionLabel(title: 'Настройки уведомлений'),
        const SizedBox(height: 8),
        SettingsCard(
          children: [
            for (int i = 0; i < 4; i++) ...[
              if (i > 0) const SettingsCardDivider(),
              const _SkeletonRow(),
            ],
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ac = context.watch<AppearanceController>();
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: ThemeColors.background,
      appBar: AppBar(
        title: Text('Уведомления', style: theme.textTheme.titleMedium),
        backgroundColor: ThemeColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: !_loaded
          ? _loadingPlaceholder()
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SettingsSectionLabel(title: 'Настройки уведомлений'),
          const SizedBox(height: 8),

          SettingsCard(
            children: [
              SettingsRow(
                icon: Icons.notifications_outlined,
                label: 'Напоминания',
                subtitle: 'Прививки, корм, прогулки',
                iconColor: ac.primaryColor,
                trailing: _notifSwitch(
                  ac,
                  _notificationSettings.enabled,
                      (v) => _updateNotif(_notificationSettings.copyWith(enabled: v)),
                ),
                last: !_notificationSettings.enabled,
              ),
              if (_notificationSettings.enabled) ...[
                SettingsCardDivider(),
                SettingsRow(
                  icon: Icons.bedtime_outlined,
                  label: 'Тихие часы',
                  subtitle: _notificationSettings.quietHoursEnabled
                      ? 'Не беспокоить в этот промежуток'
                      : 'Выключены',
                  iconColor: ac.primaryColor,
                  trailing: _notifSwitch(
                    ac,
                    _notificationSettings.quietHoursEnabled,
                        (v) => _updateNotif(_notificationSettings.copyWith(quietHoursEnabled: v)),
                  ),
                ),
                if (_notificationSettings.quietHoursEnabled) ...[
                  SettingsCardDivider(),
                  SettingsRow(
                    icon: Icons.nightlight_outlined,
                    label: 'Начало',
                    subtitle: _fmtMinutes(_notificationSettings.quietStartMinutes),
                    iconColor: ac.primaryColor,
                    trailing: settingsChevronIcon(ac.primaryColor.withAlpha(140)),
                    onTap: () => _pickQuietTime(true),
                  ),
                  SettingsCardDivider(),
                  SettingsRow(
                    icon: Icons.wb_twilight_outlined,
                    label: 'Конец',
                    subtitle: _fmtMinutes(_notificationSettings.quietEndMinutes),
                    iconColor: ac.primaryColor,
                    trailing: settingsChevronIcon(ac.primaryColor.withAlpha(140)),
                    onTap: () => _pickQuietTime(false),
                  ),
                ],
                SettingsCardDivider(),
                SettingsRow(
                  icon: Icons.wb_sunny_outlined,
                  label: 'События на весь день',
                  subtitle:
                      'Напоминать в ${_fmtMinutes(_notificationSettings.allDayReminderMinutes)}',
                  iconColor: ac.primaryColor,
                  trailing: settingsChevronIcon(ac.primaryColor.withAlpha(140)),
                  onTap: _pickAllDayTime,
                ),
                SettingsCardDivider(),
                SettingsRow(
                  icon: Icons.volume_up_outlined,
                  label: 'Звук',
                  iconColor: ac.primaryColor,
                  trailing: _notifSwitch(
                    ac,
                    _notificationSettings.sound,
                        (v) => _updateNotif(
                      _notificationSettings.copyWith(sound: v),
                      channelChanged: true,
                    ),
                  ),
                ),
                SettingsCardDivider(),
                SettingsRow(
                  icon: Icons.vibration,
                  label: 'Вибрация',
                  iconColor: ac.primaryColor,
                  trailing: _notifSwitch(
                    ac,
                    _notificationSettings.vibrate,
                        (v) => _updateNotif(
                      _notificationSettings.copyWith(vibrate: v),
                      channelChanged: true,
                    ),
                  ),
                ),
                SettingsCardDivider(),
                SettingsRow(
                  icon: Icons.priority_high,
                  label: 'Важные уведомления',
                  subtitle: 'Показывать поверх экрана',
                  iconColor: ac.primaryColor,
                  trailing: _notifSwitch(
                    ac,
                    _notificationSettings.highImportance,
                    (v) {
                      _updateNotif(
                        _notificationSettings.copyWith(highImportance: v),
                        channelChanged: true,
                      );
                      if (v) _showHeadsUpHint();
                    },
                  ),
                  last: true,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Скелетон одной строки настроек: иконка + две строки текста + «тумблер».
/// Повторяет геометрию [SettingsRow], чтобы заглушка совпадала с контентом.
class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          SkeletonBox(width: 22, height: 22, borderRadius: 6),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonText(width: 150, height: 13),
                SizedBox(height: 7),
                SkeletonText(width: 200, height: 11),
              ],
            ),
          ),
          SizedBox(width: 14),
          SkeletonBox(width: 44, height: 26, borderRadius: 14),
        ],
      ),
    );
  }
}
