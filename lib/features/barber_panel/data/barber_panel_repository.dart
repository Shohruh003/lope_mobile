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

  /// Auto-generate slots for a date range. The backend has no bulk-generate
  /// endpoint — the web computes slots client-side and PUTs `/schedule` one
  /// date at a time. We do the same so the server stores actual slot arrays
  /// (which the schedule view reads back).
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
    final slots = _buildSlots(
      dayStart: dayStart,
      dayEnd: dayEnd,
      slotMinutes: slotMinutes,
      lunchStart: lunchStart,
      lunchEnd: lunchEnd,
    );
    if (slots.isEmpty) {
      throw Exception('Slot oralig\'i noto\'g\'ri');
    }

    // Iterate each date inclusive of dateFrom..dateTo
    final from = DateTime.parse(dateFrom);
    final to = DateTime.parse(dateTo);
    var cur = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);

    while (!cur.isAfter(end)) {
      final dateStr =
          '${cur.year}-${cur.month.toString().padLeft(2, '0')}-${cur.day.toString().padLeft(2, '0')}';
      await _dio.put('/schedule', data: {
        'barberId': barberId,
        'date': dateStr,
        'slots': slots,
        'force': true,
      });
      cur = cur.add(const Duration(days: 1));
    }
  }

  /// Pure-Dart slot builder used by generateSchedule. Returns HH:MM strings
  /// from `dayStart` up to but NOT including `dayEnd`, skipping any time
  /// that falls inside the lunch window (when provided).
  List<String> _buildSlots({
    required String dayStart,
    required String dayEnd,
    required int slotMinutes,
    String? lunchStart,
    String? lunchEnd,
  }) {
    int parse(String hhmm) {
      final p = hhmm.split(':');
      return int.parse(p[0]) * 60 + int.parse(p[1]);
    }

    final start = parse(dayStart);
    final end = parse(dayEnd);
    final lunchA = (lunchStart != null) ? parse(lunchStart) : -1;
    final lunchB = (lunchEnd != null) ? parse(lunchEnd) : -1;
    final out = <String>[];
    for (var m = start; m + slotMinutes <= end; m += slotMinutes) {
      // Skip slots whose start falls inside the lunch window.
      if (lunchA >= 0 && lunchB > lunchA && m >= lunchA && m < lunchB) continue;
      out.add('${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}');
    }
    return out;
  }

  /// Convenience helper for the schedule screen's "Mijoz qo'shish" sheet:
  /// fetches the barber's service catalogue so the sheet can render chips.
  Future<List<Map<String, dynamic>>> servicesForBarber(String barberId) async {
    final res = await _dio.get('/barbers/$barberId/services');
    final data = res.data;
    final list = (data is List)
        ? data
        : (data is Map && data['data'] is List ? data['data'] as List : <dynamic>[]);
    return list.cast<Map<String, dynamic>>();
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

  /// Fetches the explicit slot list for a barber on a given day.
  /// Web equivalent: `GET /schedule/:barberId/:date`. Returns the HH:MM list.
  Future<List<String>> getDaySchedule(String barberId, String date) async {
    try {
      final res = await _dio.get('/schedule/$barberId/$date');
      final data = res.data;
      if (data is Map && data['slots'] is List) {
        return (data['slots'] as List).map((e) => e.toString()).toList();
      }
      return [];
    } on DioException catch (e) {
      // 404 means no schedule for that day — not an error, just empty.
      if (e.response?.statusCode == 404) return [];
      rethrow;
    }
  }

  /// Returns the HH:MM strings of slots that already have a booking.
  /// Web: `GET /schedule/:barberId/:date/booked`.
  Future<List<String>> getBookedSlots(String barberId, String date) async {
    try {
      final res = await _dio.get('/bookings/barber/$barberId/booked', queryParameters: {'date': date});
      final data = res.data;
      final list = (data is List)
          ? data
          : (data is Map && data['data'] is List ? data['data'] as List : <dynamic>[]);
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      // Fallback: derive from byDay() bookings.
      try {
        final list = await byDay(barberId: barberId, date: date);
        return list.map((b) => b.time).toList();
      } catch (_) {
        return [];
      }
    }
  }

  /// Returns the blocked HH:MM list for the date. 404 means no blocked slots.
  Future<List<String>> getBlockedSlots(String barberId, String date) async {
    try {
      final res = await _dio.get('/schedule/$barberId/$date/blocked');
      final data = res.data;
      final list = (data is List)
          ? data
          : (data is Map && data['data'] is List ? data['data'] as List : <dynamic>[]);
      return list.map((e) {
        if (e is Map) return (e['time'] ?? '').toString();
        return e.toString();
      }).where((s) => s.isNotEmpty).toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return [];
      return [];
    }
  }

  /// Save the entire slot list for a day. Web uses `PUT /schedule`.
  Future<void> saveDaySchedule({
    required String barberId,
    required String date,
    required List<String> slots,
  }) async {
    await _dio.put('/schedule', data: {
      'barberId': barberId,
      'date': date,
      'slots': slots,
      'force': true,
    });
  }

  /// Toggle blocked/unblocked status for a single slot.
  Future<void> toggleSlotBlock(String barberId, String date, String time) async {
    await _dio.post('/schedule/block-slot', data: {
      'barberId': barberId,
      'date': date,
      'time': time,
    });
  }
}

/// FutureProviders for the schedule view to consume directly. Day schedule,
/// booked times, and blocked times are all fetched against the same key.
final scheduleSlotsProvider = FutureProvider.family<List<String>,
    ({String barberId, String date})>((ref, key) async {
  return ref.watch(barberPanelRepositoryProvider).getDaySchedule(key.barberId, key.date);
});

final bookedSlotsProvider = FutureProvider.family<List<String>,
    ({String barberId, String date})>((ref, key) async {
  return ref.watch(barberPanelRepositoryProvider).getBookedSlots(key.barberId, key.date);
});

final blockedSlotsProvider = FutureProvider.family<List<String>,
    ({String barberId, String date})>((ref, key) async {
  return ref.watch(barberPanelRepositoryProvider).getBlockedSlots(key.barberId, key.date);
});
