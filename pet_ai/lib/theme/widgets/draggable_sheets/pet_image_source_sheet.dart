import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:pet_satellite/theme/widgets/glass_widgets.dart';
import 'package:provider/provider.dart';

/// Нижний лист выбора источника фото питомца: камера или галерея.
/// Единый лист — используется и на странице редактирования профиля, и в
/// контекстном меню аватара на главном экране.
Future<ImageSource?> showPetImageSourceSheet(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.watch<AppearanceController>().secondaryColor.withAlpha(120),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          Text('Фото питомца', style: Theme.of(context).textTheme.titleMedium),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              spacing: 8,
              children: [
                Expanded(
                  child: GlassSourceCard(
                    type: SourceCardType.camera,
                    color: ThemeColors.cameraImageSource,
                    onTap: () => Navigator.pop(ctx, ImageSource.camera),
                  ),
                ),
                Expanded(
                  child: GlassSourceCard(
                    type: SourceCardType.gallery,
                    color: ThemeColors.galleryImageSource,
                    onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
