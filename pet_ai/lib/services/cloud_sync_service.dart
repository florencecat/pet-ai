import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:pet_satellite/services/api_service.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pet_satellite/models/event.dart';
import 'package:pet_satellite/models/meal.dart';
import 'package:pet_satellite/models/mood.dart';
import 'package:pet_satellite/models/note.dart';
import 'package:pet_satellite/models/pill.dart';
import 'package:pet_satellite/models/treatment.dart';
import 'package:pet_satellite/models/weight.dart';
import 'package:pet_satellite/services/event_service.dart';
import 'package:pet_satellite/services/pb_service.dart';
import 'package:pet_satellite/services/pet_profile_service.dart';
import 'package:pet_satellite/models/pet_profile.dart';
import 'package:http/http.dart' as http;

enum SyncStatus { idle, syncing, success, error }

class CloudSyncService extends ChangeNotifier {
  final PocketBaseService _pbService;

  CloudSyncService({required PocketBaseService pbService})
    : _pbService = pbService;

  /// Convenience accessor — avoids passing the instance through the widget tree.
  static CloudSyncService get instance => GetIt.instance<CloudSyncService>();

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
  void pushAsync(String collection, PbEntity entity, String petId) {
    if (!isAuthenticated) return;

    _inFlight++;
    _setStatus(SyncStatus.syncing);

    _pb
        .collection(collection)
        .create(body: entity.toPocketBase(petId))
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
        List<http.MultipartFile> files = [];
        if (p.profileImage != null) {
          files.add(await http.MultipartFile.fromPath('profile_image', p.profileImage!.path));
        }
        _pb.collection('pets').create(body: p.toPocketBase(uid), files: files);
      }

      // Events
      final events = await EventService().loadEvents(petId);
      for (final e in events) {
        await push('events', e.toPocketBase(petId));
      }
      // Weights
      for (final e in profile.weightHistory.entries) {
        await push('weights', e.toPocketBase(petId));
      }
      // Moods
      for (final e in profile.moodHistory.entries) {
        await push('moods', e.toPocketBase(petId));
      }
      // Meals
      for (final e in profile.foodHistory.entries) {
        await push('meals', e.toPocketBase(petId));
      }
      // Notes
      for (final e in profile.noteHistory.entries) {
        await push('notes', e.toPocketBase(petId));
      }
      // Treatments
      for (final e in profile.treatmentHistory.entries) {
        await push('treatments', e.toPocketBase(petId));
      }
      // Pills
      for (final r in profile.pillReminders) {
        await push('pills', r.toPocketBase(petId));
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
      final result = await _pb
          .collection('pets')
          .getList(page: 1, perPage: 1, filter: 'user = "$uid"');
      return result.totalItems > 0;
    } catch (_) {
      return false;
    }
  }

  // ── Full pull ─────────────────────────────────────────────────────────────

  Future<List<String>> fetchAllPets() async {
    final pets = await _pb
        .collection(GetIt.instance<ApiService>().petsRoute)
        .getList(fields: 'id');
    return pets.items.map((item) => item.data['id'] as String).toList();
  }

  Future<void> pullAll() async {
    final petIds = await fetchAllPets();
    if (petIds.isEmpty) {
      final pets = await PetService().loadAllProfiles();
      petIds.addAll(pets.map((p) => p.id));
    }
    for (final petId in petIds) {
      await pullAllByPetId(petId);
    }
  }

  /// Download all remote data for the current user and **overwrite** the local
  /// data of [petId]. **Local data is replaced without recovery.**
  Future<void> pullAllByPetId(String petId) async {
    if (!isAuthenticated) return;
    _setStatus(SyncStatus.syncing);

    try {
      Pet? profile = await PetService().loadProfile(petId);
      if (profile == null) {
        profile = await _fetchAs('pets', 'id = "$petId"', Pet.codec);
        if (profile == null) {
          _setStatus(SyncStatus.error);
          return;
        }
        PetService().saveProfile(profile);
      }

      final petFilter = 'pet = "$petId"';

      profile.weightHistory = WeightHistory(
        entries: await _fetchAllAs('weights', petFilter, WeightEntry.codec),
      );
      profile.moodHistory = MoodHistory(
        entries: await _fetchAllAs('moods', petFilter, MoodEntry.codec),
      );
      profile.foodHistory = MealHistory(
        entries: await _fetchAllAs('meals', petFilter, MealEntry.codec),
      );
      profile.noteHistory = NoteHistory(
        entries: await _fetchAllAs('notes', petFilter, NoteEntry.codec),
      );
      profile.treatmentHistory = TreatmentHistory(
        entries: await _fetchAllAs(
          'treatments',
          petFilter,
          TreatmentEntry.codec,
        ),
      );
      profile.pillReminders = await _fetchAllAs(
        'pills',
        petFilter,
        Pill.codec,
      );

      await PetService().saveProfile(profile);

      // ── Events ────────────────────────────────────────────────────────────
      final events = await _fetchAllAs(
        'events',
        'pets ~ "$petId"',
        Event.codec,
      );
      await EventService().clearEvents(petId);
      for (final event in events) {
        try {
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
  /// 3. Для каждого питомца вызывает [pullAllByPetId] чтобы восстановить историю.
  ///
  /// Вызывается из онбординга создания питомца после успешной авторизации.
  /// Если питомцы восстановлены — активный профиль выставляется первому.
  Future<void> fullRestore() async {
    if (!isAuthenticated) return;
    _setStatus(SyncStatus.syncing);

    try {
      final uid = userId!;

      // ── 1. Восстанавливаем профили питомцев ──────────────────────────────
      final pets = await _fetchAllAs('pets', 'user = "$uid"', Pet.codec);
      if (pets.isEmpty) {
        _setStatus(SyncStatus.idle);
        return;
      }

      final existing = await PetService().loadAllProfiles();
      final existingIds = existing.map((p) => p.id).toSet();
      final restoredIds = <String>[];

      for (final pet in pets) {
        try {
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

      await PetService().setActiveProfile(restoredIds.first);

      // ── 2. Восстанавливаем историю для каждого питомца ───────────────────
      for (final petId in restoredIds) {
        await pullAllByPetId(petId);
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

  /// Fetch all records matching [filter] from [collection] and deserialize
  /// each one via [codec].
  Future<T?> _fetchAs<T extends PbEntity>(
    String collection,
    String filter,
    PbCodec<T> codec,
  ) async {
    int page = 1;
    const perPage = 200;
    final result = await _pb
        .collection(collection)
        .getList(page: page, perPage: perPage, filter: filter);
    if (result.totalItems == 0) {
      return null;
    }
    return codec.fromPocketBase(result.items.first.data);
  }

  Future<List<T>> _fetchAllAs<T extends PbEntity>(
    String collection,
    String filter,
    PbCodec<T> codec,
  ) async {
    final items = <T>[];
    int page = 1;
    const perPage = 200;
    while (true) {
      final result = await _pb
          .collection(collection)
          .getList(page: page, perPage: perPage, filter: filter);
      for (final r in result.items) {
        try {
          items.add(codec.fromPocketBase(r.data));
        } catch (_) {}
      }
      if (result.items.length < perPage) break;
      page++;
    }
    return items;
  }

  /// Delete all records in every collection that belong to [uid].
  Future<void> _deleteRemoteForUser(String uid) async {
    final petCollection = GetIt.instance<ApiService>().petsRoute;
    final result = await _pb
        .collection(petCollection)
        .getList(page: 1, perPage: 200, filter: 'user = "$uid"');
    if (result.items.isEmpty) return;
    await Future.wait(
      result.items.map((item) => _pb.collection(petCollection).delete(item.id)),
    );
    if (result.items.length < 200) return;
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
