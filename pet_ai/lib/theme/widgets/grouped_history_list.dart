import 'package:flutter/material.dart';
import 'package:pet_satellite/models/history.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:pet_satellite/theme/widgets/glass_widgets.dart';

/// Список записей дневника, сгруппированный по календарной дате.
///
/// Каждая дата — отдельная сворачиваемая секция ([CollapsibleSection]).
/// Дата вынесена в заголовок группы, поэтому в самих плитках её показывать
/// не нужно. Группы идут от новых к старым; по умолчанию раскрыта верхняя.
///
/// [sortWithinGroup] задаёт порядок записей внутри одной даты. Если не задан —
/// записи сортируются от поздних к ранним по времени.
class GroupedHistoryList<T extends BaseEntry> extends StatefulWidget {
  final List<T> entries;
  final Widget Function(BuildContext context, T entry) itemBuilder;
  final int Function(T a, T b)? sortWithinGroup;

  /// Необязательная «шапка» группы — виджет под заголовком даты, над записями
  /// этого дня (например, сообщение о переходе на новый корм). Возврат null —
  /// шапки нет. [dayItems] уже отсортированы порядком группы.
  final Widget? Function(BuildContext context, DateTime day, List<T> dayItems)?
  groupHeaderBuilder;

  const GroupedHistoryList({
    super.key,
    required this.entries,
    required this.itemBuilder,
    this.sortWithinGroup,
    this.groupHeaderBuilder,
  });

  @override
  State<GroupedHistoryList<T>> createState() => _GroupedHistoryListState<T>();
}

class _GroupedHistoryListState<T extends BaseEntry>
    extends State<GroupedHistoryList<T>> {
  /// Ключи (дата) свёрнутых групп. По умолчанию все раскрыты, кроме явно
  /// добавленных сюда — так верхняя (новейшая) группа остаётся открытой.
  final Set<DateTime> _collapsed = {};

  DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    // Группируем по дню.
    final groups = <DateTime, List<T>>{};
    for (final e in widget.entries) {
      groups.putIfAbsent(_dayKey(e.date), () => []).add(e);
    }

    // Даты от новых к старым.
    final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    final compare =
        widget.sortWithinGroup ?? (T a, T b) => b.date.compareTo(a.date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < days.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final day = days[i];
              final items = groups[day]!..sort(compare);
              final expanded = !_collapsed.contains(day);
              final header = widget.groupHeaderBuilder?.call(
                context,
                day,
                items,
              );

              return CollapsibleSection(
                expanded: expanded,
                onToggle: () => setState(() {
                  if (expanded) {
                    _collapsed.add(day);
                  } else {
                    _collapsed.remove(day);
                  }
                }),
                titleContent: Row(
                  children: [
                    Flexible(
                      child: Text(
                        formatSmartDate(day, pattern: 'd MMMM yyyy'),
                        style: Theme.of(context).textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (!expanded) CountBadge(count: widget.entries.length),
                  ],
                ),
                body: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (header != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: header,
                      ),
                    for (final e in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: widget.itemBuilder(context, e),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
