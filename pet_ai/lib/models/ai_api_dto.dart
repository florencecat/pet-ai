import 'package:pet_satellite/models/suggested_event.dart';

class QuotaInfo {
  final int requestsToday;
  final int limitDay;
  final int limitMinute;
  final DateTime? nextRequestAt;

  QuotaInfo({
    required this.requestsToday,
    required this.limitDay,
    required this.limitMinute,
    this.nextRequestAt,
  });

  factory QuotaInfo.fromJson(Map<String, dynamic> j) => QuotaInfo(
    requestsToday: j['requests_today'] ?? 0,
    limitDay: j['limit_day'] ?? 0,
    limitMinute: j['limit_minute'] ?? 0,
    nextRequestAt: j['next_request_at'] != null
        ? DateTime.tryParse(j['next_request_at'])
        : null,
  );

  int get remainingToday => (limitDay - requestsToday).clamp(0, limitDay);
}

class ChatResult {
  final dynamic response;
  final bool cached;
  final QuotaInfo quota;

  ChatResult({required this.response, required this.cached, required this.quota});

  factory ChatResult.fromJson(Map<String, dynamic> j) => ChatResult(
    response: j['response'],
    cached: j['cached'] ?? false,
    quota: QuotaInfo.fromJson(j['quota'] ?? {}),
  );

  /// Извлекает предложенные ИИ события (`events`) из ответа. Само событие
  /// здесь не создаётся — этим управляет контроллер чата (с учётом настройки
  /// автосоздания и подтверждения пользователя).
  List<SuggestedEvent> suggestedEvents() {
    final r = response;
    if (r is Map && r['events'] is List) {
      return (r['events'] as List)
          .whereType<Map>()
          .map((m) => SuggestedEvent.fromAi(m.cast<String, dynamic>()))
          .toList();
    }
    return const [];
  }
}

class ApiError implements Exception {
  final int statusCode;
  final String code;
  final String message;
  final QuotaInfo? quota;

  ApiError({
    required this.statusCode,
    required this.code,
    required this.message,
    this.quota,
  });
}