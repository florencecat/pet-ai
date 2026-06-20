import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:pet_satellite/services/api_service.dart';
import 'package:pet_satellite/services/pb_service.dart';
import 'package:pocketbase/pocketbase.dart';

class AuthResult {
  final bool success;
  final int code;
  final String? otpId;
  final String? errorMessage;
  /// True when the account was just created (OTP request is part of registration).
  final bool isNewUser;

  const AuthResult._({
    required this.success,
    required this.code,
    this.otpId,
    this.errorMessage,
    this.isNewUser = false,
  });

  factory AuthResult.ok({String? otpId, bool isNewUser = false}) => AuthResult._(
        success: true,
        code: 200,
        otpId: otpId,
        isNewUser: isNewUser,
      );

  factory AuthResult.fail(int code, {String? errorMessage}) => AuthResult._(
        success: false,
        code: code,
        errorMessage: errorMessage,
      );
}

class AuthService extends ChangeNotifier {
  static final _usersCollection = GetIt.instance<ApiService>().usersRoute;

  final PocketBaseService pbService;
  late final StreamSubscription<AuthStoreEvent> _sub;

  AuthService({required this.pbService}) {
    _sub = pbService.pb.authStore.onChange.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  RecordModel? get userRecord => pbService.pb.authStore.record;
  String get token => pbService.pb.authStore.token;
  bool get isAuthenticated => pbService.pb.authStore.isValid;

  /// Unified entry point for both sign-in and sign-up.
  ///
  /// Attempts to create an account for [email]. If the email is already
  /// registered (409), falls through silently. In both cases an OTP is sent
  /// and [AuthResult.isNewUser] reflects whether the account was just created.
  ///
  /// Callers should ask for a display name only when [AuthResult.isNewUser]
  /// is true — after [verifyOTP] succeeds, via [updateName].
  Future<AuthResult> requestAccess(String email) async {
    final generated = _generatePassword();
    bool isNew = false;
    try {
      await pbService.pb.collection(_usersCollection).create(body: {
        'name': '',
        'email': email,
        'password': generated,
        'passwordConfirm': generated,
      });
      isNew = true;
    } on ClientException catch (e) {
      if (e.statusCode == 400) {
        final mapped = _mapCreateError(e);
        if (mapped.code != 409) return mapped; // real validation error
        // 409 → already registered, isNew stays false
      } else {
        return _networkError(e.statusCode);
      }
    } catch (_) {
      return _offlineError();
    }

    final otp = await _requestOTP(email);
    if (!otp.success) return otp;
    return AuthResult.ok(otpId: otp.otpId, isNewUser: isNew);
  }

  /// Updates the display name of the currently authenticated user.
  Future<void> updateName(String name) async {
    final record = pbService.pb.authStore.record;
    if (record == null) return;
    try {
      await pbService.pb
          .collection(_usersCollection)
          .update(record.id, body: {'name': name});
    } catch (_) {
      // Non-fatal — will sync on next open.
    }
  }

  /// Verifies the [code] against the [otpId] returned by [register],
  /// [loginWithOTP], or [resendOTP].
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

  /// Requests a new OTP for [email].
  Future<AuthResult> resendOTP(String email) => _requestOTP(email);

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<AuthResult> _requestOTP(String email) async {
    try {
      final res = await pbService.pb
          .collection(_usersCollection)
          .requestOTP(email);
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

  /// Generates a random 24-char password used internally during account
  /// creation. The user never sees it — authentication is always via OTP.
  static String _generatePassword() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    return List.generate(24, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  AuthResult _mapCreateError(ClientException e) {
    final data = e.response['data'] as Map<String, dynamic>? ?? {};

    if (data.containsKey('email')) {
      final code =
          (data['email'] as Map<String, dynamic>?)?['code'] as String? ?? '';
      if (code == 'validation_not_unique') {
        return AuthResult.fail(409);
      }
      return AuthResult.fail(
        400,
        errorMessage: 'Некорректный адрес эл. почты',
      );
    }

    return AuthResult.fail(400);
  }

  static AuthResult _networkError(int code) =>
      AuthResult.fail(code, errorMessage: 'Ошибка сети — попробуйте позже');

  static AuthResult _offlineError() =>
      AuthResult.fail(0, errorMessage: 'Нет подключения к сети');
}
