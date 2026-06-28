import 'package:flutter/material.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/theme/widgets/glass_widgets.dart';
import 'package:pet_satellite/theme/widgets/pressable.dart';
import 'package:provider/provider.dart';

class SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const SettingsCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return GlassPlate(
      padding: 0,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class SettingsRow extends StatelessWidget {
  final IconData? icon;
  final String label;
  final String? subtitle;
  final Color? iconColor;
  final Color? labelColor;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool last;

  const SettingsRow({super.key,
    required this.label,
    this.icon,
    this.subtitle,
    this.iconColor,
    this.labelColor,
    this.leading,
    this.trailing,
    this.onTap,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    assert(icon != null || leading != null);

    final theme = Theme.of(context);
    final ac = context.watch<AppearanceController>();
    final effectiveIconColor = iconColor ?? ac.primaryColor;

    return InkWell(
      onTap: onTap == null
          ? null
          : () {
        triggerHaptic(HapticStrength.light);
        onTap!();
      },
      borderRadius: last
          ? const BorderRadius.vertical(bottom: Radius.circular(20))
          : BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            leading ?? Icon(icon, size: 20, color: effectiveIconColor),
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
            const SizedBox(width: 14),
            if (trailing != null)
              trailing!
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

class SettingsSectionLabel extends StatelessWidget {
  final String title;
  const SettingsSectionLabel({super.key, required this.title});

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

class SettingsCardDivider extends StatelessWidget {
  const SettingsCardDivider({super.key});

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

Icon settingsChevronIcon(Color color) =>
    Icon(Icons.chevron_right, size: 18, color: color);
