import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pet_satellite/pages/secondary_pages/appearance_page.dart';
import 'package:pet_satellite/pages/secondary_pages/profile_page.dart';
import 'package:pet_satellite/services/ai_service.dart';
import 'package:pet_satellite/services/event_service.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:pet_satellite/theme/widgets/glass_widgets.dart';
import 'package:provider/provider.dart';
import '../../services/pet_profile_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  List<PetProfile> _profiles = [];
  bool _loadingProfiles = true;

  // Notification stubs
  bool _remindersEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final profiles = await ProfileService().loadAllProfiles();
    if (mounted) {
      setState(() {
        _profiles = profiles;
        _loadingProfiles = false;
      });
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
    if (!await _confirmClear(
      context,
      content: 'Будут удалены все события питомца.',
    )) {
      return;
    }

    final profileId = await ProfileService().getActiveProfileId();
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

    final profileId = await ProfileService().getActiveProfileId();
    if (profileId != null) {
      await ProfileService().clearWeightHistory(profileId);
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
          // ── User account (entry point — not yet implemented) ──────────────
          _UserAccountCard(primaryColor: ac.primaryColor),
          const SizedBox(height: 24),

          // ── Питомцы ──────────────────────────────────────────────────────
          _SectionLabel('Питомцы'),
          const SizedBox(height: 8),
          _SettingsCard(
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
                      await ProfileService().setActiveProfile(p.id);
                      await ac.reloadProfile();
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PetProfilePage(),
                          ),
                        );
                      }
                    },
                  );
                }),
                _SettingsRow(
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

          // ── Уведомления ───────────────────────────────────────────────────
          _SectionLabel('Уведомления'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              // Toggle row
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.notifications_outlined,
                      color: ac.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Напоминания',
                            style: theme.textTheme.bodyMedium,
                          ),
                          Text(
                            'Прививки, корм, прогулки',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: ac.secondaryColor.withAlpha(160),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _remindersEnabled,
                      activeThumbColor: ac.primaryColor,
                      onChanged: (v) => setState(() => _remindersEnabled = v),
                    ),
                  ],
                ),
              ),
              _Divider(),
              _SettingsRow(
                icon: Icons.bedtime_outlined,
                label: 'Тихие часы',
                subtitle: '22:00 – 08:00',
                onTap: null, // stub
                iconColor: ac.primaryColor,
              ),
              _Divider(),
              _SettingsRow(
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

          // ── Оформление ────────────────────────────────────────────────────
          _SectionLabel('Оформление'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              _SettingsRow(
                icon: Icons.palette_outlined,
                label: 'Тема и цвета',
                subtitle: 'Оформление приложения',
                iconColor: ac.primaryColor,
                trailingIcon: Icons.chevron_right,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AppearancePage()),
                ),
              ),
              _Divider(),
              _SettingsRow(
                icon: Icons.language_outlined,
                label: 'Язык',
                subtitle: 'Русский',
                onTap: null, // stub
                iconColor: ac.primaryColor,
              ),
              _Divider(),
              _SettingsRow(
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

          // ── Данные и приватность ─────────────────────────────────────────
          _SectionLabel('Данные и приватность'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              _SettingsRow(
                icon: Icons.cloud_outlined,
                label: 'Облачная синхронизация',
                subtitle: 'Скоро',
                onTap: null, // stub
                iconColor: ac.primaryColor,
              ),
              _Divider(),
              _SettingsRow(
                icon: Icons.download_outlined,
                label: 'Экспорт данных',
                subtitle: 'Скоро',
                onTap: null, // stub
                iconColor: ac.primaryColor,
              ),
              _Divider(),
              _SettingsRow(
                icon: Icons.fingerprint,
                label: 'Биометрия при входе',
                onTap: null, // stub
                iconColor: ac.primaryColor,
                last: true,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── О приложении ─────────────────────────────────────────────────
          _SectionLabel('О приложении'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              _SettingsRow(
                icon: Icons.help_outline,
                label: 'Помощь и FAQ',
                onTap: null, // stub
                iconColor: ac.primaryColor,
                trailingIcon: Icons.chevron_right,
              ),
              _Divider(),
              _SettingsRow(
                icon: Icons.star_outline,
                label: 'Оценить приложение',
                onTap: null, // stub
                iconColor: ac.primaryColor,
                trailingIcon: Icons.chevron_right,
              ),
              _Divider(),
              _SettingsRow(
                icon: Icons.shield_outlined,
                label: 'Условия и конфиденциальность',
                onTap: null, // stub
                iconColor: ac.primaryColor,
                trailingIcon: Icons.chevron_right,
              ),
              _Divider(),
              _SettingsRow(
                icon: Icons.logout,
                label: 'Выйти из аккаунта',
                onTap: null, // stub
                iconColor: ThemeColors.dangerZone,
                labelColor: ThemeColors.dangerZone,
                last: true,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Debug ─────────────────────────────────────────────────────────
          if (kDebugMode) ...[
            _SectionLabel('Отладка'),
            const SizedBox(height: 8),
            _SettingsCard(
              children: [
                _SettingsRow(
                  icon: Icons.delete_forever,
                  label: 'Очистить все данные',
                  subtitle: 'Сброс SharedPreferences',
                  iconColor: Colors.red,
                  labelColor: Colors.red,
                  onTap: () => _clearAppData(context),
                ),
                _Divider(),
                _SettingsRow(
                  icon: Icons.delete_forever,
                  label: 'Очистить события',
                  iconColor: Colors.red,
                  onTap: () => _clearEvents(context),
                ),
                _Divider(),
                _SettingsRow(
                  icon: Icons.delete_forever,
                  label: 'Очистить историю веса',
                  iconColor: Colors.red,
                  onTap: () => _clearWeightHistory(context),
                ),
                _Divider(),
                _SettingsRow(
                  icon: Icons.delete_forever,
                  label: 'Очистить историю настроения',
                  iconColor: Colors.red,
                  onTap: () => _clearMoodHistory(context),
                ),
                _Divider(),
                _SettingsRow(
                  icon: Icons.delete_forever,
                  label: 'Очистить диалог с ИИ',
                  iconColor: Colors.red,
                  onTap: () => _clearMessageHistory(context),
                ),
                _Divider(),
                _SettingsRow(
                  icon: Icons.data_object,
                  label: 'Заполнить историю веса',
                  iconColor: Colors.blue,
                  onTap: () {
                    ProfileService().fillWeightHistory();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('История веса заполнена')),
                    );
                  },
                  last: true,
                ),
                _SettingsRow(
                  icon: Icons.data_object,
                  label: 'Экспорт данных',
                  iconColor: Colors.blue,
                  onTap: () async => await ProfileService().exportAllProfiles(),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          // ── Version footer ────────────────────────────────────────────────
          Center(
            child: Text(
              'pet_ai · v 0.3.4 · сделано с 🐾',
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

// ─── User account card (entry point) ─────────────────────────────────────────

class _UserAccountCard extends StatelessWidget {
  final Color primaryColor;
  const _UserAccountCard({required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ac = context.watch<AppearanceController>();

    return GlassPlate(
      child: Row(
        children: [
          // Avatar placeholder
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primaryColor.withAlpha(30),
              border: Border.all(color: primaryColor.withAlpha(80), width: 1.5),
            ),
            child: Icon(Icons.person_outline, color: primaryColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Войдите в аккаунт',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Синхронизация и резервные копии',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: ac.secondaryColor.withAlpha(160),
                  ),
                ),
              ],
            ),
          ),
          // Entry point badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: primaryColor.withAlpha(30),
            ),
            child: Text(
              'Скоро',
              style: theme.textTheme.bodySmall?.copyWith(
                color: primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: context.watch<AppearanceController>().secondaryColor,
        ),
      ),
    );
  }
}

// ─── Settings card ────────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return GlassPlate(
      padding: 0,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

// ─── Pet profile row ──────────────────────────────────────────────────────────

class _PetRow extends StatelessWidget {
  final PetProfile profile;
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
        InkWell(
          onTap: onTap,
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
        if (!isLast) _Divider(),
      ],
    );
  }
}

// ─── Generic settings row ─────────────────────────────────────────────────────

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color? iconColor;
  final Color? labelColor;
  final IconData? trailingIcon;
  final VoidCallback? onTap;
  final bool last;

  const _SettingsRow({
    required this.icon,
    required this.label,
    this.subtitle,
    this.iconColor,
    this.labelColor,
    this.trailingIcon,
    this.onTap,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ac = context.watch<AppearanceController>();
    final effectiveIconColor = iconColor ?? ac.primaryColor;

    return InkWell(
      onTap: onTap,
      borderRadius: last
          ? const BorderRadius.vertical(bottom: Radius.circular(20))
          : BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: effectiveIconColor),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: labelColor,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: ac.secondaryColor.withAlpha(160),
                      ),
                    ),
                ],
              ),
            ),
            if (trailingIcon != null)
              Icon(
                trailingIcon,
                size: 18,
                color: ac.primaryColor.withAlpha(140),
              )
            else if (onTap != null)
              Icon(
                Icons.chevron_right,
                size: 18,
                color: ac.primaryColor.withAlpha(80),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Thin divider ─────────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 16,
      endIndent: 0,
      color: Theme.of(context).dividerColor.withAlpha(60),
    );
  }
}
