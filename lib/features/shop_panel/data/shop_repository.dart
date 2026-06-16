import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';

class ShopStats {
  ShopStats({required this.bookings, required this.clients, required this.revenue, required this.messages});
  final int bookings;
  final int clients;
  final int revenue;
  final int messages;

  factory ShopStats.fromJson(Map<String, dynamic> json) => ShopStats(
        bookings: ((json['bookings'] ?? 0) as num).toInt(),
        clients: ((json['clients'] ?? 0) as num).toInt(),
        revenue: ((json['revenue'] ?? 0) as num).toInt(),
        messages: ((json['messages'] ?? json['sms'] ?? 0) as num).toInt(),
      );
}

class ShopBarber {
  ShopBarber({
    required this.id,
    required this.name,
    required this.experience,
    this.avatar,
    this.phone,
  });
  final String id;
  final String name;
  final String experience;
  final String? avatar;
  final String? phone;

  factory ShopBarber.fromJson(Map<String, dynamic> json) => ShopBarber(
        id: json['id'].toString(),
        name: (json['name'] ?? '').toString(),
        experience: (json['experience'] ?? '').toString(),
        avatar: json['avatar']?.toString(),
        phone: json['phone']?.toString(),
      );
}

class ShopBooking {
  ShopBooking({
    required this.id,
    required this.date,
    required this.time,
    required this.status,
    required this.barberName,
    required this.userName,
    required this.totalPrice,
  });
  final String id;
  final String date;
  final String time;
  final String status;
  final String barberName;
  final String userName;
  final int totalPrice;

  factory ShopBooking.fromJson(Map<String, dynamic> json) => ShopBooking(
        id: json['id'].toString(),
        date: (json['date'] ?? '').toString(),
        time: (json['time'] ?? '').toString(),
        status: (json['status'] ?? 'confirmed').toString(),
        barberName: (json['barberName'] ?? '').toString(),
        userName: (json['userName'] ?? json['guestName'] ?? 'Mijoz').toString(),
        totalPrice: ((json['totalPrice'] ?? 0) as num).toInt(),
      );
}

class ShopRepository {
  ShopRepository(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> me() async {
    final res = await _dio.get('/barbershop/me');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<ShopStats> stats({String? from, String? to}) async {
    final res = await _dio.get('/barbershop/stats', queryParameters: {
      // ignore: use_null_aware_elements
      if (from != null) 'from': from,
      // ignore: use_null_aware_elements
      if (to != null) 'to': to,
    });
    return ShopStats.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  // Barbers (masters) CRUD
  Future<List<ShopBarber>> barbers({int page = 1, int limit = 20, String? search}) async {
    final res = await _dio.get('/barbershop/barbers', queryParameters: {
      'page': page, 'limit': limit,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    final data = res.data;
    final raw = (data is List)
        ? data
        : (data is Map && data['data'] is List ? data['data'] as List : <dynamic>[]);
    return raw.cast<Map<String, dynamic>>().map(ShopBarber.fromJson).toList();
  }

  Future<void> createBarber({required String name, required String experience, String? phone}) async {
    await _dio.post('/barbershop/barbers', data: {
      'name': name,
      'experience': experience,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    });
  }

  Future<void> updateBarber(String id, Map<String, dynamic> body) async {
    await _dio.patch('/barbershop/barbers/$id', data: body);
  }

  Future<void> deleteBarber(String id) async {
    await _dio.delete('/barbershop/barbers/$id');
  }

  // Bookings
  Future<List<ShopBooking>> bookings({
    String? date,
    String? barberId,
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final res = await _dio.get('/barbershop/bookings', queryParameters: {
      // ignore: use_null_aware_elements
      if (date != null) 'date': date,
      if (barberId != null && barberId.isNotEmpty) 'barberId': barberId,
      if (status != null && status.isNotEmpty && status != 'all') 'status': status,
      'page': page, 'limit': limit,
    });
    final data = res.data;
    final raw = (data is List)
        ? data
        : (data is Map && data['data'] is List ? data['data'] as List : <dynamic>[]);
    return raw.cast<Map<String, dynamic>>().map(ShopBooking.fromJson).toList();
  }
}

final shopRepositoryProvider =
    Provider<ShopRepository>((ref) => ShopRepository(ref.watch(dioProvider)));

final shopMeProvider = FutureProvider<Map<String, dynamic>>(
    (ref) => ref.watch(shopRepositoryProvider).me());
final shopStatsProvider = FutureProvider<ShopStats>(
    (ref) => ref.watch(shopRepositoryProvider).stats());
final shopBarbersProvider = FutureProvider<List<ShopBarber>>(
    (ref) => ref.watch(shopRepositoryProvider).barbers());
final shopBookingsProvider = FutureProvider<List<ShopBooking>>(
    (ref) => ref.watch(shopRepositoryProvider).bookings());
