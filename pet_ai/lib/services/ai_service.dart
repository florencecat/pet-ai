import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:http/io_client.dart';
import 'package:pet_satellite/services/authentification_service.dart';
import 'dart:convert';
import 'package:pet_satellite/services/http_client.dart';
import 'package:pet_satellite/services/pet_profile_service.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
part 'ai_service.g.dart';

@HiveType(typeId: 0)
class ChatMessage extends HiveObject {
  @HiveField(0)
  String role;

  @HiveField(1)
  String content;

  @HiveField(2)
  DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });
}

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

class ChatRepository {
  final Box<ChatMessage> box;

  ChatRepository(this.box);

  List<ChatMessage> get messages => box.values.toList();

  Future<void> add(ChatMessage msg) async {
    await box.add(msg);
  }

  Future<void> clear() async {
    await box.clear();
  }
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
        PetService().loadActiveProfile(),
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

  Stream<String> fakeStream(String fullText) async* {
    for (int i = 0; i < fullText.length; i++) {
      await Future.delayed(const Duration(milliseconds: 20));
      yield fullText.substring(0, i + 1);
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.isEmpty || !isReady) return;

    final userMsg = ChatMessage(
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
    );

    await _repo!.add(userMsg);

    if (!kDebugMode) {
      final fakeResponse =
          'Для вельш-корги кардигана вес 14 кг может быть немного выше среднего для взрослого кобеля его возраста. Обычно взрослые корги весят около 12-14 кг. Рекомендуется проконсультироваться с ветеринаром для точного определения индекса массы тела и получения рекомендаций по питанию и физической активности.';
      final fakeBotMsg = ChatMessage(
        role: 'assistant',
        content: fakeResponse,
        timestamp: DateTime.now(),
      );

      await _repo!.add(fakeBotMsg);
      await for (final chunk in fakeStream(fakeResponse)) {
        fakeBotMsg.content = chunk;
        await fakeBotMsg.save();
        notifyListeners();
      }

      return;
    }

    isLoading = true;
    notifyListeners();

    final petContext = PetContextBuilder.build(_pet!);
    final limitedHistory = messages.take(10).toList();
    final context = [
      {
        "role": "system",
        "content":
            "Ты ветеринарный ассистент. Отвечай кратко, понятно и по делу. "
            "Учитывай контекст питомца: $petContext",
      },
      ...limitedHistory.map((e) => {"role": e.role, "content": e.content}),
    ];

    final response = await _httpClient.post(
      _messagesRoute,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        "token": GetIt.instance<AuthService>().token,
        "message": context.toString(),
      }),
    );

    final data = jsonDecode(response.body);
    final fullResponse = data['choices'][0]['message']['content'];
    final botMsg = ChatMessage(
      role: 'assistant',
      content: '',
      timestamp: DateTime.now(),
    );

    await _repo!.add(botMsg);

    isLoading = false;

    await for (final chunk in fakeStream(fullResponse)) {
      botMsg.content = chunk;
      await botMsg.save();
      notifyListeners();
    }
  }

  Future<bool> healthCheck() async {
    final response = await _httpClient.get(
      _healthRoute,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    return response.statusCode == 200;
  }

  static Future<void> clearMessageHistory() async {
    final repository = ChatRepository(
      await Hive.openBox<ChatMessage>(_defaultBoxName),
    );
    repository.clear();
  }
}
