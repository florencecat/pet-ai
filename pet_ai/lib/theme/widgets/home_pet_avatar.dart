import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pet_satellite/models/pet_profile.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/services/pet_profile_service.dart';
import 'package:pet_satellite/theme/widgets/draggable_sheets/pet_image_source_sheet.dart';
import 'package:pet_satellite/theme/widgets/image_preview_dialog.dart';
import 'package:pet_satellite/theme/widgets/pressable.dart';
import 'package:pet_satellite/theme/widgets/settings_widgets.dart';
import 'package:provider/provider.dart';

String _heroTag(Pet pet) => 'home-pet-avatar-${pet.id}';

/// Круглый аватар питомца заданного диаметра (рамка + фото/иконка).
/// Единый Hero-ребёнок: используется и в шапке главной, и в раскрытом оверлее.
Widget petAvatarCircle(
  BuildContext context,
  Pet pet,
  double diameter, {
  bool glow = true,
}) {
  final petColor = pet.palette.mainColor;
  final borderWidth = (diameter * 0.035).clamp(2.0, 4.0).toDouble();
  final hasPhoto = pet.profileImage != null;
  return Container(
    width: diameter,
    height: diameter,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white,
      border: Border.all(color: petColor, width: borderWidth),
      boxShadow: glow
          ? [
              BoxShadow(
                color: petColor.withAlpha(80),
                blurRadius: diameter * 0.14,
                spreadRadius: 1,
              ),
            ]
          : null,
    ),
    child: ClipOval(
      child: hasPhoto
          ? Image.file(
              pet.profileImage!,
              width: diameter,
              height: diameter,
              fit: BoxFit.cover,
            )
          : Center(
              child: Icon(Icons.pets, size: diameter * 0.5, color: petColor),
            ),
    ),
  );
}

/// Hero аватара с «дорогой» анимацией: прямая траектория (а не дуга Material по
/// умолчанию) и пропорциональное масштабирование без сжатия. Оба прямоугольника
/// квадратные, поэтому [RectTween] держит кадр квадратным на всём пути, а
/// flightShuttle перерисовывает кружок ровно под текущий размер.
Hero _avatarHero(
  BuildContext context,
  Pet pet,
  double diameter, {
  bool glow = true,
}) {
  return Hero(
    tag: _heroTag(pet),
    createRectTween: (begin, end) => RectTween(begin: begin, end: end),
    flightShuttleBuilder:
        (flightContext, animation, direction, fromCtx, toCtx) {
          return LayoutBuilder(
            builder: (ctx, constraints) {
              final d = math.min(constraints.maxWidth, constraints.maxHeight);
              return petAvatarCircle(ctx, pet, d, glow: false);
            },
          );
        },
    child: petAvatarCircle(context, pet, diameter, glow: glow),
  );
}

/// Аватар питомца в шапке главного экрана: адаптивный размер, прикреплённый к
/// аватарке шеврон-переключатель и Hero для анимации раскрытия по нажатию.
class HomePetAvatar extends StatelessWidget {
  final Pet pet;
  final double diameter;
  final bool multipleProfiles;

  /// Показывать ли шеврон-переключатель. Скрываем на время раскрытия аватара,
  /// чтобы он не оставался «висеть» на месте, пока аватар летит в центр.
  final bool showSwitcher;

  /// Нажатие по самой аватарке — раскрытие в центр (см. [showPetAvatarExpand]).
  final VoidCallback onTapAvatar;

  /// Нажатие по шеврону — меню выбора/создания питомца.
  final VoidCallback onTapSwitcher;

  const HomePetAvatar({
    super.key,
    required this.pet,
    required this.diameter,
    required this.multipleProfiles,
    required this.onTapAvatar,
    required this.onTapSwitcher,
    this.showSwitcher = true,
  });

  @override
  Widget build(BuildContext context) {
    final chevron = (diameter * 0.34).clamp(10.0, 25.0).toDouble();
    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Pressable(
            scale: 0.95,
            haptic: HapticStrength.selection,
            onTap: onTapAvatar,
            child: _avatarHero(context, pet, diameter),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: AnimatedOpacity(
              opacity: showSwitcher ? 1 : 0,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              child: IgnorePointer(
                ignoring: !showSwitcher,
                child: Pressable(
                  scale: 0.9,
                  haptic: HapticStrength.light,
                  onTap: onTapSwitcher,
                  child: Container(
                    width: chevron,
                    height: chevron,
                    decoration: BoxDecoration(
                      color: context.watch<AppearanceController>().petColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      multipleProfiles ? Icons.expand_more_rounded : Icons.add,
                      size: chevron * 0.6,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Раскрывает аватар питомца: он «улетает» в центр и увеличивается (Hero),
/// фон затемняется, снизу появляются действия «Посмотреть / Поменять фото».
/// Возвращает `true`, если фото было изменено (нужно обновить экран).
Future<bool?> showPetAvatarExpand(BuildContext context, Pet pet) {
  return Navigator.of(context).push<bool>(
    PageRouteBuilder<bool>(
      opaque: false,
      barrierColor: Colors.transparent,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, animation, _) =>
          _PetAvatarExpanded(pet: pet, animation: animation),
      transitionsBuilder: (_, _, _, child) => child,
    ),
  );
}

class _PetAvatarExpanded extends StatefulWidget {
  final Pet pet;
  final Animation<double> animation;

  const _PetAvatarExpanded({required this.pet, required this.animation});

  @override
  State<_PetAvatarExpanded> createState() => _PetAvatarExpandedState();
}

class _PetAvatarExpandedState extends State<_PetAvatarExpanded> {
  Pet get _pet => widget.pet;
  bool _changed = false;

  void _viewPhoto() {
    final file = _pet.profileImage;
    if (file == null) return;
    showDialog<void>(
      context: context,
      builder: (_) => ImagePreviewDialog(file: file, title: _pet.name),
    );
  }

  Future<void> _changePhoto() async {
    final source = await showPetImageSourceSheet(context);
    if (source == null || !mounted) return;
    final path = await PetProfileService().pickProfileImage(_pet.id, source: source);
    if (path == null || !mounted) return;
    _pet.profileImage = File(path);
    await PetProfileService().saveProfile(_pet);
    if (!mounted) return;
    _changed = true;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final big = math.min(media.size.width, media.size.height) * 0.55;
    final hasPhoto = _pet.profileImage != null;

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).maybePop(_changed),
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: widget.animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
          child: Stack(
            children: [
              const Positioned.fill(
                child: ColoredBox(color: Color(0xAA000000)),
              ),
              SafeArea(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Поглощаем тап по аватарке, чтобы фон-дисмисс не срабатывал.
                      GestureDetector(
                        onTap: () {},
                        child: _avatarHero(context, _pet, big, glow: false),
                      ),
                      SizedBox(height: 20),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 250),
                        child: _AvatarActions(
                          hasPhoto: hasPhoto,
                          onView: _viewPhoto,
                          onChange: _changePhoto,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Компактное стеклянное меню действий под раскрытым аватаром — в стиле
/// настроек приложения (GlassPlate + строки).
class _AvatarActions extends StatelessWidget {
  final bool hasPhoto;
  final VoidCallback onView;
  final VoidCallback onChange;

  const _AvatarActions({
    required this.hasPhoto,
    required this.onView,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      transparent: false,
      children: [
        if (hasPhoto) ...[
          SettingsRow(
            icon: Icons.visibility_outlined,
            label: 'Посмотреть фото',
            onTap: onView,
            trailing: const SizedBox.shrink(),
          ),
          const SettingsCardDivider(),
        ],
        SettingsRow(
          icon: Icons.photo_camera_outlined,
          label: 'Поменять фото',
          onTap: onChange,
          trailing: const SizedBox.shrink(),
          last: true,
        ),
      ],
    );
  }
}
