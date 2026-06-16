import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../domain/barber.dart';

class BarberRepository {
  BarberRepository(this._dio);
  final Dio _dio;

  /// List of barbers — the customer feed. Backend supports gender + sort
  /// filters but we keep the request simple for now and filter client-side.
  Future<List<Barber>> list() async {
    final res = await _dio.get('/barbers');
    final data = res.data;
    final raw = (data is List)
        ? data
        : (data is Map<String, dynamic> && data['data'] is List ? data['data'] as List : <dynamic>[]);
    return raw
        .cast<Map<String, dynamic>>()
        .map(Barber.fromJson)
        .toList();
  }

  Future<Barber> byId(String id) async {
    final res = await _dio.get('/barbers/$id');
    return Barber.fromJson(res.data as Map<String, dynamic>);
  }
}

final barberRepositoryProvider = Provider<BarberRepository>((ref) {
  return BarberRepository(ref.watch(dioProvider));
});

final barbersListProvider = FutureProvider<List<Barber>>((ref) async {
  return ref.watch(barberRepositoryProvider).list();
});

final barberDetailProvider = FutureProvider.family<Barber, String>((ref, id) async {
  return ref.watch(barberRepositoryProvider).byId(id);
});
