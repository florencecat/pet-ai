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

  PocketBaseService({required this.basePath}) : _baseUri = Uri.parse(basePath) {
    createPocketBase();
  }

  PocketBase get pb => _pb;

  Future<void> createPocketBase() async {
    final initial = await SharedPreferencesAsync().getString('pb_auth');

    final store = AsyncAuthStore(
      save: (String data) async => SharedPreferencesAsync().setString('pb_auth', data),
      initial: initial,
    );

    _pb = PocketBase(_baseUri.toString(), authStore: store);
  }
}