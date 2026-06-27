import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';

class BarberClient {
  BarberClient({
    required this.name,
    required this.phone,
    required this.bookingsCount,
    this.lastVisit,
    this.totalSpent = 0,
  });
  final String name;
  final String phone;
  final int bookingsCount;
  final DateTime? lastVisit;
  final int totalSpent;

  factory BarberClient.fromJson(Map<String, dynamic> json) => BarberClient(
        name: (json['name'] ?? json['guestName'] ?? '').toString(),
        phone: (json['phone'] ?? json['guestPhone'] ?? '').toString(),
        // Backend exposes `totalVisits` (bookings.service.ts:194); kept
        // bookingsCount/count fallbacks so older cached responses don't
        // suddenly read as 0.
        bookingsCount: ((json['totalVisits'] ?? json['bookingsCount'] ?? json['count'] ?? 0) as num).toInt(),
        lastVisit: json['lastVisit'] != null && (json['lastVisit'] as String).isNotEmpty
            ? DateTime.tryParse(json['lastVisit'].toString())
            : null,
        // Backend doesn't currently return totalSpent — keep the read
        // for forward compat but it will be 0 in production today.
        totalSpent: ((json['totalSpent'] ?? 0) as num).toInt(),
      );
}

class BarberClientsRepository {
  BarberClientsRepository(this._dio);
  final Dio _dio;

  Future<List<BarberClient>> mine(String barberId) async {
    // Backend endpoint: GET /bookings/barber/:barberId/clients
    // (bookings.controller.ts:164). The old /barbers/:id/clients had
    // no handler — barber's 'Mijozlarim' screen always loaded empty.
    final res = await _dio.get('/bookings/barber/$barberId/clients');
    final data = res.data;
    final list = (data is List)
        ? data
        : (data is Map && data['data'] is List ? data['data'] as List : <dynamic>[]);
    return list.cast<Map<String, dynamic>>().map(BarberClient.fromJson).toList();
  }
}

final barberClientsRepositoryProvider = Provider<BarberClientsRepository>(
    (ref) => BarberClientsRepository(ref.watch(dioProvider)));

final barberClientsProvider = FutureProvider.family<List<BarberClient>, String>(
    (ref, barberId) => ref.watch(barberClientsRepositoryProvider).mine(barberId));
