import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class PbEntity {
  Map<String, dynamic> toPocketBase(String petId);
}

abstract class PbCodec<T extends PbEntity> {
  const PbCodec();

  T fromPocketBase(Map<String, dynamic> data);
}

class PocketBaseService {
  final String basePath;
  final Uri _baseUri;

  late PocketBase _pb;
  bool _initialized = false;

  PocketBaseService({required this.basePath}) : _baseUri = Uri.parse(basePath);

  PocketBase get pb {
    assert(
      _initialized,
      'PocketBaseService used before init() — await init() before reading pb',
    );
    return _pb;
  }

  /// Loads the persisted auth token from SharedPreferences and instantiates the
  /// PocketBase client. Must be awaited once at startup before any other
  /// service reads [pb]; otherwise a still-logged-in user appears anonymous and
  /// the backend rejects requests with 401 ("Сессия истекла").
  Future<void> init() async {
    if (_initialized) return;
    final initial = await FlutterSecureStorage().read(key: 'pb_auth');
    final store = AsyncAuthStore(
      save: (String data) async => FlutterSecureStorage().write(
          key: 'pb_auth',
          value: data
      ),
      initial: initial,
    );
    _pb = PocketBase(_baseUri.toString(), authStore: store);
    _initialized = true;
  }
}
