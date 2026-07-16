import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:http/io_client.dart';
import 'package:pet_satellite/models/ai_api_dto.dart';
import 'package:pet_satellite/models/event.dart';
import 'package:pet_satellite/models/suggested_event.dart';
import 'package:pet_satellite/services/authentification_service.dart';
import 'package:pet_satellite/services/cloud_sync_service.dart';
import 'package:pet_satellite/services/event_service.dart';
import 'dart:convert';
import 'package:pet_satellite/services/http_client.dart';
import 'package:pet_satellite/services/pet_profile_service.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pet_satellite/models/pet_profile.dart';
part 'ai_service.g.dart';

@HiveType(typeId: 0)
class ChatMessage extends HiveObject {
  @HiveField(0)
  String role;

  @HiveField(1)
  String content;

  @HiveField(2)
  DateTime timestamp;

  /// Завершена ли трансляция («печать») ответа. Виджет предложенных событий
  /// показываем с анимацией только после окончания печати; флаг персистится,
  /// чтобы после перезапуска карточки не пропадали и не переанимировались.
  @HiveField(4)
  bool completed;

  /// Предложенные ИИ события для этого сообщения — JSON-список [SuggestedEvent].
  /// null, если событий нет. Храним строкой, чтобы не плодить Hive-адаптеры.
  @HiveField(3)
  String? eventsJson;

  /// id записи в коллекции `chats` PocketBase (для апсерта/дедупликации при
  /// синхронизации). null, пока сообщение не выгружено в облако.
  @HiveField(5)
  String? remoteId;

  ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.eventsJson,
    this.completed = false,
    this.remoteId,
  });

  /// Декодированный список предложенных событий (пустой, если их нет).
  List<SuggestedEvent> get attachedEvents =>
      eventsJson == null ? const [] : SuggestedEvent.decodeList(eventsJson!);

  set attachedEvents(List<SuggestedEvent> list) =>
      eventsJson = list.isEmpty ? null : SuggestedEvent.encodeList(list);
}

// ── Настройка автосоздания сущностей ──────────────────────────────────────────

const _autoCreateEntitiesKey = 'ai_auto_create_entities';

/// Создавать ли предложенные ИИ сущности автоматически, без подтверждения.
/// По умолчанию выключено — пользователь подтверждает каждое создание.
Future<bool> isAutoCreateEntitiesEnabled() async =>
    (await SharedPreferencesAsync().getBool(_autoCreateEntitiesKey)) ?? false;

Future<void> setAutoCreateEntitiesEnabled(bool value) async =>
    SharedPreferencesAsync().setBool(_autoCreateEntitiesKey, value);

class ArchivedThread {
  final String boxName;
  final DateTime date;
  final List<ChatMessage> messages;

  const ArchivedThread({
    required this.boxName,
    required this.date,
    required this.messages,
  });
}

/// Сущность, прикреплённая к сообщению (напоминание, заметка, прививка, …).
/// [data] уходит в тело запроса в формате JSON.
class ChatAttachment {
  final String type; // 'pill' | 'note' | 'treatment' | 'event' | ...
  final String label; // человекочитаемая подпись (для чипа)
  final IconData icon;
  final Color color;
  final Map<String, dynamic> data;

  const ChatAttachment({
    required this.type,
    required this.label,
    required this.icon,
    required this.color,
    required this.data,
  });
}

class ChatRepository {
  final Box<ChatMessage> box;

  ChatRepository(this.box);

  List<ChatMessage> get messages => box.isOpen ? box.values.toList() : [];

  Future<void> add(ChatMessage msg) async {
    await box.add(msg);
  }

  Future<void> clear() async {
    await box.clear();
  }
}

/// Внутреннее исключение для не-200 ответов сервера / пустого ответа.
class _ServerException implements Exception {
  final int statusCode;
  final String? message;
  const _ServerException(this.statusCode, [this.message]);
}

class AIChatController extends ChangeNotifier {
  static const _currentBoxKey = 'current_thread_box';
  static const _archivedBoxesKey = 'archived_threads';
  static const _defaultBoxName = 'chat_box';

  final String basePath;

  final Uri _healthRoute;
  final Uri _messagesRoute;

  late final IOClient _httpClient;

  ChatRepository? _repo;
  Pet? _pet;
  String _currentBoxName = _defaultBoxName;

  bool isLoading = false;
  bool isInitialized = false;

  /// Текст последней ошибки (сети/сервера/GigaChat). null — ошибок нет.
  String? _error;
  String? get error => _error;

  /// Текст последнего неудачного сообщения — для повторной отправки.
  String? _lastFailedText;
  bool get canRetry => _lastFailedText != null;

  /// Сущность, прикреплённая к следующему сообщению (ephemeral).
  ChatAttachment? _pendingAttachment;
  ChatAttachment? get pendingAttachment => _pendingAttachment;

  void setAttachment(ChatAttachment a) {
    _pendingAttachment = a;
    notifyListeners();
  }

  void clearAttachment() {
    _pendingAttachment = null;
    notifyListeners();
  }

  /// Активный профиль питомца (для пикера вложений).
  Pet? get pet => _pet;

  /// Имя текущего треда (для подсветки активного в истории).
  String get currentBoxName => _currentBoxName;

  AIChatController({required this.basePath})
    : _healthRoute = Uri.parse('$basePath/health'),
      _messagesRoute = Uri.parse('$basePath/chat');

  Future<void> init() async {
    isLoading = true;
    notifyListeners();

    try {
      _httpClient = await createIOClient();

      final prefs = await SharedPreferences.getInstance();
      _currentBoxName = prefs.getString(_currentBoxKey) ?? _defaultBoxName;

      final results = await Future.wait([
        PetProfileService().loadActiveProfile(),
        Hive.openBox<ChatMessage>(_currentBoxName),
      ]);

      final pet = results[0] as Pet?;
      var box = results[1] as Box<ChatMessage>;

      if (pet == null) {
        throw Exception('Профиль питомца не найден');
      }

      _pet = pet;

      // Check if we should archive and start a new thread (new day trigger)
      if (box.isNotEmpty) {
        final lastMsg = box.values.last;
        final lastDay = DateUtils.dateOnly(lastMsg.timestamp);
        final today = DateUtils.dateOnly(DateTime.now());

        if (lastDay.isBefore(today)) {
          // Archive the current box name
          final archived = prefs.getStringList(_archivedBoxesKey) ?? [];
          if (!archived.contains(_currentBoxName)) {
            archived.add(_currentBoxName);
            await prefs.setStringList(_archivedBoxesKey, archived);
          }

          // Create a new box for the current session
          _currentBoxName =
              'chat_thread_${DateTime.now().millisecondsSinceEpoch}';
          await prefs.setString(_currentBoxKey, _currentBoxName);
          box = await Hive.openBox<ChatMessage>(_currentBoxName);
        }
      }

      _repo = ChatRepository(box);
      isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        print('Init error: $e');
      }
    }

    isLoading = false;
    notifyListeners();
  }

  List<ChatMessage> get messages => _repo?.messages ?? [];

  bool get isReady => _repo != null && _pet != null;

  String get petName => _pet?.name ?? 'питомец';

  /// Перечитывает активного питомца.
  ///
  /// [_pet] загружается один раз в [init], а контроллер живёт всё время работы
  /// приложения — поэтому при смене профиля его надо обновить явно. Иначе чат
  /// продолжит здороваться именем прежнего питомца ([petName]) и отправлять в
  /// запрос его же контекст (PetContextBuilder.build) — до перезапуска
  /// приложения. Вызывается из [AIChatPageState] по сигналу
  /// [PetProfileService.activeProfileChanged].
  Future<void> reloadPet() async {
    final pet = await PetProfileService().loadActiveProfile();
    if (pet == null || pet.id == _pet?.id) return;
    _pet = pet;
    notifyListeners();
  }

  /// Loads all archived threads, newest first.
  Future<List<ArchivedThread>> loadArchivedThreads() async {
    final prefs = await SharedPreferences.getInstance();
    final names = prefs.getStringList(_archivedBoxesKey) ?? [];

    final threads = <ArchivedThread>[];
    for (final name in names.reversed) {
      final box = await Hive.openBox<ChatMessage>(name);
      if (box.isNotEmpty) {
        threads.add(
          ArchivedThread(
            boxName: name,
            date: box.values.first.timestamp,
            messages: box.values.toList(),
          ),
        );
      }
    }
    return threads;
  }

  /// Переключается на архивный тред [boxName] и делает его текущим —
  /// общение продолжается с его контекстом.
  Future<void> switchToThread(String boxName) async {
    if (boxName == _currentBoxName) return;
    final prefs = await SharedPreferences.getInstance();
    final archived = prefs.getStringList(_archivedBoxesKey) ?? [];

    // Архивируем текущий тред, если в нём есть сообщения.
    if ((_repo?.messages.isNotEmpty ?? false) &&
        !archived.contains(_currentBoxName)) {
      archived.add(_currentBoxName);
    }
    // Целевой тред становится текущим — убираем его из архива.
    archived.remove(boxName);
    await prefs.setStringList(_archivedBoxesKey, archived);

    _currentBoxName = boxName;
    await prefs.setString(_currentBoxKey, boxName);
    final box = await Hive.openBox<ChatMessage>(boxName);
    _repo = ChatRepository(box);
    _error = null;
    _lastFailedText = null;
    _pendingAttachment = null;
    notifyListeners();
  }

  /// Начинает новый пустой тред (текущий уходит в архив, если непустой).
  Future<void> startNewThread() async {
    final prefs = await SharedPreferences.getInstance();
    final archived = prefs.getStringList(_archivedBoxesKey) ?? [];
    if ((_repo?.messages.isNotEmpty ?? false) &&
        !archived.contains(_currentBoxName)) {
      archived.add(_currentBoxName);
      await prefs.setStringList(_archivedBoxesKey, archived);
    }

    _currentBoxName = 'chat_thread_${DateTime.now().millisecondsSinceEpoch}';
    await prefs.setString(_currentBoxKey, _currentBoxName);
    final box = await Hive.openBox<ChatMessage>(_currentBoxName);
    _repo = ChatRepository(box);
    _error = null;
    _lastFailedText = null;
    _pendingAttachment = null;
    notifyListeners();
  }

  /// Удаляет один тред (бокс) с диска и из архива. Если удалён текущий тред —
  /// открывается новый пустой.
  Future<void> deleteThread(String boxName) async {
    final prefs = await SharedPreferences.getInstance();
    final archived = prefs.getStringList(_archivedBoxesKey) ?? [];
    archived.remove(boxName);
    await prefs.setStringList(_archivedBoxesKey, archived);

    // Удаляем сообщения треда из облака.
    try {
      final box = await Hive.openBox<ChatMessage>(boxName);
      for (final m in box.values) {
        if (m.remoteId != null) {
          CloudSyncService.instance.deleteChat(m.remoteId!);
        }
      }
    } catch (_) {}

    try {
      await Hive.deleteBoxFromDisk(boxName);
    } catch (_) {}

    if (boxName == _currentBoxName) {
      _currentBoxName = 'chat_thread_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(_currentBoxKey, _currentBoxName);
      final box = await Hive.openBox<ChatMessage>(_currentBoxName);
      _repo = ChatRepository(box);
      _error = null;
      _lastFailedText = null;
      _pendingAttachment = null;
    }
    notifyListeners();
  }

  /// Удаляет все треды (архивные + текущий) и начинает чистый диалог.
  Future<void> deleteAllThreads() async {
    final prefs = await SharedPreferences.getInstance();
    final archived = prefs.getStringList(_archivedBoxesKey) ?? [];
    final boxes = {...archived, _currentBoxName, _defaultBoxName};
    for (final name in boxes) {
      try {
        await Hive.deleteBoxFromDisk(name);
      } catch (_) {}
    }
    await prefs.remove(_archivedBoxesKey);
    // Чистим всю историю чата и в облаке.
    await CloudSyncService.instance.deleteAllChats();

    _currentBoxName = _defaultBoxName;
    await prefs.setString(_currentBoxKey, _currentBoxName);
    final box = await Hive.openBox<ChatMessage>(_currentBoxName);
    _repo = ChatRepository(box);
    _error = null;
    _lastFailedText = null;
    _pendingAttachment = null;
    notifyListeners();
  }

  /// Сбрасывает баннер ошибки.
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Повторяет последнее неудачное сообщение.
  Future<void> retryLast() async {
    final text = _lastFailedText;
    if (text == null) return;
    _lastFailedText = null;
    await sendMessage(text);
  }

  // ── Предложенные ИИ события ───────────────────────────────────────────────

  /// Фактически создаёт событие из предложенного ИИ (общая логика для
  /// автосоздания и подтверждения «Создать»).
  Future<Event?> _createFromSuggested(SuggestedEvent s) async {
    final event = await Event.codec.fromAIResponse(s.raw);
    if (event != null) await EventService().createEvent(event);
    return event;
  }

  /// Подтверждает создание предложенного события [index] из сообщения [msg].
  Future<void> createSuggestedEvent(ChatMessage msg, int index) async {
    final list = msg.attachedEvents;
    if (index < 0 || index >= list.length) return;
    final s = list[index];
    if (s.status != SuggestedEventStatus.pending) return;

    final event = await _createFromSuggested(s);
    if (event == null) return;

    list[index] = s.copyWith(
      status: SuggestedEventStatus.created,
      createdEventId: event.id,
    );
    msg.attachedEvents = list;
    await msg.save();
    _pushMessage(msg);
    notifyListeners();
  }

  /// Отклоняет предложенное событие [index] (нажатие «Отмена»).
  Future<void> cancelSuggestedEvent(ChatMessage msg, int index) async {
    final list = msg.attachedEvents;
    if (index < 0 || index >= list.length) return;
    final s = list[index];
    if (s.status != SuggestedEventStatus.pending) return;

    list[index] = s.copyWith(status: SuggestedEventStatus.cancelled);
    msg.attachedEvents = list;
    await msg.save();
    _pushMessage(msg);
    notifyListeners();
  }

  /// Загружает созданное событие по id — для просмотра из карточки в чате.
  Future<Event?> findCreatedEvent(String id) async {
    final petId = _pet?.id;
    if (petId == null) return null;
    final all = await EventService().loadEvents(petId);
    for (final e in all) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Fire-and-forget upsert сообщения [msg] текущего треда в облако.
  /// Полученный remoteId сохраняется обратно в сообщение для последующих правок.
  /// Фоновый пуш — уважает тумблер синхронизации.
  void _pushMessage(ChatMessage msg) {
    final sync = CloudSyncService.instance;
    if (!sync.isAuthenticated || !sync.syncEnabled) return;
    sync
        .pushChat(
          remoteId: msg.remoteId,
          thread: _currentBoxName,
          role: msg.role,
          content: msg.content,
          timestamp: msg.timestamp,
          completed: msg.completed,
          eventsJson: msg.eventsJson,
        )
        .then((id) async {
          if (id != null && id != msg.remoteId) {
            msg.remoteId = id;
            try {
              await msg.save();
            } catch (_) {}
          }
        });
  }

  Stream<String> fakeStream(String fullText) async* {
    for (int i = 0; i < fullText.length; i++) {
      await Future.delayed(const Duration(milliseconds: 20));
      yield fullText.substring(0, i + 1);
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.isEmpty || !isReady || isLoading) return;

    // Снимаем вложение для этого сообщения (оно «расходуется» при отправке).
    final attachment = _pendingAttachment;
    _pendingAttachment = null;
    _error = null;

    final displayText = attachment != null
        ? '$text\n\n📎 ${attachment.label}'
        : text;
    final userMsg = ChatMessage(
      role: 'user',
      content: displayText,
      timestamp: DateTime.now(),
    );
    await _repo!.add(userMsg);
    _pushMessage(userMsg);

    isLoading = true;
    notifyListeners();

    try {
      final petContext = PetContextBuilder.build(_pet!);
      // Последние 10 сообщений (а не первые) — для актуального контекста.
      final history = messages;
      final limitedHistory = history.length > 10
          ? history.sublist(history.length - 10)
          : history;

      final context = [
        {
          "role": "system",
          "content":
              "Ты ветеринарный ассистент. Отвечай кратко, понятно и по делу. "
              "Используй приведённые данные о питомце и не переспрашивай то, "
              "что в них уже есть (обработки, прививки, препараты, аллергии и т.п.).\n\n"
              "Данные о питомце:\n$petContext"
              "${attachment != null ? "\n\nПользователь прикрепил данные (${attachment.type}): ${jsonEncode(attachment.data)}" : ""}",
        },
        ...limitedHistory.map((e) => {"role": e.role, "content": e.content}),
      ];

      final authService = GetIt.instance<AuthService>();
      final body = jsonEncode({
        // Контракт бэкенда: поле `message` — строка. Кладём ВАЛИДНЫЙ JSON
        // диалога (jsonEncode), а не Dart-представление списка (context.toString()):
        // так спецсимволы в сообщениях (кавычки, скобки, переводы строк)
        // корректно экранируются и не ломают структуру/парсинг на сервере.
        "message": jsonEncode(context),
        if (attachment != null) "attachment": attachment.data,
      });

      final response = await _httpClient
          .post(
            _messagesRoute,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${authService.token}',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        throw _ServerException(response.statusCode);
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final result = ChatResult.fromJson(data as Map<String, dynamic>);
      final fullResponse = _extractAnswer(result.response);
      final suggested = result.suggestedEvents();

      if (fullResponse == null || fullResponse.trim().isEmpty) {
        throw const _ServerException(0, 'Пустой ответ ассистента');
      }

      // Автосоздание (если включено в настройках) — иначе пользователь
      // подтверждает каждое событие карточкой под сообщением.
      if (suggested.isNotEmpty && await isAutoCreateEntitiesEnabled()) {
        for (final s in suggested) {
          final event = await _createFromSuggested(s);
          if (event != null) {
            s.status = SuggestedEventStatus.created;
            s.createdEventId = event.id;
          }
        }
      }

      isLoading = false;
      final botMsg = ChatMessage(
        role: 'assistant',
        content: '',
        timestamp: DateTime.now(),
        eventsJson: suggested.isEmpty
            ? null
            : SuggestedEvent.encodeList(suggested),
      );
      await _repo!.add(botMsg);
      // «Печать» ответа: содержимое обновляем в памяти и уведомляем UI на каждый
      // кадр (botMsg — тот же инстанс, что в боксе, поэтому UI видит изменения
      // без записи на диск). На диск (Hive) пишем не чаще ~500 мс — иначе на один
      // ответ уходят сотни записей (по записи на символ): износ флеша и лаги на
      // слабых устройствах. Первая запись — сразу (чтобы при крахе не остался
      // пустой пузырь), итоговый текст гарантированно сохраняем после цикла.
      var lastPersistMs = 0;
      await for (final chunk in fakeStream(fullResponse)) {
        botMsg.content = chunk;
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        if (nowMs - lastPersistMs >= 500) {
          lastPersistMs = nowMs;
          await botMsg.save();
        }
        notifyListeners();
      }
      botMsg.completed = true;
      await botMsg.save();
      _pushMessage(botMsg);
      notifyListeners();
    } catch (e) {
      // Любая ошибка (сеть, таймаут, сервер, GigaChat, парсинг) — не зависаем.
      isLoading = false;
      _error = _friendlyError(e);
      _lastFailedText = text;
      notifyListeners();
    }
  }

  /// Достаёт текст ответа из возможных форматов ответа сервера.
  static String? _extractAnswer(dynamic response) {
    if (response is Map && response.containsKey('response')) {
      return response['response'] as String; // обёрнутый простой текст
    }
    return response.toString();
  }

  static String _friendlyError(Object e) {
    if (e is _ServerException) {
      if (e.message != null) return e.message!;
      switch (e.statusCode) {
        case 401:
        case 403:
          return 'Сессия истекла — войдите снова';
        case 429:
          return 'Слишком много запросов — попробуйте позже';
        case 500:
        case 502:
        case 503:
          return 'Ассистент временно недоступен';
        default:
          return 'Ошибка сервера (${e.statusCode})';
      }
    }
    if (e is TimeoutException) return 'Ассистент долго не отвечает';
    final s = e.toString().toLowerCase();
    if (s.contains('socket') ||
        s.contains('connection') ||
        s.contains('network') ||
        s.contains('handshake')) {
      return 'Нет подключения к сети';
    }
    return 'Не удалось получить ответ';
  }

  /// Проверяет доступность ИИ-бэкенда (`<aiUrl>/health`).
  /// Любая ошибка сети/таймаут трактуется как «оффлайн» — метод не бросает
  /// исключений, чтобы статус всегда отражал реальную доступность.
  Future<bool> healthCheck() async {
    try {
      final response = await _httpClient
          .get(
            _healthRoute,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 6));

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Полностью удаляет всю историю общения (все треды) — используется из
  /// настроек, где живого контроллера нет.
  static Future<void> clearMessageHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final archived = prefs.getStringList(_archivedBoxesKey) ?? [];
    final current = prefs.getString(_currentBoxKey) ?? _defaultBoxName;
    final boxes = {...archived, current, _defaultBoxName};
    for (final name in boxes) {
      try {
        await Hive.deleteBoxFromDisk(name);
      } catch (_) {}
    }
    await prefs.remove(_archivedBoxesKey);
    await prefs.setString(_currentBoxKey, _defaultBoxName);
    await CloudSyncService.instance.deleteAllChats();
  }

  /// Выгружает **все** локальные треды в облако — часть полной выгрузки
  /// («Загрузить на сервер» / включение синхронизации), симметрично
  /// [restoreThreadsFromCloud]. Идемпотентно: каждое сообщение апсертится по
  /// своему remoteId, затем с сервера удаляются чаты, которых больше нет
  /// локально (синхронизация офлайн-удалений). Тумблер здесь НЕ проверяется —
  /// вызывается только из явной полной выгрузки.
  static Future<void> pushAllThreadsToCloud() async {
    final sync = CloudSyncService.instance;
    if (!sync.isAuthenticated) return;

    final prefs = await SharedPreferences.getInstance();
    final archived = prefs.getStringList(_archivedBoxesKey) ?? [];
    final current = prefs.getString(_currentBoxKey) ?? _defaultBoxName;
    final boxNames = {...archived, current, _defaultBoxName};

    final keepIds = <String>{};
    for (final name in boxNames) {
      final box = await Hive.openBox<ChatMessage>(name);
      for (final m in box.values) {
        final id = await sync.pushChat(
          remoteId: m.remoteId,
          thread: name,
          role: m.role,
          content: m.content,
          timestamp: m.timestamp,
          completed: m.completed,
          eventsJson: m.eventsJson,
        );
        if (id == null) continue;
        if (id != m.remoteId) {
          m.remoteId = id;
          try {
            await m.save();
          } catch (_) {}
        }
        keepIds.add(id);
      }
    }

    await sync.deleteStaleChats(keepIds);
  }

  /// Восстанавливает всю историю чата из облака (новое устройство).
  /// Группирует сообщения по тредам, пересоздаёт Hive-боксы и выставляет
  /// активным самый свежий тред. Безопасно вызывать повторно.
  static Future<void> restoreThreadsFromCloud() async {
    final records = await CloudSyncService.instance.fetchChats();
    if (records.isEmpty) return;

    final byThread = <String, List<dynamic>>{};
    for (final r in records) {
      final thread = r.data['thread'] as String? ?? _defaultBoxName;
      byThread.putIfAbsent(thread, () => []).add(r);
    }

    final prefs = await SharedPreferences.getInstance();
    final threadNames = <String>[];
    DateTime? latestTime;
    String? latestThread;

    for (final entry in byThread.entries) {
      final box = await Hive.openBox<ChatMessage>(entry.key);
      await box.clear();
      for (final r in entry.value) {
        final eventsJson = r.data['events_json'] as String?;
        await box.add(
          ChatMessage(
            role: r.data['role'] as String? ?? 'user',
            content: r.data['content'] as String? ?? '',
            timestamp:
                DateTime.tryParse(r.data['timestamp'] as String? ?? '') ??
                    DateTime.now(),
            completed: r.data['completed'] as bool? ?? false,
            eventsJson: (eventsJson == null || eventsJson.isEmpty)
                ? null
                : eventsJson,
            remoteId: r.id as String?,
          ),
        );
      }
      threadNames.add(entry.key);
      final lastTs = box.values.isNotEmpty ? box.values.last.timestamp : null;
      if (lastTs != null &&
          (latestTime == null || lastTs.isAfter(latestTime))) {
        latestTime = lastTs;
        latestThread = entry.key;
      }
    }

    final current = latestThread ?? _defaultBoxName;
    await prefs.setString(_currentBoxKey, current);
    await prefs.setStringList(
      _archivedBoxesKey,
      threadNames.where((t) => t != current).toList(),
    );
  }
}
