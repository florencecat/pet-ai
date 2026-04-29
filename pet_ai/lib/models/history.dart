enum HistoryPeriod { day, month, year, all }

abstract class BaseEntry {
  DateTime get date;

  Map<String, dynamic> toJson();
}

class History<T extends BaseEntry> {
  final List<T> entries;

  History({required this.entries});
  History.empty() : entries = [];

  void add(T entry) {
    entries.add(entry);
  }

  void deleteEntry(DateTime date) {
    entries.removeWhere((e) => e.date == date);
  }

  void clear() => entries.clear();

  T? get lastEntry {
    if (entries.isEmpty) return null;
    return entries.last;
  }



  List<T> filterByPeriod(HistoryPeriod period) {
    final now = DateTime.now();

    switch (period) {
      case HistoryPeriod.day:
        final start = DateTime(now.year, now.month, now.day);
        return entries.where((e) => e.date.isAfter(start)).toList();

      case HistoryPeriod.month:
        final start = now.subtract(const Duration(days: 30));
        return entries.where((e) => e.date.isAfter(start)).toList();

      case HistoryPeriod.year:
        final start = DateTime(now.year - 1, now.month, now.day);
        return entries.where((e) => e.date.isAfter(start)).toList();

      case HistoryPeriod.all:
        return entries;
    }
  }
}

class HistorySerializer<T extends BaseEntry> {
  final T Function(Map<String, dynamic>) fromJson;

  HistorySerializer({required this.fromJson});

  History<T> fromJsonList(List<dynamic> json) {
    return History(
      entries: json.map((e) => fromJson(e)).toList(),
    );
  }

  List<Map<String, dynamic>> toJsonList(History<T> history) {
    return history.entries.map((e) => e.toJson()).toList();
  }
}