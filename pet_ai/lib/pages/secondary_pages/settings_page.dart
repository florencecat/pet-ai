import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pet_satellite/models/user_profile.dart';
import 'package:pet_satellite/pages/secondary_pages/appearance_page.dart';
import 'package:pet_satellite/pages/secondary_pages/notifications_page.dart';
import 'package:pet_satellite/pages/secondary_pages/pet_profile_page.dart';
import 'package:pet_satellite/pages/secondary_pages/user_profile_page.dart';
import 'package:pet_satellite/pages/registration_flows/user_registration_flow.dart';
import 'package:pet_satellite/services/ai_service.dart';
import 'package:pet_satellite/services/api_service.dart';
import 'package:pet_satellite/services/cloud_sync_service.dart';
import 'package:pet_satellite/services/crash_reporting_service.dart';
import 'package:pet_satellite/services/event_service.dart';
import 'package:pet_satellite/services/notification_service.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/services/pb_service.dart';
import 'package:pet_satellite/services/user_profile_service.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:pet_satellite/theme/widgets/confirm_delete.dart';
import 'package:pet_satellite/theme/widgets/glass_widgets.dart';
import 'package:pet_satellite/theme/widgets/pressable.dart';
import 'package:pet_satellite/theme/widgets/settings_widgets.dart';
import 'package:provider/provider.dart';
import '../../services/pet_profile_service.dart';
import 'package:pet_satellite/models/pet_profile.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  List<Pet> _profiles = [];
  bool _loadingProfiles = true;
  UserProfile? _user;

  // Подтверждение удаления (загружается асинхронно из SharedPreferences).
  bool _confirmDeleteEnabled = true;

  // Автосоздание предложенных ИИ событий (без подтверждения).
  bool _autoCreateEntities = false;

  // Имя и версия приложения для футера — читаются из package_info, чтобы
  // совпадать с релизной сборкой и не требовать ручного обновления.
  String _appVersion = '';

  late final CloudSyncService _sync;
  late final CrashReportingService _crash;

  @override
  void initState() {
    super.initState();
    _sync = CloudSyncService.instance;
    _sync.addListener(_onSyncChanged);
    _crash = CrashReportingService.instance;
    _crash.addListener(_onSyncChanged);
    _loadAll();
  }

  @override
  void dispose() {
    _sync.removeListener(_onSyncChanged);
    _crash.removeListener(_onSyncChanged);
    super.dispose();
  }

  void _onSyncChanged() => setState(() {});

  Future<void> _loadAll() async {
    final profiles = await PetService().loadAllProfiles();
    final user = await UserService().load();
    final confirmDeleteEnabled = await isDeleteConfirmationEnabled();
    final autoCreateEntities = await isAutoCreateEntitiesEnabled();

    String? appVersion;
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = info.version;
    } catch (_) {
      // package_info может быть недоступен — оставляем значения по умолчанию.
    }

    if (mounted) {
      setState(() {
        _profiles = profiles;
        _loadingProfiles = false;
        _user = user;
        _confirmDeleteEnabled = confirmDeleteEnabled;
        _autoCreateEntities = autoCreateEntities;
        if (appVersion != null) _appVersion = appVersion;
      });
    }
  }

  Future<void> _openUserProfile() async {
    if (_user == null) {
      // No profile yet → registration flow
      final result = await Navigator.push<UserProfile>(
        context,
        MaterialPageRoute(
          builder: (_) => const UserRegistrationFlow(),
          fullscreenDialog: true,
        ),
      );
      if (result != null && mounted) setState(() => _user = result);
    } else {
      // Profile exists → edit page; null return = deleted
      await Navigator.push<UserProfile?>(
        context,
        MaterialPageRoute(builder: (_) => UserProfileEditPage(profile: _user!)),
      );
      _loadAll();
    }
  }

  Future<void> _logout() async {
    final confirmed = await confirmDelete(
      context,
      title: 'Выйти из аккаунта?',
      message: 'Сессия на этом устройстве будет завершена и вам придется войти заново.',
    );
    if (confirmed) {
      await UserService().delete();
      GetIt.instance<PocketBaseService>().pb.authStore.clear();
      if (mounted) setState(() => _user = null);
    }
  }

  // ── Sync actions ──────────────────────────────────────────────────────────

  Future<void> _syncPushAll(BuildContext context) async {
    final petId = await PetService().getActiveProfileId();
    if (petId == null) return;
    try {
      await _sync.pushAll(petId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Данные успешно отправлены на сервер')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_sync.lastError ?? 'Ошибка синхронизации')),
        );
      }
    }
  }

  Future<void> _syncPullAll(BuildContext context) async {
    final petId = await PetService().getActiveProfileId();
    if (petId == null) return;

    if (context.mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) =>
            AlertDialog(
              title: const Text('Загрузить с сервера?'),
              content: const Text(
                'Локальные данные питомца будут заменены данными с сервера. '
                    'Это действие нельзя отменить.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: ThemeColors.dangerZone,
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Загрузить'),
                ),
              ],
            ),
      );

      if (confirmed != true) return;

      try {
        await _sync.pullAll();
        await AIChatController.restoreThreadsFromCloud();
        await _loadAll();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Данные загружены с сервера')),
          );
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_sync.lastError ?? 'Ошибка загрузки')),
          );
        }
      }
    }
  }

  // ── Debug actions ─────────────────────────────────────────────────────────

  Future<bool> _confirmClear(
    BuildContext context, {
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
    if (!await _confirmClear(
      context,
      content:
          'Будут удалены все данные питомца, события и настройки. '
          'Приложение будет выглядеть как при первом запуске.',
    )) {
      return;
    }

    final profiles = await PetService().loadAllProfiles();
    await EventService().clearEventsForAll(profiles.map((p) => p.id).toList());
    await PetService().clearAll();
    await AIChatController.clearMessageHistory();

    GetIt.instance<PocketBaseService>().pb.authStore.clear();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Данные приложения очищены')),
      );
      Navigator.pushReplacementNamed(context, '/registration');
    }
  }

  Future<void> _clearEvents(BuildContext context) async {
    if (!await _confirmClear(
      context,
      content: 'Будут удалены все события питомца.',
    )) {
      return;
    }

    final profileId = await PetService().getActiveProfileId();
    if (profileId != null) {
      await EventService().clearEvents(profileId);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('События удалены')));
    }
  }

  Future<void> _clearWeightHistory(BuildContext context) async {
    if (!await _confirmClear(
      context,
      content: 'Будет удалена вся история веса.',
    )) {
      return;
    }

    final profileId = await PetService().getActiveProfileId();
    if (profileId != null) {
      await PetService().clearWeightHistory(profileId);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('История веса удалена')));
    }
  }

  Future<void> _clearMoodHistory(BuildContext context) async {
    if (!await _confirmClear(
      context,
      content: 'Будет удалена вся история настроения.',
    )) {
      return;
    }

    final profileId = await PetService().getActiveProfileId();
    if (profileId != null) {
      await PetService().clearMoodHistory(profileId);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('История настроения удалена')),
      );
    }
  }

  Future<void> _clearMessageHistory(BuildContext context) async {
    if (!await _confirmClear(
      context,
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ac = context.watch<AppearanceController>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Настройки', style: theme.textTheme.titleMedium),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
        children: [
          // ── User account ─────────────────────────────────────────────────
          _UserAccountCard(
            user: _user,
            primaryColor: ac.primaryColor,
            onTap: _openUserProfile,
            onDelete: _user != null ? _logout : null,
          ),
          const SizedBox(height: 24),

          // ── Питомцы ──────────────────────────────────────────────────────
          SettingsSectionLabel(title: 'Питомцы'),
          const SizedBox(height: 8),
          SettingsCard(
            children: [
              if (_loadingProfiles)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                ..._profiles.asMap().entries.map((entry) {
                  final i = entry.key;
                  final p = entry.value;
                  final isLast = i == _profiles.length - 1;
                  return _PetRow(
                    profile: p,
                    isLast: isLast && false, // always show divider before "add"
                    onTap: () async {
                      await PetService().setActiveProfile(p.id);
                      await ac.reloadProfile();
                      if (context.mounted) {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PetProfilePage(),
                          ),
                        );
                      }
                      await _loadAll();
                    },
                  );
                }),
                SettingsRow(
                  icon: Icons.add_circle_outline,
                  label: 'Добавить питомца',
                  iconColor: ac.primaryColor,
                  onTap: () => Navigator.pushNamed(context, '/registration'),
                  last: true,
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),

          // ── Оформление ────────────────────────────────────────────────────
          SettingsSectionLabel(title: 'Персонализация'),
          const SizedBox(height: 8),
          SettingsCard(
            children: [
              SettingsRow(
                icon: Icons.notifications_outlined,
                label: 'Уведомления',
                subtitle: 'Настройки уведомлений',
                iconColor: ac.primaryColor,
                trailing: settingsChevronIcon(ac.primaryColor.withAlpha(140)),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsPage()),
                ),
              ),
              SettingsCardDivider(),
              SettingsRow(
                icon: Icons.palette_outlined,
                label: 'Тема и цвета',
                subtitle: 'Оформление приложения',
                iconColor: ac.primaryColor,
                trailing: settingsChevronIcon(ac.primaryColor.withAlpha(140)),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AppearancePage()),
                ),
              ),
              SettingsCardDivider(),
              SettingsRow(
                icon: Icons.language_outlined,
                label: 'Язык',
                subtitle: 'Русский',
                onTap: null, // stub
                iconColor: ac.primaryColor,
              ),
              SettingsCardDivider(),
              SettingsRow(
                icon: Icons.straighten_outlined,
                label: 'Единицы',
                subtitle: 'кг · км',
                onTap: null, // stub
                iconColor: ac.primaryColor,
                last: true,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Помощник ──────────────────────────────────────────────────────
          SettingsSectionLabel(title: 'Помощник'),
          const SizedBox(height: 8),
          SettingsCard(
            children: [
              SettingsRow(
                icon: Icons.auto_awesome_outlined,
                label: 'Создавать события автоматически',
                subtitle: 'Без подтверждения, сразу после ответа ИИ',
                iconColor: ac.primaryColor,
                trailing: Switch(
                  inactiveThumbColor: ac.primaryColor,
                  trackOutlineColor: WidgetStateProperty.resolveWith<Color?>((
                    states,
                  ) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.transparent;
                    }
                    return ac.primaryColor;
                  }),
                  value: _autoCreateEntities,
                  activeThumbColor: ac.primaryColor,
                  onChanged: (v) async {
                    await setAutoCreateEntitiesEnabled(v);
                    if (mounted) setState(() => _autoCreateEntities = v);
                  },
                ),
              ),
              SettingsCardDivider(),
              SettingsRow(
                icon: Icons.lightbulb_outline,
                label: 'Советы помощника',
                subtitle: 'Не чаще раза в день',
                onTap: null, // stub
                iconColor: ac.primaryColor,
                last: true,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Данные и приватность ─────────────────────────────────────────
          SettingsSectionLabel(title: 'Данные и приватность'),
          const SizedBox(height: 8),
          _SyncCard(
            sync: _sync,
            isAuthenticated: _user != null,
            primaryColor: ac.primaryColor,
            onPushAll: () => _syncPushAll(context),
            onPullAll: () => _syncPullAll(context),
          ),
          const SizedBox(height: 8),
          SettingsCard(
            children: [
              SettingsRow(
                icon: Icons.download_outlined,
                label: 'Экспорт данных',
                subtitle: 'Скоро',
                onTap: null,
                iconColor: ac.primaryColor,
              ),
              SettingsCardDivider(),
              SettingsRow(
                icon: Icons.fingerprint,
                label: 'Биометрия при входе',
                onTap: null,
                iconColor: ac.primaryColor,
              ),
              SettingsCardDivider(),
              SettingsRow(
                icon: Icons.delete_sweep_outlined,
                label: 'Подтверждать удаление',
                subtitle: 'Спрашивать перед удалением записей',
                iconColor: ac.primaryColor,
                trailing: Switch(
                  inactiveThumbColor: ac.primaryColor,
                  trackOutlineColor:
                      WidgetStateProperty.resolveWith<Color?>((states) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.transparent;
                    }
                    return ac.primaryColor;
                  }),
                  value: _confirmDeleteEnabled,
                  activeThumbColor: ac.primaryColor,
                  onChanged: (v) async {
                    await setDeleteConfirmationEnabled(v);
                    if (mounted) setState(() => _confirmDeleteEnabled = v);
                  },
                ),
              ),
              SettingsCardDivider(),
              SettingsRow(
                icon: Icons.bug_report_outlined,
                label: 'Отправлять отчёты об ошибках',
                subtitle: 'Помогает быстрее исправлять сбои',
                iconColor: ac.primaryColor,
                trailing: Switch(
                  inactiveThumbColor: ac.primaryColor,
                  trackOutlineColor:
                      WidgetStateProperty.resolveWith<Color?>((states) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.transparent;
                    }
                    return ac.primaryColor;
                  }),
                  value: _crash.enabled,
                  activeThumbColor: ac.primaryColor,
                  onChanged: (v) => _crash.setEnabled(v),
                ),
                last: true,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── О приложении ─────────────────────────────────────────────────
          SettingsSectionLabel(title: 'О приложении'),
          const SizedBox(height: 8),
          SettingsCard(
            children: [
              SettingsRow(
                icon: Icons.help_outline,
                label: 'Помощь и FAQ',
                onTap: null, // stub
                iconColor: ac.primaryColor,
                trailing: settingsChevronIcon(ac.primaryColor.withAlpha(140)),
              ),
              SettingsCardDivider(),
              SettingsRow(
                icon: Icons.star_outline,
                label: 'Оценить приложение',
                onTap: null, // stub
                iconColor: ac.primaryColor,
                trailing: settingsChevronIcon(ac.primaryColor.withAlpha(140)),
              ),
              SettingsCardDivider(),
              SettingsRow(
                icon: Icons.newspaper_rounded,
                label: 'Пользовательское соглашение',
                onTap: () async => GetIt.instance<ApiService>().openTerms(),
                iconColor: ac.primaryColor,
                trailing: settingsChevronIcon(ac.primaryColor.withAlpha(140)),
              ),
              SettingsRow(
                icon: Icons.shield_outlined,
                label: 'Политика конфиденциальности',
                onTap: () async => GetIt.instance<ApiService>().openPrivacy(),
                iconColor: ac.primaryColor,
                trailing: settingsChevronIcon(ac.primaryColor.withAlpha(140)),
              ),
              SettingsCardDivider(),
              SettingsRow(
                icon: Icons.logout,
                label: 'Выйти из аккаунта',
                onTap: _user != null ? _logout : null,
                iconColor: _user != null
                    ? ThemeColors.dangerZone
                    : ThemeColors.border,
                labelColor: _user != null ? ThemeColors.dangerZone : null,
                last: true,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Debug ─────────────────────────────────────────────────────────
          if (kDebugMode) ...[
            SettingsSectionLabel(title: 'Отладка'),
            const SizedBox(height: 8),
            SettingsCard(
              children: [
                SettingsRow(
                  icon: Icons.notifications_active_outlined,
                  label: 'Тест уведомления',
                  subtitle: 'Показать сейчас (звук/вибрация/heads-up)',
                  iconColor: Colors.blue,
                  onTap: () => NotificationService().showTestNotification(),
                ),
                SettingsCardDivider(),
                SettingsRow(
                  icon: Icons.delete_forever,
                  label: 'Очистить все данные',
                  subtitle: 'Сброс SharedPreferences',
                  iconColor: Colors.red,
                  labelColor: Colors.red,
                  onTap: () => _clearAppData(context),
                ),
                SettingsCardDivider(),
                SettingsRow(
                  icon: Icons.delete_forever,
                  label: 'Очистить события',
                  iconColor: Colors.red,
                  onTap: () => _clearEvents(context),
                ),
                SettingsCardDivider(),
                SettingsRow(
                  icon: Icons.delete_forever,
                  label: 'Очистить историю веса',
                  iconColor: Colors.red,
                  onTap: () => _clearWeightHistory(context),
                ),
                SettingsCardDivider(),
                SettingsRow(
                  icon: Icons.delete_forever,
                  label: 'Очистить историю настроения',
                  iconColor: Colors.red,
                  onTap: () => _clearMoodHistory(context),
                ),
                SettingsCardDivider(),
                SettingsRow(
                  icon: Icons.delete_forever,
                  label: 'Очистить диалог с ИИ',
                  iconColor: Colors.red,
                  onTap: () => _clearMessageHistory(context),
                ),
                SettingsCardDivider(),
                SettingsRow(
                  icon: Icons.data_object,
                  label: 'Заполнить историю веса',
                  iconColor: Colors.blue,
                  onTap: () {
                    PetService().fillWeightHistory();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('История веса заполнена')),
                    );
                  },
                  last: true,
                ),
                SettingsRow(
                  icon: Icons.data_object,
                  label: 'Экспорт данных',
                  iconColor: Colors.blue,
                  onTap: () async => await PetService().exportAllProfiles(),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          // ── Version footer ────────────────────────────────────────────────
          Center(
            child: Text(
              _appVersion.isEmpty
                  ? 'PetСпутник'
                  : 'PetСпутник [ $_appVersion ]',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade500,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Sync status card ────────────────────────────────────────────────────────

class _SyncCard extends StatelessWidget {
  final CloudSyncService sync;
  final bool isAuthenticated;
  final Color primaryColor;
  final VoidCallback onPushAll;
  final VoidCallback onPullAll;

  const _SyncCard({
    required this.sync,
    required this.isAuthenticated,
    required this.primaryColor,
    required this.onPushAll,
    required this.onPullAll,
  });

  Color get _statusColor {
    if (!isAuthenticated) return Colors.grey.shade400;
    switch (sync.status) {
      case SyncStatus.idle:
        return Colors.grey.shade400;
      case SyncStatus.syncing:
        return Colors.amber.shade600;
      case SyncStatus.success:
        return Colors.green.shade500;
      case SyncStatus.error:
        return Colors.red.shade400;
    }
  }

  String get _statusLabel {
    if (!isAuthenticated) return 'Требуется вход в аккаунт';
    switch (sync.status) {
      case SyncStatus.idle:
        return sync.lastSync != null
            ? _formatSync(sync.lastSync!)
            : 'Нет данных';
      case SyncStatus.syncing:
        return 'Синхронизация…';
      case SyncStatus.success:
        return sync.lastSync != null ? _formatSync(sync.lastSync!) : 'Готово';
      case SyncStatus.error:
        return sync.lastError ?? 'Ошибка синхронизации';
    }
  }

  String _formatSync(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин. назад';
    if (diff.inHours < 24) return '${diff.inHours} ч. назад';
    return DateFormat('d MMM, HH:mm', 'ru_RU').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSync = isAuthenticated && !sync.isSyncing;

    return GlassPlate(
      padding: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──────────────────────────────────────────────────
            Row(
              children: [
                // Coloured cloud icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _statusColor.withAlpha(30),
                  ),
                  child: Icon(
                    sync.status == SyncStatus.syncing
                        ? Icons.cloud_sync_outlined
                        : Icons.cloud_outlined,
                    color: _statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Облачная синхронизация',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _statusLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: sync.status == SyncStatus.error
                              ? Colors.red.shade400
                              : Colors.grey.shade500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Spinning indicator while syncing
                if (sync.isSyncing)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.amber.shade600,
                      ),
                    ),
                  ),
              ],
            ),

            // ── Action buttons (only when authenticated) ─────────────────────
            if (isAuthenticated) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  // Push all
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: canSync ? onPushAll : null,
                      icon: const Icon(Icons.upload_outlined, size: 16),
                      label: const Text('Загрузить на сервер'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryColor,
                        side: BorderSide(color: primaryColor.withAlpha(80)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        textStyle: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Pull all
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: canSync ? onPullAll : null,
                      icon: const Icon(Icons.download_outlined, size: 16),
                      label: const Text('Скачать с сервера'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade600,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        textStyle: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── User account card ────────────────────────────────────────────────────────

class _UserAccountCard extends StatelessWidget {
  final UserProfile? user;
  final Color primaryColor;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _UserAccountCard({
    required this.user,
    required this.primaryColor,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ac = context.watch<AppearanceController>();
    final hasUser = user != null;

    return GlassPlate(
      padding: 0,
      child: Pressable(
        onTap: onTap,
        haptic: HapticStrength.light,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor.withAlpha(30),
                  border: Border.all(
                    color: primaryColor.withAlpha(80),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  hasUser ? Icons.person_rounded : Icons.person_outline,
                  color: primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasUser ? user!.name : 'Войти в аккаунт',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasUser
                          ? _subtitle(user!)
                          : 'Синхронизация и резервные копии',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: ac.secondaryColor.withAlpha(160),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Badge / chevron
              if (!hasUser)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: primaryColor.withAlpha(25),
                  ),
                  child: Text(
                    'Войти',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else ...[
                if (user!.emailVerified)
                  Icon(
                    Icons.verified_outlined,
                    color: ThemeColors.ok.mainColor,
                    size: 18,
                  ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  color: ac.secondaryColor.withAlpha(120),
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle(UserProfile u) {
    final parts = <String>[];
    if (u.email.isNotEmpty) parts.add(u.email);
    if (u.city.isNotEmpty) parts.add(u.city);
    if (parts.isEmpty) return 'Профиль заполнен';
    return parts.join(' · ');
  }
}

// ─── Pet profile row ──────────────────────────────────────────────────────────

class _PetRow extends StatelessWidget {
  final Pet profile;
  final bool isLast;
  final VoidCallback? onTap;

  const _PetRow({required this.profile, this.isLast = false, this.onTap});

  String _ageLabel() {
    if (profile.birthDate == null) return profile.species.name;
    final duration = DateTime.now().difference(profile.birthDate!);
    return '${profile.species.emoji} ${formatPetAge(duration)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ac = context.watch<AppearanceController>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Pressable(
          onTap: onTap,
          haptic: HapticStrength.light,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // Mini avatar
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: profile.palette.mainColor.withAlpha(40),
                    border: Border.all(
                      color: profile.palette.mainColor,
                      width: 1.5,
                    ),
                  ),
                  child: ClipOval(
                    child: profile.profileImage != null
                        ? Image.file(profile.profileImage!, fit: BoxFit.cover)
                        : Center(
                            child: Text(
                              profile.species.emoji,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _ageLabel(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: ac.secondaryColor.withAlpha(160),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: ac.primaryColor.withAlpha(140),
                ),
              ],
            ),
          ),
        ),
        if (!isLast) SettingsCardDivider(),
      ],
    );
  }
}