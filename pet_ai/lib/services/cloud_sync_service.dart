import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pet_satellite/models/event.dart';
import 'package:pet_satellite/models/meal.dart';
import 'package:pet_satellite/models/mood.dart';
import 'package:pet_satellite/models/note.dart';
import 'package:pet_satellite/models/pill_reminder.dart';
import 'package:pet_satellite/models/treatment.dart';
import 'package:pet_satellite/models/weight.dart';
import 'package:pet_satellite/services/event_service.dart';
import 'package:pet_satellite/services/pb_service.dart';
import 'package:pet_satellite/services/pet_profile_service.dart';

// ─── Status ───────────────────────────────────────────────────────────────────

enum SyncStatus { idle, syncing, success, error }

// ─── Service ──────────────────────────────────────────────────────────────────

/// Singleton cloud-sync service.
///
/// Registration in GetIt (call once at app start):
/// ```dart
/// GetIt.instance.registerSingleton<CloudSyncService>(
///   CloudSyncService(pbService: GetIt.instance<PocketBaseService>()),
/// );
/// ```
///
/// Quick access from anywhere:
/// ```dart
/// CloudSyncService.instance.pushAsync('weights', entry.toJson(), petId: id);
/// ```
///
/// PocketBase schema required for every collection:
///   - `user_id`  (text, indexed)
///   - `pet_id`   (text, indexed)
///   - `data`     (json / text) — full serialised model
///
/// The local model ID is submitted as the PocketBase record ID to make
/// pushes naturally idempotent (duplicate create → 400, silently ignored).
class CloudSyncService extends ChangeNotifier {
  final PocketBaseService _pbService;

  CloudSyncService({required PocketBaseService pbService})
      : _pbService = pbService;

  /// Convenience accessor — avoids passing the instance through the widget tree.
  static CloudSyncService get instance => GetIt.instance<CloudSyncService>();

  static const _collections = [
    'pets',
    'events',
    'weights',
    'moods',
    'meals',
    'notes',
    'treatments',
    'pills',
  ];

  // ── State ─────────────────────────────────────────────────────────────────

  SyncStatus _status = SyncStatus.idle;
  DateTime? _lastSync;
  String? _lastError;

  /// Number of fire-and-forget calls currently in-flight.
  int _inFlight = 0;

  PocketBase get _pb => _pbService.pb;

  /// Whether the user is currently authenticated.
  bool get isAuthenticated => _pb.authStore.isValid;

  /// PocketBase user-record ID of the authenticated user, or null.
  String? get userId => _pb.authStore.record?.id;

  SyncStatus get status => _status;
  DateTime? get lastSync => _lastSync;

  /// Human-readable error from the last failed operation. Null when healthy.
  String? get lastError => _lastError;

  bool get isSyncing => _status == SyncStatus.syncing;

  // ── Fire-and-forget push ──────────────────────────────────────────────────

  /// Push a single [record] to PocketBase [collection] in the background.
  ///
  /// - Silently does nothing when the user is not authenticated.
  /// - Uses the record's `id` field as the PocketBase record ID so that
  ///   retries / duplicate pushes are safe (409 → silently ignored).
  /// - Updates [status] and [lastSync] reactively via [notifyListeners].
  void pushAsync(
    String collection,
    Map<String, dynamic> record, {
    String? petId,
  }) {
    if (!isAuthenticated) return;

    final String? localId = record['id'] as String?;
    final body = <String, dynamic>{
      if (localId != null && localId.isNotEmpty) 'id': localId,
      'user_id': userId ?? '',
      if (petId != null && petId.isNotEmpty) 'pet_id': petId,
      'data': jsonEncode(record),
    };

    _inFlight++;
    _setStatus(SyncStatus.syncing);

    _pb
        .collection(collection)
        .create(body: body)
        .then((_) {
          _inFlight--;
          if (_inFlight == 0) {
            _lastSync = DateTime.now();
            _setStatus(SyncStatus.success);
          }
        })
        .catchError((Object e) {
          _inFlight--;
          // 400/409 typically means duplicate (already on server) — not an error
          // from the user's perspective for fire-and-forget push.
          final code = e is ClientException ? e.statusCode : 0;
          if (code != 400 && code != 409) {
            _lastError = _friendlyError(e);
            if (_inFlight == 0) _setStatus(SyncStatus.error);
          } else {
            if (_inFlight == 0 && _status != SyncStatus.error) {
              _lastSync = DateTime.now();
              _setStatus(SyncStatus.success);
            }
          }
        });
  }

  // ── Full push ─────────────────────────────────────────────────────────────

  /// Upload **all** local data for [petId].
  ///
  /// Clears existing remote data for this user first, then re-uploads the
  /// full local state. Awaitable; throws on unrecoverable error.
  Future<void> pushAll(String petId) async {
    if (!isAuthenticated) return;
    _setStatus(SyncStatus.syncing);

    try {
      final uid = userId!;
      final profile = await PetService().loadProfile(petId);
      if (profile == null) throw Exception('Профиль с id=$petId не найден');

      // Wipe remote state for this user, then re-upload everything.
      await _deleteRemoteForUser(uid);

      Future<void> push(String col, Map<String, dynamic> data) =>
          _pb.collection(col).create(body: data);

      final pets = await PetService().loadAllProfiles();
      for (final p in pets) {
        await push('pets', p.toPocketBase(uid));
      }

      // Events
      final events = await EventService().loadEvents(petId);
      for (final e in events) {
        await push('events', e.toPocketBase());
      }
      // Weights
      for (final e in profile.weightHistory.entries) {
        await push('weights', e.toJson());
      }
      // Moods
      for (final e in profile.moodHistory.entries) {
        await push('moods', e.toJson());
      }
      // Meals
      for (final e in profile.foodHistory.entries) {
        await push('meals', e.toJson());
      }
      // Notes
      for (final e in profile.noteHistory.entries) {
        await push('notes', e.toJson());
      }
      // Treatments
      for (final e in profile.treatmentHistory.entries) {
        await push('treatments', e.toJson());
      }
      // Pills
      for (final r in profile.pillReminders) {
        await push('pills', r.toJson());
      }

      _lastSync = DateTime.now();
      _setStatus(SyncStatus.success);
    } catch (e) {
      _lastError = _friendlyError(e);
      _setStatus(SyncStatus.error);
      rethrow;
    }
  }

  // ── Check remote ──────────────────────────────────────────────────────────

  /// Returns `true` if the server holds **any** records for the current user.
  Future<bool> checkHasRemoteData() async {
    if (!isAuthenticated) return false;
    final uid = userId ?? '';
    try {
      for (final c in _collections) {
        final result = await _pb.collection(c).getList(
          page: 1,
          perPage: 1,
          filter: 'user_id = "$uid"',
        );
        if (result.totalItems > 0) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── Full pull ─────────────────────────────────────────────────────────────

  /// Download all remote data for the current user and **overwrite** the local
  /// data of [petId]. **Local data is replaced without recovery.**
  Future<void> pullAll(String petId) async {
    if (!isAuthenticated) return;
    _setStatus(SyncStatus.syncing);

    try {
      final uid = userId!;
      final profile = await PetService().loadProfile(petId);
      if (profile == null) throw Exception('Профиль с id=$petId не найден');

      // ── Weights ──────────────────────────────────────────────────────────
      final weightData = await _fetchAll('weights', uid);
      profile.weightHistory = WeightHistory(
        entries: weightData.map(WeightEntry.fromJson).toList(),
      );

      // ── Moods ─────────────────────────────────────────────────────────────
      final moodData = await _fetchAll('moods', uid);
      profile.moodHistory = MoodHistory(
        entries: moodData.map(MoodEntry.fromJson).toList(),
      );

      // ── Meals ─────────────────────────────────────────────────────────────
      final mealData = await _fetchAll('meals', uid);
      profile.foodHistory = MealHistory(
        entries: mealData.map(MealEntry.fromJson).toList(),
      );

      // ── Notes ─────────────────────────────────────────────────────────────
      final noteData = await _fetchAll('notes', uid);
      profile.noteHistory = NoteHistory(
        entries: noteData.map(NoteEntry.fromJson).toList(),
      );

      // ── Treatments ────────────────────────────────────────────────────────
      final treatmentData = await _fetchAll('treatments', uid);
      profile.treatmentHistory = TreatmentHistory(
        entries: treatmentData.map(TreatmentEntry.fromJson).toList(),
      );

      // ── Pills ─────────────────────────────────────────────────────────────
      final pillData = await _fetchAll('pills', uid);
      profile.pillReminders = pillData.map(PillReminder.fromJson).toList();

      await PetService().saveProfile(profile);

      // ── Events ────────────────────────────────────────────────────────────
      // Use EventService's public API: clear existing, then create each.
      final eventData = await _fetchAll('events', uid);
      await EventService().clearEvents(petId);
      for (final d in eventData) {
        try {
          final event = Event.fromJson(d);
          // Ensure the pet is associated even if the record came from elsewhere.
          if (!event.petIds.contains(petId)) event.petIds.add(petId);
          await EventService().createEvent(event);
        } catch (_) {}
      }

      _lastSync = DateTime.now();
      _setStatus(SyncStatus.success);
    } catch (e) {
      _lastError = _friendlyError(e);
      _setStatus(SyncStatus.error);
      rethrow;
    }
  }

  // ── Full restore (new device) ─────────────────────────────────────────────

  /// Полное восстановление на новом устройстве:
  /// 1. Получает все профили питомцев из коллекции `pets`.
  /// 2. Создаёт их локально (только если не существуют).
  /// 3. Для каждого питомца вызывает [pullAll] чтобы восстановить историю.
  ///
  /// Вызывается из онбординга создания питомца после успешной авторизации.
  /// Если питомцы восстановлены — активный профиль выставляется первому.
  Future<void> fullRestore() async {
    if (!isAuthenticated) return;
    _setStatus(SyncStatus.syncing);

    try {
      final uid = userId!;

      // ── 1. Восстанавливаем профили питомцев ──────────────────────────────
      final petData = await _fetchAll('pets', uid);
      if (petData.isEmpty) {
        _setStatus(SyncStatus.idle);
        return;
      }

      final existing = await PetService().loadAllProfiles();
      final existingIds = existing.map((p) => p.id).toSet();
      final restoredIds = <String>[];

      for (final d in petData) {
        try {
          // fromJson reconstructs the full model; profileImage path is ignored
          // (local file doesn't exist on a new device).
          final pet = Pet.fromJson({
            ...d,
            'profileImage': null,   // can't restore a local file path
            'weightHistory': [],
            'moodHistory': [],
            'noteHistory': [],
            'treatmentHistory': [],
            'foodHistory': [],
            'pillReminders': [],
          });

          if (!existingIds.contains(pet.id)) {
            await PetService().saveProfile(pet);
          }
          restoredIds.add(pet.id);
        } catch (_) {}
      }

      if (restoredIds.isEmpty) {
        _setStatus(SyncStatus.idle);
        return;
      }

      // Set the first restored pet as active.
      await PetService().setActiveProfile(restoredIds.first);

      // ── 2. Восстанавливаем историю для каждого питомца ───────────────────
      for (final petId in restoredIds) {
        await pullAll(petId);
      }

    } catch (e) {
      _lastError = _friendlyError(e);
      _setStatus(SyncStatus.error);
      rethrow;
    }
  }

  // ── Misc ──────────────────────────────────────────────────────────────────

  /// Dismiss the last error and reset to idle / last-success state.
  void clearError() {
    _lastError = null;
    _status = _lastSync != null ? SyncStatus.success : SyncStatus.idle;
    notifyListeners();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Fetch all records for [uid] from [collection], returning the decoded
  /// `data` JSON payload of each record (the original serialised model).
  Future<List<Map<String, dynamic>>> _fetchAll(
    String collection,
    String uid,
  ) async {
    final items = <Map<String, dynamic>>[];
    int page = 1;
    const perPage = 200;
    while (true) {
      final result = await _pb.collection(collection).getList(
        page: page,
        perPage: perPage,
        filter: 'user_id = "$uid"',
      );
      for (final r in result.items) {
        try {
          final raw = r.data['data'];
          final Map<String, dynamic> decoded = raw is String
              ? jsonDecode(raw) as Map<String, dynamic>
              : (raw as Map<String, dynamic>);
          items.add(decoded);
        } catch (_) {}
      }
      if (result.items.length < perPage) break;
      page++;
    }
    return items;
  }

  /// Delete all records in every collection that belong to [uid].
  Future<void> _deleteRemoteForUser(String uid) async {
    for (final c in _collections) {
      try {
        while (true) {
          String filter;
          if (c == 'pets') {
            filter = 'user = "$uid"';
          } else if (c == 'events') {
            filter = 'pets.user ?= "$uid"';
          } else {
            filter = 'pet.user = "$uid"';
          }

          final result = await _pb.collection(c).getList(
            page: 1,
            perPage: 200,
            filter: filter,
          );
          if (result.items.isEmpty) break;
          await Future.wait(
            result.items.map((item) => _pb.collection(c).delete(item.id)),
          );
          if (result.items.length < 200) break;
        }
      } catch (_) {
        // Ignore per-collection failures; continue with the rest.
      }
    }
  }

  static String _friendlyError(Object e) {
    if (e is ClientException) {
      if (e.statusCode == 0) return 'Нет подключения к сети';
      return 'Ошибка сервера (${e.statusCode})';
    }
    return 'Неизвестная ошибка';
  }

  void _setStatus(SyncStatus s) {
    _status = s;
    notifyListeners();
  }
}
