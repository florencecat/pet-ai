import 'package:flutter/material.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:provider/provider.dart';

/// Подпись пустого состояния: текст + инлайновая кнопка «Добавить ›».
///
/// Свёрстано на [Wrap], а не на [Row]: длинная подпись переносится по словам,
/// а если кнопка перестаёт помещаться в строку — уезжает на следующую. Так
/// вёрстка не ломается ни на длинных лейблах, ни на узких экранах.
class EmptyStateLabel extends StatelessWidget {
  final String message;
  final String? createMessage;
  final VoidCallback onCreateTap;

  const EmptyStateLabel({
    super.key,
    required this.message,
    this.createMessage,
    required this.onCreateTap,
  });

  @override
  Widget build(BuildContext context) {
    final appearance = context.watch<AppearanceController>();
    final titleStyle = Theme.of(context).textTheme.titleLarge!;

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: titleStyle.copyWith(
            inherit: true,
            color: appearance.secondaryColor.withAlpha(60),
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(padding: const EdgeInsets.all(5)),
          onPressed: onCreateTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 1,
            children: [
              // Flexible — чтобы длинный createMessage сжимался, а не выдавливал
              // шеврон за границу кнопки.
              Flexible(
                child: Text(
                  createMessage ?? 'Добавить',
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle.copyWith(
                    inherit: true,
                    color: appearance.primaryColor.withAlpha(192),
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 28),
            ],
          ),
        ),
      ],
    );
  }
}
