import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pet_satellite/models/pet_profile.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/services/pet_profile_service.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:pet_satellite/theme/widgets/glass_widgets.dart';
import 'package:pet_satellite/theme/widgets/pressable.dart';

/// Открывает лист выбора активного профиля питомца и применяет результат:
/// переключает активного питомца или ведёт на регистрацию нового.
///
/// Смену вкладок/палитры/чата навешивать не нужно — [setActiveProfile] сигналит
/// о смене активного питомца, и MainPage обновляет все вкладки разом.
Future<void> showProfileSwitcher(BuildContext context) async {
  final profiles = await PetProfileService().loadAllProfiles();
  final activeId = await PetProfileService().getActiveProfileId();

  if (!context.mounted) return;

  final result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ProfileSwitcherSheet(profiles: profiles, activeId: activeId),
  );

  if (result == null) return;

  if (result == '__create_new__') {
    if (context.mounted) await Navigator.pushNamed(context, '/registration');
  } else {
    await PetProfileService().setActiveProfile(result);
  }
}

/// Лист со списком профилей питомцев + кнопкой создания нового. Возвращает id
/// выбранного профиля, `'__create_new__'` для нового, либо null при отмене.
class ProfileSwitcherSheet extends StatelessWidget {
  final List<Pet> profiles;
  final String? activeId;

  const ProfileSwitcherSheet({
    super.key,
    required this.profiles,
    required this.activeId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: ThemeColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Text('Профили питомцев', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),

          ...profiles.map((profile) {
            final isActive = profile.id == activeId;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: GlassPlate(
                color: isActive ? profile.palette.mainColor : Colors.white,
                child: Pressable(
                  haptic: HapticStrength.selection,
                  onTap: isActive
                      ? () => Navigator.pop(context)
                      : () => Navigator.pop(context, profile.id),
                  child: PetProfileService().buildProfileDescription(
                    context,
                    profile,
                    leading: PetProfileService().buildProfileAvatar(
                      context,
                      profile,
                      size: 22,
                    ),
                    trailing: isActive
                        ? const Icon(Icons.check_circle, color: Colors.white)
                        : null,
                    titleTheme: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      color: isActive
                          ? Colors.white
                          : context.watch<AppearanceController>().secondaryColor,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                    ),
                    subTitleTheme: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: isActive
                          ? Colors.white.withAlpha(204)
                          : context
                                .watch<AppearanceController>()
                                .secondaryColor
                                .withAlpha(153),
                    ),
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: GlassCard(
              callback: () => Navigator.pop(context, '__create_new__'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      color: context.watch<AppearanceController>().primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Добавить питомца',
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: context.watch<AppearanceController>().primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
