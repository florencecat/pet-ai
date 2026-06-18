import 'dart:convert';

import 'package:pet_satellite/models/event.dart';
import 'package:pet_satellite/services/event_service.dart';

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

  Future<void> createSuggestedEvents() async {
    if (response.containsKey('events')) {
      final events = response['events'] as List<dynamic>? ?? [];
      if (events.isNotEmpty) {
        for (final event in events) {
          final newEvent = await Event.codec.fromAIResponse(event);
          if (newEvent != null) {
            EventService().createEvent(newEvent);
          }
        }
      }
    }
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