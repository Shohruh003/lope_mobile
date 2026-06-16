import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
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

final favoritesProvider = FutureProvider<List<Barber>>(
    (ref) => ref.watch(favoritesRepositoryProvider).list());
