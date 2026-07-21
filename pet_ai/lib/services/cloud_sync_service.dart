import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pet_satellite/services/api_service.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pet_satellite/models/event.dart';
import 'package:pet_satellite/models/meal.dart';
import 'package:pet_satellite/models/walk.dart';
import 'package:pet_satellite/models/mood.dart';
import 'package:pet_satellite/models/note.dart';
import 'package:pet_satellite/models/pill.dart';
import 'package:pet_satellite/models/treatment.dart';
import 'package:pet_satellite/models/weight.dart';
import 'package:pet_satellite/services/event_service.dart';
import 'package:pet_satellite/services/file_storage_service.dart';
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

  static const _syncEnabledKey = 'cloud_sync_enabled';
  static const _lastSyncKey = 'cloud_sync_last';

  /// Whether background sync to the server is enabled. Persisted across runs.
  /// While enabled (and authenticated) local changes are pushed to the server.
  /// Off by default — sync is opt-in and its toggle may be hidden behind a
  /// feature gate, so it must never turn on by itself after authentication.
  bool _syncEnabled = false;

  PocketBase get _pb => _pbService.pb;

  /// Whether the user is currently authenticated.
  bool get isAuthenticated => _pb.authStore.isValid;

  /// Whether background sync to the server is currently enabled.
  bool get syncEnabled => _syncEnabled;

  /// Loads the persisted [syncEnabled] preference and the last sync time.
  /// Call once at startup so the UI reflects state across restarts.
  Future<void> init() async {
    final prefs = SharedPreferencesAsync();
    _syncEnabled = (await prefs.getBool(_syncEnabledKey)) ?? false;
    final lastIso = await prefs.getString(_lastSyncKey);
    _lastSync = lastIso != null ? DateTime.tryParse(lastIso) : null;
    // Восстанавливаем «зелёный» статус, если синхронизация уже была.
    _status = _lastSync != null ? SyncStatus.success : SyncStatus.idle;
    notifyListeners();
  }

  /// Records a successful sync (now), persists it, and flips status to success.
  void _markSynced() {
    _lastSync = DateTime.now();
    SharedPreferencesAsync().setString(
      _lastSyncKey,
      _lastSync!.toIso8601String(),
    );
    _setStatus(SyncStatus.success);
  }

  /// Enables/disables background sync and persists the choice. Returns the new
  /// value. Pushing the current data on enable is left to the caller (so it can
  /// surface progress/errors in the UI).
  Future<void> setSyncEnabled(bool enabled) async {
    _syncEnabled = enabled;
    await SharedPreferencesAsync().setBool(_syncEnabledKey, enabled);
    notifyListeners();
  }

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
    if (!isAuthenticated || !_syncEnabled) return;

    final body = entity.toPocketBase(petId);
    final id = body['id'] as String?;

    _inFlight++;
    _setStatus(SyncStatus.syncing);

    _upsert(collection, id, body)
        .then((_) => _onInFlightDone())
        .catchError((Object e) => _onInFlightError(e));
  }

  /// Delete a single remote [id] from [collection] in the background.
  /// Silently ignores 404 (already deleted) and missing auth.
  void deleteAsync(String collection, String id) {
    if (!isAuthenticated || !_syncEnabled) return;

    _inFlight++;
    _setStatus(SyncStatus.syncing);

    _pb
        .collection(collection)
        .delete(id)
        .then((_) => _onInFlightDone())
        .catchError((Object e) {
          // 404 — запись уже отсутствует на сервере, это не ошибка.
          final code = e is ClientException ? e.statusCode : 0;
          if (code == 404) {
            _onInFlightDone();
          } else {
            _onInFlightError(e);
          }
        });
  }

  /// Create the record, falling back to update when it already exists.
  /// Makes pushes idempotent and lets edits (addOrReplace, saveEvent) update
  /// the same record instead of duplicating it.
  Future<void> _upsert(
    String collection,
    String? id,
    Map<String, dynamic> body,
  ) async {
    try {
      await _pb.collection(collection).create(body: body);
    } on ClientException catch (e) {
      // 400/409 при наличии id означает «запись уже существует» — обновляем.
      if (id != null && (e.statusCode == 400 || e.statusCode == 409)) {
        await _pb.collection(collection).update(id, body: body);
      } else {
        rethrow;
      }
    }
  }

  void _onInFlightDone() {
    _inFlight--;
    if (_inFlight == 0 && _status != SyncStatus.error) {
      _markSynced();
    }
  }

  void _onInFlightError(Object e) {
    _inFlight--;
    _lastError = _friendlyError(e);
    if (_inFlight == 0) _setStatus(SyncStatus.error);
  }

  // ── Documents ──────────────────────────────────────────────────────────────

  /// Uploads a document (with its file) to the `files` collection.
  /// Returns the created record id, or null on failure / no auth.
  ///
  /// Низкоуровневый метод: тумблер синхронизации здесь НЕ проверяется, потому
  /// что он переиспользуется явной полной выгрузкой ([pushAll]/[_syncDocuments]).
  /// Фоновая загрузка (добавление документа) должна проверять [syncEnabled] сама.
  Future<String?> pushDocument(PetDocument doc, String petId) async {
    if (!isAuthenticated) return null;
    try {
      final files = <http.MultipartFile>[];
      final f = File(doc.filePath);
      if (await f.exists()) {
        files.add(await http.MultipartFile.fromPath('file', doc.filePath));
      }
      final body = <String, dynamic>{
        'pet': petId,
        'caption': doc.name,
        'date': doc.date.toIso8601String(),
        if (doc.category != null) 'category': doc.category!.id,
      };
      final rec = await _pb
          .collection('files')
          .create(body: body, files: files);
      return rec.id;
    } catch (_) {
      return null;
    }
  }

  /// Downloads all documents for [petId] and replaces the local list.
  Future<void> _pullDocuments(String petId) async {
    try {
      final recs = await _pb
          .collection('files')
          .getFullList(filter: 'pet = "$petId"');
      final docs = <PetDocument>[];
      for (final r in recs) {
        final fname = r.data['file'] as String?;
        if (fname == null || fname.isEmpty) continue;
        final fileToken = await _pb.files.getToken();
        final resp = await http.get(
          _pb.files.getUrl(r, fname, token: fileToken),
        );
        if (resp.statusCode != 200) continue;
        final catId = r.data['category'] as String?;
        docs.add(
          await FileStorageService().buildDocumentFromRemote(
            petId: petId,
            remoteId: r.id,
            name: r.data['caption'] as String? ?? fname,
            date:
                DateTime.tryParse(r.data['date'] as String? ?? '') ??
                DateTime.now(),
            fileName: fname,
            bytes: resp.bodyBytes,
            category: (catId != null && catId.isNotEmpty)
                ? DocumentCategories.byId(catId)
                : null,
          ),
        );
      }
      await FileStorageService().importDocuments(petId, docs);
    } catch (_) {
      // Документы — некритичны: сбой не должен ронять остальной pull.
    }
  }

  // ── Chat ───────────────────────────────────────────────────────────────────

  /// Upserts a chat message into the `chats` collection. Returns the record id
  /// (new on first push, unchanged on update), or the original [remoteId] on
  /// failure / no auth — so the caller can retry later.
  ///
  /// Низкоуровневый метод: тумблер синхронизации здесь НЕ проверяется, потому
  /// что он переиспользуется явной полной выгрузкой
  /// ([AIChatController.pushAllThreadsToCloud]). Фоновый пуш сообщения
  /// ([AIChatController._pushMessage]) проверяет [syncEnabled] сам.
  Future<String?> pushChat({
    String? remoteId,
    required String thread,
    required String role,
    required String content,
    required DateTime timestamp,
    required bool completed,
    String? eventsJson,
  }) async {
    if (!isAuthenticated) return remoteId;
    final body = <String, dynamic>{
      'user': userId,
      'thread': thread,
      'role': role,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'completed': completed,
      'events_json': eventsJson ?? '',
    };
    try {
      if (remoteId == null) {
        final rec = await _pb.collection('chats').create(body: body);
        return rec.id;
      }
      await _pb.collection('chats').update(remoteId, body: body);
      return remoteId;
    } catch (_) {
      return remoteId;
    }
  }

  /// Fire-and-forget delete of a chat message.
  void deleteChat(String remoteId) => deleteAsync('chats', remoteId);

  /// Deletes all chat records for the current user (used by «clear history»).
  /// Уважает тумблер синхронизации: при выключенной синхронизации серверная
  /// копия чатов остаётся нетронутой (как замороженный бэкап).
  Future<void> deleteAllChats() async {
    if (!isAuthenticated || !_syncEnabled) return;
    await _deleteAllChatsRemote();
  }

  /// Безусловное (без учёта тумблера) удаление всех чатов пользователя.
  /// Используется [wipeRemote], которая замещает/очищает серверную копию и
  /// должна отрабатывать независимо от состояния синхронизации.
  Future<void> _deleteAllChatsRemote() async {
    if (!isAuthenticated) return;
    try {
      final recs = await _pb
          .collection('chats')
          .getFullList(filter: 'user = "$userId"');
      await Future.wait(recs.map((r) => _pb.collection('chats').delete(r.id)));
    } catch (_) {}
  }

  /// Удаляет с сервера чаты пользователя, id которых нет в [keepIds] —
  /// синхронизирует удаления, сделанные локально в офлайне. Ungated: часть
  /// явной полной выгрузки ([AIChatController.pushAllThreadsToCloud]).
  Future<void> deleteStaleChats(Set<String> keepIds) async {
    if (!isAuthenticated) return;
    try {
      final recs = await _pb
          .collection('chats')
          .getFullList(filter: 'user = "$userId"', fields: 'id');
      await _deleteStaleIds('chats', recs.map((r) => r.id), keepIds);
    } catch (_) {}
  }

  /// Fetches all chat records for the current user, oldest first.
  Future<List<RecordModel>> fetchChats() async {
    if (!isAuthenticated) return const [];
    try {
      return await _pb
          .collection('chats')
          .getFullList(filter: 'user = "$userId"', sort: 'timestamp');
    } catch (_) {
      return const [];
    }
  }

  // ── Full push ─────────────────────────────────────────────────────────────

  /// Upload **all** local data of the current user.
  ///
  /// Идемпотентно: каждая запись апсертится по своему стабильному id, после
  /// чего с сервера удаляются только записи, которых больше нет локально.
  /// До успешной загрузки ничего не стирается — обрыв посередине оставляет
  /// на сервере прежние данные (возможно, с частью уже обновлённых).
  /// Awaitable; throws on unrecoverable error.
  Future<void> pushAll() async {
    if (!isAuthenticated) return;
    _setStatus(SyncStatus.syncing);

    try {
      final uid = userId!;
      final pets = await PetProfileService().loadAllProfiles();
      if (pets.isEmpty) throw Exception('Нет профилей для выгрузки');

      // ── Питомцы + их история ──────────────────────────────────────────────
      for (final p in pets) {
        await _upsertPet(p, uid);

        await _syncCollection('weights', p.id, p.weightHistory.entries);
        await _syncCollection('moods', p.id, p.moodHistory.entries);
        await _syncCollection('meals', p.id, p.foodHistory.entries);
        await _syncCollection('walks', p.id, p.walkHistory.entries);
        await _syncCollection('notes', p.id, p.noteHistory.entries);
        await _syncCollection('treatments', p.id, p.treatmentHistory.entries);
        await _syncCollection('pills', p.id, p.pillReminders);

        // Документы питомца.
        await _syncDocuments(p.id);
      }

      // ── События (общие для нескольких питомцев — пушим один раз) ──────────
      final events = await EventService().loadAllEventsFlat();
      final eventIds = <String>{};
      for (final e in events) {
        if (e.petIds.isEmpty) continue;
        eventIds.add(e.id);
        await _upsert('events', e.id, e.toPocketBase(e.petIds.first));
      }
      for (final p in pets) {
        await _deleteStale('events', 'pets ~ "${p.id}"', eventIds);
      }

      // ── Питомцы, удалённые локально, удаляются и с сервера ────────────────
      final localPetIds = pets.map((p) => p.id).toSet();
      final remotePets = await _pb
          .collection(GetIt.instance<ApiService>().petsRoute)
          .getFullList(filter: 'user = "$uid"', fields: 'id');
      for (final r in remotePets) {
        if (!localPetIds.contains(r.id)) await _deleteRemotePet(r.id);
      }

      _markSynced();
    } catch (e) {
      _lastError = _friendlyError(e);
      _setStatus(SyncStatus.error);
      rethrow;
    }
  }

  // ── Check remote ──────────────────────────────────────────────────────────

  /// Returns `true` if the server holds **any** records for the current user.
  /// Сетевые ошибки проглатываются (→ false) — использовать там, где сбой
  /// проверки не должен ничего ломать (онбординг предлагает восстановление).
  Future<bool> checkHasRemoteData() async {
    if (!isAuthenticated) return false;
    try {
      return await hasRemoteData();
    } catch (_) {
      return false;
    }
  }

  /// Проверяет наличие серверных данных пользователя, **пробрасывая** ошибку
  /// сети. В отличие от [checkHasRemoteData], позволяет вызывающей стороне
  /// отличить «сервер пуст» от «не удалось проверить» — критично при включении
  /// синхронизации, где на основе ответа принимается решение о заливке/очистке.
  Future<bool> hasRemoteData() async {
    final uid = userId ?? '';
    final result = await _pb
        .collection(GetIt.instance<ApiService>().petsRoute)
        .getList(page: 1, perPage: 1, filter: 'user = "$uid"');
    return result.totalItems > 0;
  }

  /// Приводит серверную копию в соответствие с локальными данными: выгружает
  /// все локальные записи (идемпотентный апсерт) и удаляет с сервера то, чего
  /// нет локально. Если локальных профилей нет — полностью очищает сервер.
  /// Используется при включении синхронизации, когда пользователь решает
  /// заменить данные на сервере данными этого устройства.
  Future<void> replaceRemoteWithLocal() async {
    if (!isAuthenticated) return;
    final pets = await PetProfileService().loadAllProfiles();
    if (pets.isEmpty) {
      await wipeRemote();
    } else {
      await pushAll();
    }
  }

  /// Полностью удаляет серверную копию пользователя: питомцев со всей историей
  /// (moods/meals/notes/treatments/pills/events каскадятся при удалении
  /// питомца; weights и files — вручную) и все чаты.
  Future<void> wipeRemote() async {
    if (!isAuthenticated) return;
    _setStatus(SyncStatus.syncing);
    try {
      final uid = userId!;
      final pets = await _pb
          .collection(GetIt.instance<ApiService>().petsRoute)
          .getFullList(filter: 'user = "$uid"', fields: 'id');
      for (final r in pets) {
        await _deleteRemotePet(r.id);
      }
      await _deleteAllChatsRemote();
      _markSynced();
    } catch (e) {
      _lastError = _friendlyError(e);
      _setStatus(SyncStatus.error);
      rethrow;
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
      final pets = await PetProfileService().loadAllProfiles();
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
      // Идентичность питомца берём из облака (pull = overwrite local).
      RecordModel? petRecord;
      try {
        petRecord = await _pb.collection('pets').getOne(petId);
      } catch (_) {
        petRecord = null;
      }

      Pet? profile = await PetProfileService().loadProfile(petId);
      if (petRecord != null) {
        final remote = Pet.codec.fromPocketBase(petRecord.data);
        // Сохраняем уже скачанный локальный аватар, если на сервере его нет.
        remote.profileImage = profile?.profileImage;
        profile = remote;
      } else if (profile == null) {
        // Ни на сервере, ни локально — нечего восстанавливать.
        _setStatus(SyncStatus.error);
        return;
      }

      // Аватар из облака.
      final imageName = petRecord?.data['profile_image'] as String?;
      if (petRecord != null && imageName != null && imageName.isNotEmpty) {
        final path = await _downloadAvatar(petRecord, imageName, petId);
        if (path != null) profile.profileImage = File(path);
      }

      final petFilter = 'pet = "$petId"';

      final weightEntries = await _fetchAllAs(
        'weights',
        petFilter,
        WeightEntry.codec,
      );
      weightEntries.sort((a, b) => a.date.compareTo(b.date));
      profile.weightHistory = WeightHistory(entries: weightEntries);
      profile.moodHistory = MoodHistory(
        entries: await _fetchAllAs('moods', petFilter, MoodEntry.codec),
      );
      profile.foodHistory = MealHistory(
        entries: await _fetchAllAs('meals', petFilter, MealEntry.codec),
      );
      profile.walkHistory = WalkHistory(
        entries: await _fetchAllAs('walks', petFilter, WalkEntry.codec),
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
      profile.pillReminders = await _fetchAllAs('pills', petFilter, Pill.codec);

      await PetProfileService().saveProfile(profile);

      // ── Events ────────────────────────────────────────────────────────────
      final events = await _fetchAllAs(
        'events',
        'pets ~ "$petId"',
        Event.codec,
      );
      // Импортируем без обратного пуша (createEvent пушит в облако).
      await EventService().importEvents(petId, events);

      // ── Документы ─────────────────────────────────────────────────────────
      await _pullDocuments(petId);

      _markSynced();
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

      final existing = await PetProfileService().loadAllProfiles();
      final existingIds = existing.map((p) => p.id).toSet();
      final restoredIds = <String>[];

      for (final pet in pets) {
        try {
          if (!existingIds.contains(pet.id)) {
            await PetProfileService().saveProfile(pet);
          }
          restoredIds.add(pet.id);
        } catch (_) {}
      }

      if (restoredIds.isEmpty) {
        _setStatus(SyncStatus.idle);
        return;
      }

      await PetProfileService().setActiveProfile(restoredIds.first);

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

  /// Downloads the pet [filename] image of [record] and stores it as the local
  /// avatar for [petId]. Returns the saved path, or null on any failure.
  Future<String?> _downloadAvatar(
    RecordModel record,
    String filename,
    String petId,
  ) async {
    try {
      final fileToken = await _pb.files.getToken();
      final url = _pb.files.getUrl(record, filename, token: fileToken);
      final resp = await http.get(url);
      if (resp.statusCode != 200) return null;
      final dir = await getTemporaryDirectory();
      final tmp = File('${dir.path}/avatar_dl_$petId');
      await tmp.writeAsBytes(resp.bodyBytes);
      final saved = await PetProfileService().saveAvatar(petId, tmp.path);
      try {
        await tmp.delete();
      } catch (_) {}
      return saved;
    } catch (_) {
      return null;
    }
  }

  /// Fetch all records matching [filter] from [collection] and deserialize
  /// each one via [codec].
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

  /// Апсертит профиль питомца вместе с аватаром. Multipart-файл нельзя
  /// отправить дважды, поэтому для fallback-update он создаётся заново.
  Future<void> _upsertPet(Pet p, String uid) async {
    Future<List<http.MultipartFile>> avatar() async {
      final img = p.profileImage;
      if (img == null || !await img.exists()) return const [];
      return [await http.MultipartFile.fromPath('profile_image', img.path)];
    }

    try {
      await _pb
          .collection('pets')
          .create(body: p.toPocketBase(uid), files: await avatar());
    } on ClientException catch (e) {
      if (e.statusCode == 400 || e.statusCode == 409) {
        await _pb
            .collection('pets')
            .update(p.id, body: p.toPocketBase(uid), files: await avatar());
      } else {
        rethrow;
      }
    }
  }

  /// Апсертит записи [entries] в [collection] и удаляет с сервера записи
  /// этого питомца, которых больше нет локально.
  Future<void> _syncCollection(
    String collection,
    String petId,
    Iterable<PbEntity> entries,
  ) async {
    final localIds = <String>{};
    for (final e in entries) {
      final body = e.toPocketBase(petId);
      final id = body['id'] as String?;
      if (id != null) localIds.add(id);
      await _upsert(collection, id, body);
    }
    await _deleteStale(collection, 'pet = "$petId"', localIds);
  }

  /// Синхронизирует документы питомца: выгружает отсутствующие на сервере и
  /// удаляет с сервера записи, которых больше нет локально.
  Future<void> _syncDocuments(String petId) async {
    final storage = FileStorageService();
    final docs = await storage.loadDocuments(petId);

    final remote = await _pb
        .collection('files')
        .getFullList(filter: 'pet = "$petId"', fields: 'id');
    final remoteIds = remote.map((r) => r.id).toSet();

    var changed = false;
    for (final doc in docs) {
      // remoteId может указывать на запись, удалённую с другого устройства —
      // такой документ выгружается заново.
      if (doc.remoteId != null && remoteIds.contains(doc.remoteId)) continue;
      final rid = await pushDocument(doc, petId);
      if (rid != null && rid != doc.remoteId) {
        doc.remoteId = rid;
        changed = true;
      }
    }
    if (changed) await storage.importDocuments(petId, docs);

    final keep = docs.map((d) => d.remoteId).whereType<String>().toSet();
    await _deleteStaleIds('files', remoteIds, keep);
  }

  /// Удаляет из [collection] записи по [filter], id которых нет в [keepIds].
  Future<void> _deleteStale(
    String collection,
    String filter,
    Set<String> keepIds,
  ) async {
    final remote = await _pb
        .collection(collection)
        .getFullList(filter: filter, fields: 'id');
    await _deleteStaleIds(collection, remote.map((r) => r.id), keepIds);
  }

  Future<void> _deleteStaleIds(
    String collection,
    Iterable<String> remoteIds,
    Set<String> keepIds,
  ) async {
    for (final id in remoteIds) {
      if (keepIds.contains(id)) continue;
      try {
        await _pb.collection(collection).delete(id);
      } on ClientException catch (e) {
        // 404 — запись уже отсутствует на сервере, это не ошибка.
        if (e.statusCode != 404) rethrow;
      }
    }
  }

  /// Удаляет питомца с сервера вместе с weights и files — эти коллекции не
  /// каскадятся при удалении питомца (`cascadeDelete: false` в схеме).
  Future<void> _deleteRemotePet(String petId) async {
    for (final col in const ['weights', 'files']) {
      await _deleteStale(col, 'pet = "$petId"', const {});
    }
    await _pb.collection(GetIt.instance<ApiService>().petsRoute).delete(petId);
  }

  /// Fire-and-forget удаление питомца со всей историей из облака (при удалении
  /// профиля). Уважает тумблер синхронизации; ошибки проглатываются, чтобы не
  /// блокировать локальное удаление. Если питомец удалён при выключенной
  /// синхронизации — он уедет с сервера при следующей полной выгрузке.
  Future<void> deletePetRemote(String petId) async {
    if (!isAuthenticated || !_syncEnabled) return;
    try {
      await _deleteRemotePet(petId);
    } catch (_) {}
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
