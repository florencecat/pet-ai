import 'package:get_it/get_it.dart';
import 'package:pet_satellite/services/api_service.dart';
import 'package:pet_satellite/services/pb_service.dart';
import 'package:pocketbase/pocketbase.dart';

class AuthResult {
  final bool success;
  final int code;
  final String? otpId;
  final String? errorMessage;

  const AuthResult._({
    required this.success,
    required this.code,
    this.otpId,
    this.errorMessage,
  });

  factory AuthResult.ok({String? otpId}) => AuthResult._(
        success: true,
        code: 200,
        otpId: otpId,
      );

  factory AuthResult.fail(int code, {String? errorMessage}) => AuthResult._(
        success: false,
        code: code,
        errorMessage: errorMessage,
      );
}

class AuthService {
  static final _usersCollection = GetIt.instance<ApiService>().usersRoute;

  final PocketBaseService pbService;

  AuthService({required this.pbService});

  RecordModel? get userRecord => pbService.pb.authStore.record;
  String get token => pbService.pb.authStore.token;

  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirm,
  }) async {
    try {
      await pbService.pb.collection(_usersCollection).create(body: {
        'name': name,
        'email': email,
        'password': password,
        'passwordConfirm': passwordConfirm,
      });
    } on ClientException catch (e) {
      if (e.statusCode == 400) {
        final mapped = _mapCreateError(e);
        if (mapped.code == 409) {
          // Email already registered (likely from a previous attempt).
          // Fall through to OTP so the user can still verify their email.
        } else {
          return mapped;
        }
      } else {
        return _networkError(e.statusCode);
      }
    } catch (_) {
      return _offlineError();
    }

    return _requestOTP(email);
  }

  /// Verifies the [code] against the [otpId] returned by [register] or
  /// [resendOTP].
  ///
  /// On success, [pb].authStore is populated — the user is now authenticated.
  Future<AuthResult> verifyOTP({
    required String otpId,
    required String code,
  }) async {
    try {
      await pbService.pb.collection(_usersCollection).authWithOTP(otpId, code);
      return AuthResult.ok();
    } on ClientException catch (e) {
      switch (e.statusCode) {
        case 400:
          return AuthResult.fail(400, errorMessage: 'Неверный код');
        case 404:
          return AuthResult.fail(
            404,
            errorMessage: 'Код устарел — запросите новый',
          );
        default:
          return _networkError(e.statusCode);
      }
    } catch (_) {
      return _offlineError();
    }
  }

  /// Requests a new OTP for [email] (e.g. when the user taps "Отправить снова").
  Future<AuthResult> resendOTP(String email) => _requestOTP(email);

  /// Signs in an existing user with [email] and [password].
  ///
  /// On success, [pb].authStore is populated — callers read the profile from
  /// [pb].authStore.record.
  ///
  /// Security: the same generic message is returned whether the email does not
  /// exist or the password is wrong, to prevent account enumeration.
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      await pbService.pb
          .collection(_usersCollection)
          .authWithPassword(email, password);
      return AuthResult.ok();
    } on ClientException catch (e) {
      if (e.statusCode == 400 || e.statusCode == 401) {
        return AuthResult.fail(
          e.statusCode,
          errorMessage: 'Неверный адрес или пароль.',
        );
      }
      return _networkError(e.statusCode);
    } catch (_) {
      return _offlineError();
    }
  }

  /// Sends a password-reset link to [email].
  ///
  /// PocketBase always returns success even if the email is not registered, so
  /// callers can safely show a "check your inbox" message without leaking
  /// whether the address exists in the system.
  Future<AuthResult> requestPasswordReset(String email) async {
    try {
      await pbService.pb
          .collection(_usersCollection)
          .requestPasswordReset(email);
      return AuthResult.ok();
    } on ClientException catch (e) {
      if (e.statusCode == 429) {
        return AuthResult.fail(
          429,
          errorMessage: 'Слишком много запросов — повторите позже',
        );
      }
      return _networkError(e.statusCode);
    } catch (_) {
      return _offlineError();
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<AuthResult> _requestOTP(String email) async {
    try {
      final res = await pbService.pb.collection(_usersCollection).requestOTP(email);
      return AuthResult.ok(otpId: res.otpId);
    } on ClientException catch (e) {
      if (e.statusCode == 429) {
        return AuthResult.fail(
          429,
          errorMessage: 'Слишком много запросов — повторите позже',
        );
      }
      return _networkError(e.statusCode);
    } catch (_) {
      return _offlineError();
    }
  }

  /// Maps a 400 response from the create endpoint to a typed [AuthResult].
  /// Does not expose raw field names or server error codes to callers.
  AuthResult _mapCreateError(ClientException e) {
    final data = e.response['data'] as Map<String, dynamic>? ?? {};

    if (data.containsKey('email')) {
      final code =
          (data['email'] as Map<String, dynamic>?)?['code'] as String? ?? '';
      if (code == 'validation_not_unique') {
        return AuthResult.fail(409); // handled by caller: fall through to OTP
      }
      return AuthResult.fail(
        400,
        errorMessage: 'Некорректный адрес эл. почты',
      );
    }

    if (data.containsKey('password') || data.containsKey('passwordConfirm')) {
      return AuthResult.fail(400, errorMessage: 'Пароль не соответствует требованиям сервера');
    }

    return AuthResult.fail(400);
  }

  static AuthResult _networkError(int code) =>
      AuthResult.fail(code, errorMessage: 'Ошибка сети — попробуйте позже');

  static AuthResult _offlineError() =>
      AuthResult.fail(0, errorMessage: 'Нет подключения к сети');
}
