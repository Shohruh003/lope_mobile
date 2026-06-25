import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/storage.dart';
import '../domain/user.dart';

/// Wraps the backend's NestJS auth endpoints. Two flows:
///
/// 1. **Login** (returning user): POST /auth/login with phone + password →
///    {user, token, refreshToken}.
///
/// 2. **Register** (new user): POST /auth/register/send-code → OTP arrives by
///    SMS, then POST /auth/register/verify-code to validate, then POST
///    /auth/register with the full {name, phone, password, role} payload to
///    create the account and receive the token.
class AuthRepository {
  AuthRepository(this._dio, this._storage);
  final Dio _dio;
  final StorageService _storage;

  // ---------- LOGIN ----------

  Future<AppUser> login({required String phone, required String password}) async {
    final res = await _dio.post('/auth/login', data: {'phone': phone, 'password': password});
    final data = res.data as Map<String, dynamic>;
    final token = data['token'] as String;
    final user = data['user'] as Map<String, dynamic>;
    await _storage.writeToken(token);
    if (data['refreshToken'] is String) {
      await _storage.writeRefreshToken(data['refreshToken'] as String);
    }
    await _storage.writeUser(jsonEncode(user));
    return AppUser.fromJson(user);
  }

  // ---------- REGISTER ----------

  /// Step 1 — kick off registration. Returns the number of seconds the OTP is
  /// valid so the UI can show a resend countdown.
  Future<int> sendRegistrationCode(String phone) async {
    final res = await _dio.post('/auth/register/send-code', data: {'phone': phone});
    final data = res.data as Map<String, dynamic>;
    return (data['expiresIn'] as num?)?.toInt() ?? 60;
  }

  /// Step 2 — verify the SMS code. Returns true on success.
  Future<bool> verifyRegistrationCode({required String phone, required String code}) async {
    final res = await _dio.post('/auth/register/verify-code', data: {'phone': phone, 'code': code});
    return res.data == true || (res.data is Map && res.data['valid'] == true);
  }

  /// Step 3 — actually create the account and grab the JWT.
  /// PATCH /auth/me/referral-code — rotate the user's own referral
  /// code. Returns the new code so callers can patch local state.
  Future<String> updateMyReferralCode(String code) async {
    final res = await _dio.patch('/auth/me/referral-code',
        data: {'referralCode': code});
    final data = res.data;
    if (data is Map && data['referralCode'] != null) {
      return data['referralCode'].toString();
    }
    return code;
  }

  Future<AppUser> register({
    required String name,
    required String phone,
    required String password,
    String role = 'user',
    String? gender,
    String? promoCode,
    String? shopName,
  }) async {
    final res = await _dio.post('/auth/register', data: {
      'name': name,
      'phone': phone,
      'password': password,
      'role': role,
      // ignore: use_null_aware_elements
      if (gender != null) 'gender': gender,
      if (promoCode != null && promoCode.isNotEmpty) 'promoCode': promoCode,
      if (shopName != null && shopName.isNotEmpty) 'shopName': shopName,
    });
    final data = res.data as Map<String, dynamic>;
    final token = data['token'] as String;
    final user = data['user'] as Map<String, dynamic>;
    await _storage.writeToken(token);
    if (data['refreshToken'] is String) {
      await _storage.writeRefreshToken(data['refreshToken'] as String);
    }
    await _storage.writeUser(jsonEncode(user));
    return AppUser.fromJson(user);
  }

  // ---------- SESSION ----------

  /// Restore on app start. Returns null if no stored session.
  Future<AppUser?> restoreSession() async {
    final token = await _storage.readToken();
    final userJson = await _storage.readUser();
    if (token == null || token.isEmpty || userJson == null) return null;
    try {
      final map = jsonDecode(userJson) as Map<String, dynamic>;
      return AppUser.fromJson(map);
    } catch (_) {
      await _storage.clearAll();
      return null;
    }
  }

  /// Fetch the current user from /auth/me and persist the fresh copy.
  /// Returns the new user record, or null if the token was rejected.
  /// Web does this on every app open so balance / VIP / role updates
  /// show up without forcing a logout — we mirror that.
  Future<AppUser?> refreshMe() async {
    try {
      final res = await _dio.get('/auth/me');
      if (res.data is! Map) return null;
      final user = AppUser.fromJson(
          (res.data as Map).cast<String, dynamic>());
      await _storage.writeUser(jsonEncode(user.toJson()));
      return user;
    } on DioException catch (e) {
      // 401: token expired or revoked — caller should clear session.
      if (e.response?.statusCode == 401) {
        await _storage.clearAll();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async => _storage.clearAll();
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(dioProvider), ref.watch(storageProvider));
});
