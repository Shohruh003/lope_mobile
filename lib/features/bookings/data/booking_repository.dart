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
    // Backend uses query params (bookings.controller.ts:40): GET /bookings/booked-slots?barberId&date
    final res = await _dio.get('/bookings/booked-slots',
        queryParameters: {'barberId': barberId, 'date': date});
    final data = res.data;
    if (data is List) return data.cast<String>();
    if (data is Map<String, dynamic> && data['slots'] is List) {
      return (data['slots'] as List).cast<String>();
    }
    return const [];
  }

  /// Free day-schedule for a barber on a date — slots barber offers.
  /// Backend endpoint: GET /schedule/:barberId/:date (schedule.controller.ts:41).
  /// Old /schedule/day/:barberId/:date had no handler → 404 → empty
  /// slot list → customer step 2 always rendered "no times available".
  Future<List<String>> daySchedule({required String barberId, required String date}) async {
    try {
      final res = await _dio.get('/schedule/$barberId/$date');
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
    final r = await minePaged(userId, page: page, limit: limit);
    return r.data;
  }

  /// Paginated variant returning {data, hasMore} so the list screen can
  /// load older history with infinite scroll. Mirrors web's
  /// `loadMoreUserBookings` flow.
  Future<({List<Booking> data, bool hasMore, int total})> minePaged(
      String userId,
      {int page = 1,
      int limit = 20}) async {
    final res = await _dio.get('/bookings/user/$userId',
        queryParameters: {'page': page, 'limit': limit});
    final data = res.data;
    final raw = (data is List)
        ? data
        : (data is Map<String, dynamic> && data['data'] is List ? data['data'] as List : <dynamic>[]);
    final meta = data is Map && data['meta'] is Map
        ? (data['meta'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    final list =
        raw.cast<Map<String, dynamic>>().map(Booking.fromJson).toList();
    return (
      data: list,
      hasMore: meta['hasMore'] == true ||
          (((meta['page'] ?? page) as num) <
              ((meta['totalPages'] ?? 1) as num)),
      total: ((meta['total'] ?? list.length) as num).toInt(),
    );
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

/// Family provider over (barberId, datesKey) returning which of the given
/// dates the barber has any schedule slots on. Empty list means none
/// of the dates have slots yet.
///
/// `datesKey` is a comma-joined stable string (not `List<String>`) — Dart
/// List uses identity equality, so passing a fresh `.toList()` on every
/// build would spawn a new provider instance per rebuild and hammer the
/// API into 429s. A String key gives us structural equality for free.
final scheduledDatesProvider = FutureProvider.family<List<String>,
    ({String barberId, String datesKey})>((ref, k) async {
  final dates = k.datesKey.split(',');
  return ref
      .watch(bookingRepositoryProvider)
      .scheduledDates(barberId: k.barberId, dates: dates);
});

/// My bookings provider — keyed on the current user id so a fresh login pulls
/// the new account's bookings.
final myBookingsProvider = FutureProvider<List<Booking>>((ref) async {
  final user = ref.watch(authControllerProvider).user;
  if (user == null) return const [];
  return ref.watch(bookingRepositoryProvider).mine(user.id);
});

/// Paged variant — used by MyBookingsScreen for infinite scroll.
final myBookingsPagedProvider = FutureProvider.family<
    ({List<Booking> data, bool hasMore, int total}), int>((ref, page) async {
  final user = ref.watch(authControllerProvider).user;
  if (user == null) {
    return (data: const <Booking>[], hasMore: false, total: 0);
  }
  return ref.watch(bookingRepositoryProvider).minePaged(user.id, page: page);
});
