import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/theme/app_colors.dart';

const _skipDeleteKey = 'skip_delete_confirmation';

/// Включено ли подтверждение удаления (true = спрашивать).
Future<bool> isDeleteConfirmationEnabled() async =>
    !((await SharedPreferencesAsync().getBool(_skipDeleteKey)) ?? false);

/// Включить/выключить подтверждение удаления (используется из настроек).
Future<void> setDeleteConfirmationEnabled(bool enabled) async =>
    SharedPreferencesAsync().setBool(_skipDeleteKey, !enabled);

/// Показывает подтверждение удаления любой сущности с галочкой
/// «Больше не спрашивать».
///
/// Возвращает `true`, если удаление нужно выполнить. Если пользователь ранее
/// отметил «больше не спрашивать» — сразу возвращает `true` без диалога.
Future<bool> confirmDelete(
  BuildContext context, {
  String title = 'Удалить?',
  String? message,
  String confirmLabel = 'Удалить',
  bool ignorePreferences = false,
}) async {
  if (!ignorePreferences) {
    final skip =
        (await SharedPreferencesAsync().getBool(_skipDeleteKey)) ?? false;
    if (skip) return true;
  }
  if (!context.mounted) return false;

  final result = await showDialog<bool>(
    context: context,
    builder: (_) => _DeleteConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      useDontAsk: !ignorePreferences,
    ),
  );
  return result == true;
}

class _DeleteConfirmDialog extends StatefulWidget {
  final String title;
  final String? message;
  final String confirmLabel;
  final bool useDontAsk;

  const _DeleteConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.useDontAsk = true,
  });

  @override
  State<_DeleteConfirmDialog> createState() => _DeleteConfirmDialogState();
}

class _DeleteConfirmDialogState extends State<_DeleteConfirmDialog> {
  bool _dontAsk = false;

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<AppearanceController>().primaryColor;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.message != null) ...[
            Text(widget.message!),
            const SizedBox(height: 8),
          ],
          // «Больше не спрашивать»
          if (widget.useDontAsk) ...[
            InkWell(
              onTap: () => setState(() => _dontAsk = !_dontAsk),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _dontAsk,
                        activeColor: accent,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        onChanged: (v) => setState(() => _dontAsk = v ?? false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Больше не спрашивать',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: ThemeColors.dangerZone,
          ),
          onPressed: () async {
            if (_dontAsk) {
              await SharedPreferencesAsync().setBool(_skipDeleteKey, true);
            }
            if (context.mounted) Navigator.pop(context, true);
          },
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
