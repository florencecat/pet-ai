import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pet_satellite/models/event.dart';
import 'package:pet_satellite/models/history.dart';
import 'package:pet_satellite/services/pb_service.dart';
import 'package:pet_satellite/services/event_service.dart';
import 'package:pet_satellite/services/pet_profile_service.dart';

// ─── Предустановленные симптомы ──────────────────────────────────────────────

class SymptomTag {
  final String id;
  final String label;
  final IconData icon;
  final int colorValue;

  const SymptomTag({
    required this.id,
    required this.label,
    required this.icon,
    required this.colorValue,
  });

  Color get color => Color(colorValue);
}

class SymptomTags {
  static const vomiting = SymptomTag(
    id: 'lb18x8wz0uav3zs',
    label: 'Рвота',
    icon: Icons.sick_outlined,
    colorValue: 0xFFE53935,
  );
  static const diarrhea = SymptomTag(
    id: '65invddq8bmt3fm',
    label: 'Жидкий стул',
    icon: Icons.warning_amber_rounded,
    colorValue: 0xFFFF8F00,
  );
  static const refusedFood = SymptomTag(
    id: '2zxi8jlzyh649wm',
    label: 'Отказ от еды',
    icon: Icons.no_food_outlined,
    colorValue: 0xFFF57F17,
  );
  static const lethargy = SymptomTag(
    id: 'woakc6ce2ka3d41',
    label: 'Вялость',
    icon: Icons.bedtime_outlined,
    colorValue: 0xFF1565C0,
  );
  static const sneezing = SymptomTag(
    id: '1hk0ae4mfip81xu',
    label: 'Чихание',
    icon: Icons.air_outlined,
    colorValue: 0xFF6A1B9A,
  );
  static const coughing = SymptomTag(
    id: '6xstbg23me36gxw',
    label: 'Кашель',
    icon: Icons.masks_outlined,
    colorValue: 0xFF558B2F,
  );
  static const scratching = SymptomTag(
    id: '0at5r8rjmubktl7',
    label: 'Расчёсывается',
    icon: Icons.touch_app_outlined,
    colorValue: 0xFF00838F,
  );
  static const limping = SymptomTag(
    id: 'qsjy1av39qa33xq',
    label: 'Хромает',
    icon: Icons.accessible_forward_outlined,
    colorValue: 0xFF4E342E,
  );

  static const all = [
    vomiting,
    diarrhea,
    refusedFood,
    lethargy,
    sneezing,
    coughing,
    scratching,
    limping,
  ];

  static SymptomTag? byId(String id) {
    try {
      return all.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }
}

// ─── Тяжесть симптома ─────────────────────────────────────────────────────────

/// Насколько выражен симптом (макет 2e/2f): лёгкий / средний / сильный.
/// Опциональна — у заметок без явной оценки тяжести её нет.
enum SymptomSeverity { mild, moderate, severe }

extension SymptomSeverityX on SymptomSeverity {
  String get label {
    switch (this) {
      case SymptomSeverity.mild:
        return 'Лёгкий';
      case SymptomSeverity.moderate:
        return 'Средний';
      case SymptomSeverity.severe:
        return 'Сильный';
    }
  }

  /// «Вес» для сравнения нагрузки по симптому между периодами (динамика статуса).
  int get value {
    switch (this) {
      case SymptomSeverity.mild:
        return 1;
      case SymptomSeverity.moderate:
        return 2;
      case SymptomSeverity.severe:
        return 3;
    }
  }

  /// Цвет столбика на графике тяжести (палитра макета 2e).
  Color get chartColor {
    switch (this) {
      case SymptomSeverity.mild:
        return const Color(0xFFF0C9A0);
      case SymptomSeverity.moderate:
        return const Color(0xFFE8A25C);
      case SymptomSeverity.severe:
        return const Color(0xFFD95A43);
    }
  }

  /// Относительная высота столбика (33 % / 66 % / 100 %, как на макете).
  double get chartFraction {
    switch (this) {
      case SymptomSeverity.mild:
        return 0.34;
      case SymptomSeverity.moderate:
        return 0.66;
      case SymptomSeverity.severe:
        return 1.0;
    }
  }

  static SymptomSeverity? fromName(String? name) {
    if (name == null) return null;
    for (final s in SymptomSeverity.values) {
      if (s.name == name) return s;
    }
    return null;
  }
}

/// Направление динамики симптома для статус-карточки (макет 2e).
enum SymptomTrend { improving, worsening, steady, dormant }

/// Сводный статус по одному симптому: тренд, дней без записей, дата последнего
/// эпизода. Текст/иконку/цвет карточки собирает уже слой представления.
class SymptomStatus {
  final SymptomTrend trend;
  final int daysSinceLast;
  final DateTime? lastDate;
  final int episodeCount;

  const SymptomStatus({
    required this.trend,
    required this.daysSinceLast,
    required this.lastDate,
    required this.episodeCount,
  });
}

/// Один столбик графика тяжести: дата, худшая тяжесть за интервал (null — записей
/// не было) и необязательная подпись под столбиком (для помесячного вида).
class SymptomBar {
  final DateTime date;
  final SymptomSeverity? severity;
  final String? label;

  const SymptomBar({required this.date, this.severity, this.label});
}

// ─── Модель записи ────────────────────────────────────────────────────────────

class NoteEntry implements BaseEntry {
  static const codec = _NoteEntryCodec();

  @override
  final String id;
  @override
  final DateTime date;
  final String note;

  /// Если заметка создана по предустановленному симптому — его id, иначе null.
  final String? symptomId;

  /// Тяжесть симптома (только для заметок-симптомов, макет 2e/2f). null — не
  /// оценивалась (старые заметки, свободные наблюдения).
  final SymptomSeverity? severity;

  NoteEntry({
    String? id,
    required this.date,
    required this.note,
    this.symptomId,
    this.severity,
  }) : id = id ?? generateId();

  SymptomTag? get symptomTag =>
      symptomId != null ? SymptomTags.byId(symptomId!) : null;

  factory NoteEntry.fromJson(Map<String, dynamic> json) {
    return NoteEntry(
      id: json['id'] as String?,
      date: DateTime.parse(json['date']),
      note: json['note'],
      symptomId: json['symptomId'] as String?,
      severity: SymptomSeverityX.fromName(json['severity'] as String?),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'note': note,
    if (symptomId != null) 'symptomId': symptomId,
    if (severity != null) 'severity': severity!.name,
  };

  @override
  Map<String, dynamic> toPocketBase(String ownerId) => {
    'id': id,
    'pet': ownerId,
    'date': date.toIso8601String(),
    'note': note,
    if (symptomId != null) 'symptom': symptomId,
    if (severity != null) 'severity': severity!.name,
  };
}

class _NoteEntryCodec extends PbCodec<NoteEntry> {
  const _NoteEntryCodec();

  @override
  NoteEntry fromPocketBase(Map<String, dynamic> data) => NoteEntry(
    id: data['id'] as String?,
    date: DateTime.parse(data['date'] as String),
    note: data['note'] as String,
    symptomId: (data['symptom'] as String?)?.isEmpty ?? true
        ? null
        : data['symptom'] as String?,
    severity: SymptomSeverityX.fromName(data['severity'] as String?),
  );
}

class NoteHistory extends History<NoteEntry> {
  NoteHistory({required super.entries});
  NoteHistory.empty() : super.empty();

  Future<NoteEntry> addNote(
    String text, {
    String? symptomId,
    SymptomSeverity? severity,
  }) async {
    final date = DateTime.now();
    final entry = NoteEntry(
      date: date,
      note: text,
      symptomId: symptomId,
      severity: symptomId != null ? severity : null,
    );
    add(entry);

    final profileId = await PetProfileService().getActiveProfileId();
    if (profileId != null) {
      final eventFromNote = Event.fromNote(
        noteId: entry.id,
        name: text,
        dateTime: date,
        symptomTag: symptomId,
      );
      eventFromNote.petIds.add(profileId);
      await EventService().createEvent(eventFromNote);
    } else if (kDebugMode) {
      print('addNote: failed to get active profileId');
    }
    return entry;
  }

  // ─── Симптомы ──────────────────────────────────────────────────────────────
  // Трекер симптомов не хранит отдельную коллекцию: его записи — это заметки с
  // проставленным симптомом (те же, что заводятся на главном экране).

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Записи-симптомы: заметки с распознанным тегом и проставленной тяжестью.
  /// Их заводит только диалог симптома (макет 2f); быстрые заметки с главного
  /// экрана в трекер не попадают — логика заметок и симптомов разделена. Отсюда
  /// же следует, что тяжесть у записи трекера всегда есть (null не обрабатываем).
  List<NoteEntry> get symptomEntries => entries
      .where((e) => e.symptomTag != null && e.severity != null)
      .toList();

  /// Эпизоды одного симптома, от новых к старым.
  List<NoteEntry> entriesForSymptom(String tagId) =>
      symptomEntries.where((e) => e.symptomId == tagId).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  /// Симптомы, по которым есть записи за последние [days] дней — в порядке
  /// давности последнего эпизода (свежие слева). Это вкладки трекера. Если за
  /// период ничего нет, чтобы трекер не оставался пустым при наличии истории,
  /// откатываемся ко всем симптомам за всё время.
  List<SymptomTag> activeSymptomTags({int days = 30}) {
    final now = DateTime.now();
    final start = _dayKey(now).subtract(Duration(days: days - 1));
    final recent = _orderedTags(
      symptomEntries.where((e) => !e.date.isBefore(start)),
    );
    if (recent.isNotEmpty) return recent;
    return _orderedTags(symptomEntries);
  }

  /// Уникальные теги из [source], упорядоченные по самому свежему эпизоду.
  List<SymptomTag> _orderedTags(Iterable<NoteEntry> source) {
    final lastDate = <String, DateTime>{};
    for (final e in source) {
      final id = e.symptomId!;
      final prev = lastDate[id];
      if (prev == null || e.date.isAfter(prev)) lastDate[id] = e.date;
    }
    final ids = lastDate.keys.toList()
      ..sort((a, b) => lastDate[b]!.compareTo(lastDate[a]!));
    return ids.map(SymptomTags.byId).whereType<SymptomTag>().toList();
  }

  /// Статус по симптому: сравниваем «нагрузку» (сумму тяжестей, а без оценки —
  /// сам факт записи) за последние 7 дней с предыдущими 7 днями.
  SymptomStatus symptomStatus(String tagId) {
    final episodes = entriesForSymptom(tagId);
    if (episodes.isEmpty) {
      return const SymptomStatus(
        trend: SymptomTrend.dormant,
        daysSinceLast: 0,
        lastDate: null,
        episodeCount: 0,
      );
    }

    final now = DateTime.now();
    final last = episodes.first.date;
    final daysSinceLast = _dayKey(now).difference(_dayKey(last)).inDays;

    int loadBetween(DateTime from, DateTime to) => episodes
        .where((e) => !e.date.isBefore(from) && e.date.isBefore(to))
        .fold(0, (sum, e) => sum + e.severity!.value);

    final today = _dayKey(now).add(const Duration(days: 1));
    final week1Start = today.subtract(const Duration(days: 7));
    final week2Start = today.subtract(const Duration(days: 14));
    final recent = loadBetween(week1Start, today);
    final previous = loadBetween(week2Start, week1Start);

    final SymptomTrend trend;
    if (recent == 0) {
      trend = daysSinceLast >= 3 ? SymptomTrend.improving : SymptomTrend.dormant;
    } else if (recent > previous) {
      trend = SymptomTrend.worsening;
    } else if (recent < previous) {
      trend = SymptomTrend.improving;
    } else {
      trend = SymptomTrend.steady;
    }

    return SymptomStatus(
      trend: trend,
      daysSinceLast: daysSinceLast,
      lastDate: last,
      episodeCount: episodes.length,
    );
  }

  /// Столбики графика тяжести по дням за последние [days] дней (вид «Месяц»).
  /// Тяжесть дня — максимальная из эпизодов этого дня.
  List<SymptomBar> severityDailyBars(String tagId, {int days = 14}) {
    final episodes = entriesForSymptom(tagId);
    final now = _dayKey(DateTime.now());
    return List.generate(days, (i) {
      final day = now.subtract(Duration(days: days - 1 - i));
      final worst = _worstSeverity(
        episodes.where((e) => _sameDay(e.date, day)),
      );
      return SymptomBar(date: day, severity: worst);
    });
  }

  /// Столбики графика тяжести по месяцам (вид «Всё») — последние [months] мес.
  List<SymptomBar> severityMonthlyBars(String tagId, {int months = 12}) {
    const monthLabels = [
      'Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июн',
      'Июл', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек',
    ];
    final episodes = entriesForSymptom(tagId);
    final now = DateTime.now();
    return List.generate(months, (i) {
      final month = DateTime(now.year, now.month - (months - 1 - i), 1);
      final worst = _worstSeverity(
        episodes.where(
          (e) => e.date.year == month.year && e.date.month == month.month,
        ),
      );
      return SymptomBar(
        date: month,
        severity: worst,
        label: monthLabels[month.month - 1],
      );
    });
  }

  /// Самая тяжёлая оценка среди [source]; null — если записей в интервале нет.
  /// Все записи-симптомы гарантированно с тяжестью (см. [symptomEntries]).
  SymptomSeverity? _worstSeverity(Iterable<NoteEntry> source) {
    SymptomSeverity? worst;
    for (final e in source) {
      final s = e.severity!;
      if (worst == null || s.value > worst.value) worst = s;
    }
    return worst;
  }

  static final noteSerializer = HistorySerializer<NoteEntry>(
    fromJson: NoteEntry.fromJson,
  );
}
