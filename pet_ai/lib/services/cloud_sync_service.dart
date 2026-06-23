import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';
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
    if (!isAuthenticated) return;

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
      _lastSync = DateTime.now();
      _setStatus(SyncStatus.success);
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
        final resp = await http.get(_pb.files.getUrl(r, fname));
        if (resp.statusCode != 200) continue;
        final catId = r.data['category'] as String?;
        docs.add(
          await FileStorageService().buildDocumentFromRemote(
            petId: petId,
            remoteId: r.id,
            name: r.data['caption'] as String? ?? fname,
            date: DateTime.tryParse(r.data['date'] as String? ?? '') ??
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
  Future<void> deleteAllChats() async {
    if (!isAuthenticated) return;
    try {
      final recs = await _pb
          .collection('chats')
          .getFullList(filter: 'user = "$userId"');
      await Future.wait(recs.map((r) => _pb.collection('chats').delete(r.id)));
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

  /// Upload **all** local data for [petId].
  ///
  /// Clears existing remote data for this user first, then re-uploads the
  /// full local state. Awaitable; throws on unrecoverable error.
  Future<void> pushAll(String petId) async {
    if (!isAuthenticated) return;
    _setStatus(SyncStatus.syncing);

    try {
      final uid = userId!;
      final pets = await PetService().loadAllProfiles();
      if (pets.isEmpty) throw Exception('Нет профилей для выгрузки');

      // Wipe remote state for this user, then re-upload everything.
      await _deleteRemoteForUser(uid);

      Future<void> push(String col, Map<String, dynamic> data) =>
          _pb.collection(col).create(body: data);

      // ── Питомцы + их история ──────────────────────────────────────────────
      for (final p in pets) {
        final files = <http.MultipartFile>[];
        if (p.profileImage != null && await p.profileImage!.exists()) {
          files.add(
            await http.MultipartFile.fromPath(
              'profile_image',
              p.profileImage!.path,
            ),
          );
        }
        await _pb
            .collection('pets')
            .create(body: p.toPocketBase(uid), files: files);

        for (final e in p.weightHistory.entries) {
          await push('weights', e.toPocketBase(p.id));
        }
        for (final e in p.moodHistory.entries) {
          await push('moods', e.toPocketBase(p.id));
        }
        for (final e in p.foodHistory.entries) {
          await push('meals', e.toPocketBase(p.id));
        }
        for (final e in p.noteHistory.entries) {
          await push('notes', e.toPocketBase(p.id));
        }
        for (final e in p.treatmentHistory.entries) {
          await push('treatments', e.toPocketBase(p.id));
        }
        for (final r in p.pillReminders) {
          await push('pills', r.toPocketBase(p.id));
        }

        // Документы питомца.
        final docs = await FileStorageService().loadDocuments(p.id);
        for (final doc in docs) {
          final rid = await pushDocument(doc, p.id);
          if (rid != null && doc.remoteId != rid) {
            doc.remoteId = rid;
          }
        }
        if (docs.isNotEmpty) {
          await FileStorageService().importDocuments(p.id, docs);
        }
      }

      // ── События (общие для нескольких питомцев — пушим один раз) ──────────
      final events = await EventService().loadAllEventsFlat();
      for (final e in events) {
        if (e.petIds.isEmpty) continue;
        await push('events', e.toPocketBase(e.petIds.first));
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
      // Идентичность питомца берём из облака (pull = overwrite local).
      RecordModel? petRecord;
      try {
        petRecord = await _pb.collection('pets').getOne(petId);
      } catch (_) {
        petRecord = null;
      }

      Pet? profile = await PetService().loadProfile(petId);
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
      // Импортируем без обратного пуша (createEvent пушит в облако).
      await EventService().importEvents(petId, events);

      // ── Документы ─────────────────────────────────────────────────────────
      await _pullDocuments(petId);

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

  /// Downloads the pet [filename] image of [record] and stores it as the local
  /// avatar for [petId]. Returns the saved path, or null on any failure.
  Future<String?> _downloadAvatar(
    RecordModel record,
    String filename,
    String petId,
  ) async {
    try {
      final url = _pb.files.getUrl(record, filename);
      final resp = await http.get(url);
      if (resp.statusCode != 200) return null;
      final dir = await getTemporaryDirectory();
      final tmp = File('${dir.path}/avatar_dl_$petId');
      await tmp.writeAsBytes(resp.bodyBytes);
      final saved = await PetService().saveAvatar(petId, tmp.path);
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

  /// Delete all records belonging to [uid]. Deleting a pet cascades to moods,
  /// meals, notes, treatments, pills and events — but **not** weights
  /// (`cascadeDelete: false` in the schema), so those are removed explicitly
  /// to avoid orphaned duplicates on the next push.
  Future<void> _deleteRemoteForUser(String uid) async {
    final petCollection = GetIt.instance<ApiService>().petsRoute;
    final pets = await _pb
        .collection(petCollection)
        .getFullList(filter: 'user = "$uid"');
    if (pets.isEmpty) return;

    for (final p in pets) {
      // weights и files не каскадятся при удалении питомца — чистим вручную.
      for (final col in const ['weights', 'files']) {
        final items = await _pb
            .collection(col)
            .getFullList(filter: 'pet = "${p.id}"');
        await Future.wait(items.map((i) => _pb.collection(col).delete(i.id)));
      }
    }

    await Future.wait(
      pets.map((p) => _pb.collection(petCollection).delete(p.id)),
    );
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
