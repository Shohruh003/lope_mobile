import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';

class BarberBooking {
  BarberBooking({
    required this.id,
    required this.date,
    required this.time,
    required this.status,
    required this.userName,
    required this.totalPrice,
    required this.totalDuration,
    this.userPhone,
    this.guestName,
    this.guestPhone,
  });

  final String id;
  final String date;
  final String time;
  final String status;
  final String userName;
  final int totalPrice;
  final int totalDuration;
  final String? userPhone;
  final String? guestName;
  final String? guestPhone;

  factory BarberBooking.fromJson(Map<String, dynamic> json) => BarberBooking(
        id: json['id'] as String,
        date: json['date'] as String,
        time: json['time'] as String,
        status: (json['status'] ?? 'confirmed') as String,
        userName: (json['userName'] ?? '') as String,
        userPhone: json['userPhone'] as String?,
        guestName: json['guestName'] as String?,
        guestPhone: json['guestPhone'] as String?,
        totalPrice: ((json['totalPrice'] ?? 0) as num).toInt(),
        totalDuration: ((json['totalDuration'] ?? 0) as num).toInt(),
      );
}

class BarberPanelRepository {
  BarberPanelRepository(this._dio);
  final Dio _dio;

  /// Bookings for a specific barber on a specific date.
  Future<List<BarberBooking>> byDay({required String barberId, required String date}) async {
    final res = await _dio.get('/bookings/barber/$barberId', queryParameters: {'date': date});
    final data = res.data;
    final raw = (data is List)
        ? data
        : (data is Map<String, dynamic> && data['data'] is List ? data['data'] as List : <dynamic>[]);
    final list = raw.cast<Map<String, dynamic>>().map(BarberBooking.fromJson).toList();
    list.sort((a, b) => a.time.compareTo(b.time));
    return list;
  }

  /// All bookings for the barber, paginated. Backend already orders by
  /// {date desc, time desc}.
  Future<List<BarberBooking>> all({required String barberId, int page = 1, int limit = 20}) async {
    final res = await _dio.get(
      '/bookings/barber/$barberId',
      queryParameters: {'page': page, 'limit': limit},
    );
    final data = res.data;
    final raw = (data is List)
        ? data
        : (data is Map<String, dynamic> && data['data'] is List ? data['data'] as List : <dynamic>[]);
    return raw.cast<Map<String, dynamic>>().map(BarberBooking.fromJson).toList();
  }
}

final barberPanelRepositoryProvider = Provider<BarberPanelRepository>((ref) {
  return BarberPanelRepository(ref.watch(dioProvider));
});

final barberDayBookingsProvider = FutureProvider.family<List<BarberBooking>,
    ({String barberId, String date})>((ref, key) async {
  return ref.watch(barberPanelRepositoryProvider).byDay(barberId: key.barberId, date: key.date);
});

final barberAllBookingsProvider = FutureProvider.family<List<BarberBooking>, String>((ref, barberId) async {
  return ref.watch(barberPanelRepositoryProvider).all(barberId: barberId);
});

/// Booking actions a barber can take on their own bookings. These are POSTed
/// to existing NestJS endpoints; the web uses the same routes.
extension BarberBookingActions on BarberPanelRepository {
  Future<void> markComplete(String bookingId) async {
    await _dio.patch('/bookings/$bookingId/complete');
  }

  Future<void> cancel(String bookingId, {String? reason}) async {
    await _dio.patch('/bookings/$bookingId/cancel',
        data: reason == null ? {} : {'reason': reason});
  }

  /// Move the booking to a different date/time. Backend revalidates the slot
  /// against the barber's schedule, so a 409 means "slot taken".
  Future<void> reschedule(String bookingId, {required String date, required String time}) async {
    await _dio.patch('/bookings/$bookingId/reschedule', data: {'date': date, 'time': time});
  }

  /// Append N minutes to the booking's duration when the cut runs over.
  Future<void> extendDuration(String bookingId, int extraMinutes) async {
    await _dio.patch('/bookings/$bookingId/extend-duration', data: {'extraMinutes': extraMinutes});
  }

  /// Toggle the barber's accepting-bookings flag. The web has the same
  /// endpoint behind the "I'm off today" switch.
  Future<bool> toggleAvailability(String barberId) async {
    final res = await _dio.patch('/barbers/$barberId/toggle-availability');
    final data = res.data;
    if (data is Map && data['isAvailable'] is bool) return data['isAvailable'] as bool;
    return true;
  }

  /// Manual booking created by the barber on behalf of a guest who walked in
  /// or called by phone. Backend route: POST /bookings/manual.
  Future<void> createManual({
    required String barberId,
    required String date,
    required String time,
    required List<String> serviceIds,
    String? guestName,
    String? guestPhone,
    String? notes,
  }) async {
    await _dio.post('/bookings/manual', data: {
      'barberId': barberId,
      'date': date,
      'time': time,
      'serviceIds': serviceIds,
      // ignore: use_null_aware_elements
      if (guestName != null && guestName.isNotEmpty) 'guestName': guestName,
      // ignore: use_null_aware_elements
      if (guestPhone != null && guestPhone.isNotEmpty) 'guestPhone': guestPhone,
      // ignore: use_null_aware_elements
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
  }

  /// Auto-generate slots between dates based on working hours.
  Future<void> generateSchedule({
    required String barberId,
    required String dateFrom,
    required String dateTo,
    required String dayStart,
    required String dayEnd,
    required int slotMinutes,
    String? lunchStart,
    String? lunchEnd,
  }) async {
    await _dio.post('/barbers/$barberId/schedule/generate', data: {
      'dateFrom': dateFrom,
      'dateTo': dateTo,
      'dayStart': dayStart,
      'dayEnd': dayEnd,
      'slotMinutes': slotMinutes,
      // ignore: use_null_aware_elements
      if (lunchStart != null) 'lunchStart': lunchStart,
      // ignore: use_null_aware_elements
      if (lunchEnd != null) 'lunchEnd': lunchEnd,
    });
  }

  /// Voice booking — multipart audio blob to the parser endpoint.
  Future<Map<String, dynamic>> parseVoiceBooking({
    required String barberId,
    required String audioPath,
  }) async {
    final form = FormData.fromMap({
      'audio': await MultipartFile.fromFile(audioPath),
    });
    final res = await _dio.post('/barbers/$barberId/voice-booking', data: form);
    return Map<String, dynamic>.from(res.data as Map);
  }
}
