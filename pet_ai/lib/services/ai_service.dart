import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:pet_ai/services/profile_service.dart';
import 'package:hive/hive.dart';
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

class AuthService {
  static const _authUrl = 'https://ngw.devices.sberbank.ru:9443/api/v2/oauth';

  final String authorizationKey;

  String? _accessToken;
  DateTime? _expiresAt;

  AuthService({required this.authorizationKey});

  bool get _hasValidToken {
    if (_accessToken == null || _expiresAt == null) return false;

    return DateTime.now().isBefore(_expiresAt!.subtract(Duration(minutes: 2)));
  }

  Future<String> getAccessToken() async {
    if (_hasValidToken) {
      return _accessToken!;
    }

    final uuid = Uuid().v4();

    final response = await http.post(
      Uri.parse(_authUrl),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json',
        'RqUID': uuid,
        'Authorization': 'Basic $authorizationKey',
      },
      body: {'scope': 'GIGACHAT_API_PERS'},
    );

    if (response.statusCode != 200) {
      throw Exception('Ошибка получения токена: ${response.body}');
    }

    final data = jsonDecode(response.body);

    _accessToken = data['access_token'];
    final expiresIn = data['expires_in']; // секунды

    _expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

    return _accessToken!;
  }
}

class GigaChatService {
  static const _baseUrl =
      'https://gigachat.devices.sberbank.ru/api/v1/chat/completions';

  final AuthService authService;

  GigaChatService({required this.authService});

  Future<String> sendMessage({
    required List<ChatMessage> history,
    required String petContext,
  }) async {
    final token = await authService.getAccessToken();

    final limitedHistory = history.take(10).toList();

    final messages = [
      {
        "role": "system",
        "content":
            "Ты ветеринарный ассистент. Отвечай кратко, понятно и по делу. "
            "Учитывай контекст питомца: $petContext",
      },
      ...limitedHistory.map((e) => {"role": e.role, "content": e.content}),
    ];

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        "model": "GigaChat-2",
        "messages": messages,
        "n": 1,
        "stream": false,
        "max_tokens": 350,
        "repetition_penalty": 1.05,
      }),
    );

    final data = jsonDecode(response.body);

    return data['choices'][0]['message']['content'];
  }
}

class AIChatController extends ChangeNotifier {
  final GigaChatService service;

  ChatRepository? _repo;
  PetProfile? _pet;

  bool isLoading = false;
  bool isInitialized = false;

  AIChatController({required this.service});

  Future<void> init() async {
    isLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        ProfileService().loadProfile(),
        Hive.openBox<ChatMessage>('chat_box'),
      ]);

      final pet = results[0] as PetProfile?;
      final box = results[1] as Box<ChatMessage>;

      if (pet == null) {
        throw Exception('Профиль питомца не найден');
      }

      _pet = pet;
      _repo = ChatRepository(box);

      isInitialized = true;
    } catch (e) {
      print('Init error: $e');
    }

    isLoading = false;
    notifyListeners();
  }

  List<ChatMessage> get messages => _repo?.messages ?? [];

  bool get isReady => _repo != null && _pet != null;

  Stream<String> fakeStream(String fullText) async* {
    for (int i = 0; i < fullText.length; i++) {
      await Future.delayed(const Duration(milliseconds: 15));
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

    isLoading = true;
    notifyListeners();

    final petContext = PetContextBuilder.build(_pet!);

    final fullResponse = await service.sendMessage(
      history: messages,
      petContext: petContext,
    );

    final botMsg = ChatMessage(
      role: 'assistant',
      content: '',
      timestamp: DateTime.now(),
    );

    await _repo!.add(botMsg);

    await for (final chunk in fakeStream(fullResponse)) {
      botMsg.content = chunk;
      await botMsg.save();
      notifyListeners();
    }

    isLoading = false;
    notifyListeners();
  }
}
