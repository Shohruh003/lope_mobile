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

  /// Get the saved slot list for one day — mirrors web's
  /// `fetchBarberDaySchedule`. Returns empty on 404.
  Future<List<String>> scheduleSlots({required String barberId, required String date}) async {
    try {
      final res = await _dio.get('/schedule/$barberId/$date');
      final data = res.data;
      if (data is Map && data['slots'] is List) {
        return (data['slots'] as List).map((e) => e.toString()).toList();
      }
      return [];
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return [];
      rethrow;
    }
  }

  /// HH:MM strings already booked. Backend endpoint:
  /// GET /bookings/booked-slots?barberId&date (bookings.controller.ts:40)
  Future<List<String>> bookedTimes({required String barberId, required String date}) async {
    try {
      final res = await _dio.get('/bookings/booked-slots',
          queryParameters: {'barberId': barberId, 'date': date});
      final data = res.data;
      final list = (data is List)
          ? data
          : (data is Map && data['data'] is List ? data['data'] as List : <dynamic>[]);
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
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
