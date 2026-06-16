import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/booking.dart';

class BookingRepository {
  BookingRepository(this._dio);
  final Dio _dio;

  /// Booked slots for a barber on a date — used to grey-out unavailable times.
  Future<List<String>> bookedSlots({required String barberId, required String date}) async {
    final res = await _dio.get('/bookings/booked-slots/$barberId', queryParameters: {'date': date});
    final data = res.data;
    if (data is List) return data.cast<String>();
    if (data is Map<String, dynamic> && data['slots'] is List) {
      return (data['slots'] as List).cast<String>();
    }
    return const [];
  }

  /// Free day-schedule for a barber on a date — slots barber offers.
  Future<List<String>> daySchedule({required String barberId, required String date}) async {
    try {
      final res = await _dio.get('/schedule/day/$barberId/$date');
      final data = res.data;
      if (data is Map<String, dynamic> && data['slots'] is List) {
        return (data['slots'] as List).cast<String>();
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return const [];
      rethrow;
    }
    return const [];
  }

  /// Book a slot as a registered customer.
  Future<Booking> create({
    required String userId,
    required String barberId,
    required String date,
    required String time,
    required List<Map<String, dynamic>> services,
    required int totalPrice,
    required int totalDuration,
  }) async {
    final res = await _dio.post('/bookings', data: {
      'userId': userId,
      'barberId': barberId,
      'date': date,
      'time': time,
      'services': services,
      'totalPrice': totalPrice,
      'totalDuration': totalDuration,
    });
    return Booking.fromJson(res.data as Map<String, dynamic>);
  }

  /// My bookings (customer side, paginated).
  Future<List<Booking>> mine(String userId, {int page = 1, int limit = 20}) async {
    final res = await _dio.get('/bookings/user/$userId', queryParameters: {'page': page, 'limit': limit});
    final data = res.data;
    final raw = (data is List)
        ? data
        : (data is Map<String, dynamic> && data['data'] is List ? data['data'] as List : <dynamic>[]);
    return raw.cast<Map<String, dynamic>>().map(Booking.fromJson).toList();
  }

  Future<void> cancel(String bookingId) async {
    await _dio.patch('/bookings/$bookingId/cancel');
  }
}

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return BookingRepository(ref.watch(dioProvider));
});

/// My bookings provider — keyed on the current user id so a fresh login pulls
/// the new account's bookings.
final myBookingsProvider = FutureProvider<List<Booking>>((ref) async {
  final user = ref.watch(authControllerProvider).user;
  if (user == null) return const [];
  return ref.watch(bookingRepositoryProvider).mine(user.id);
});
