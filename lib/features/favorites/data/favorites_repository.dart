import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../barbers/domain/barber.dart';

class FavoritesRepository {
  FavoritesRepository(this._dio);
  final Dio _dio;

  Future<List<Barber>> list() async {
    final res = await _dio.get('/favorites');
    final data = res.data;
    final raw = (data is List)
        ? data
        : (data is Map && data['data'] is List ? data['data'] as List : <dynamic>[]);
    return raw.cast<Map<String, dynamic>>().map(Barber.fromJson).toList();
  }

  Future<bool> toggle(String barberId) async {
    final res = await _dio.post('/favorites/$barberId/toggle');
    if (res.data is Map && (res.data as Map)['favorited'] is bool) {
      return (res.data as Map)['favorited'] as bool;
    }
    return false;
  }
}

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
    (ref) => FavoritesRepository(ref.watch(dioProvider)));

/// Watches the auth state so a fresh login (or logout → re-login as a
/// different account) re-fetches favourites instead of returning the
/// previous user's cached list. The user.id is not actually used by the
/// /favorites endpoint (the backend resolves it from the JWT) but reading
/// it makes the provider's identity depend on the auth state.
final favoritesProvider = FutureProvider<List<Barber>>((ref) {
  final _ = ref.watch(authControllerProvider.select((s) => s.user?.id));
  return ref.watch(favoritesRepositoryProvider).list();
});
