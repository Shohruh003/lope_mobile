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
    String? notes,
  }) async {
    final res = await _dio.post('/bookings', data: {
      'userId': userId,
      'barberId': barberId,
      'date': date,
      'time': time,
      'services': services,
      'totalPrice': totalPrice,
      'totalDuration': totalDuration,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
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

  /// Mark a booking as completed. Optional totalPrice override is sent
  /// when the barber adjusts the final amount at checkout.
  Future<void> complete(String bookingId, {int? totalPrice}) async {
    await _dio.patch('/bookings/$bookingId/complete',
        data: totalPrice == null ? <String, dynamic>{} : {'totalPrice': totalPrice});
  }

  /// Reschedule a booking to a different date/time.
  Future<void> reschedule(String bookingId,
      {required String date, required String time}) async {
    await _dio.patch('/bookings/$bookingId/reschedule',
        data: {'date': date, 'time': time});
  }

  /// Of the given date list, which dates does the barber actually
  /// have schedule slots on. Returns a subset (or empty list).
  Future<List<String>> scheduledDates({
    required String barberId,
    required List<String> dates,
  }) async {
    final res = await _dio.get(
      '/schedule/$barberId/scheduled-dates',
      queryParameters: {'dates': dates},
    );
    final data = res.data;
    if (data is List) return data.cast<String>();
    return const [];
  }
}

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return BookingRepository(ref.watch(dioProvider));
});

/// Family provider over (barberId, dates) returning which of the given
/// dates the barber has any schedule slots on. Empty list means none
/// of the dates have slots yet.
final scheduledDatesProvider = FutureProvider.family<List<String>,
    ({String barberId, List<String> dates})>((ref, k) async {
  return ref
      .watch(bookingRepositoryProvider)
      .scheduledDates(barberId: k.barberId, dates: k.dates);
});

/// My bookings provider — keyed on the current user id so a fresh login pulls
/// the new account's bookings.
final myBookingsProvider = FutureProvider<List<Booking>>((ref) async {
  final user = ref.watch(authControllerProvider).user;
  if (user == null) return const [];
  return ref.watch(bookingRepositoryProvider).mine(user.id);
});
