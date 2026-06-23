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

  /// Fetch a single barber (master) by id — used by the shop-owner's
  /// per-barber schedule screen.
  Future<ShopBarber> getBarber(String id) async {
    final res = await _dio.get('/barbershop/barbers/$id');
    return ShopBarber.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  /// POST /barbershop/send-retention-sms — bulk retention SMS to the
  /// selected phones. Returns the server's job id so the UI can poll
  /// progress.
  Future<({String jobId, int total})> sendRetentionSms(List<String> phones) async {
    final res = await _dio.post('/barbershop/send-retention-sms',
        data: {'phones': phones});
    final data = res.data is Map ? res.data as Map : <String, dynamic>{};
    return (
      jobId: (data['jobId'] ?? '').toString(),
      total: ((data['total'] ?? phones.length) as num).toInt(),
    );
  }

  /// Clients that booked with the given barber — used by the per-
  /// barber detail screen's Clients tab. The backend route returns
  /// a paginated `{data: [...]}` envelope; we unwrap to a flat list.
  Future<List<Map<String, dynamic>>> barberClients(String barberId,
      {int page = 1, int limit = 100}) async {
    final res = await _dio.get('/bookings/barber/$barberId/clients',
        queryParameters: {'page': page, 'limit': limit});
    final data = res.data;
    final list = (data is List)
        ? data
        : (data is Map && data['data'] is List ? data['data'] as List : <dynamic>[]);
    return list.cast<Map<String, dynamic>>();
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

/// Shop clients (customers who booked at this salon).
class ShopClient {
  ShopClient({required this.name, required this.phone, this.lastVisit, this.bookingsCount = 0});
  final String name;
  final String phone;
  final DateTime? lastVisit;
  final int bookingsCount;
  factory ShopClient.fromJson(Map<String, dynamic> json) => ShopClient(
        name: (json['name'] ?? '').toString(),
        phone: (json['phone'] ?? '').toString(),
        lastVisit: json['lastVisit'] != null ? DateTime.tryParse(json['lastVisit'].toString()) : null,
        bookingsCount: ((json['bookingsCount'] ?? json['count'] ?? 0) as num).toInt(),
      );
}

class ShopSmsLogEntry {
  ShopSmsLogEntry({required this.phone, required this.message, required this.status, required this.createdAt});
  final String phone;
  final String message;
  final String status;
  final DateTime createdAt;
  factory ShopSmsLogEntry.fromJson(Map<String, dynamic> json) => ShopSmsLogEntry(
        phone: (json['phone'] ?? '').toString(),
        message: (json['message'] ?? '').toString(),
        status: (json['status'] ?? 'unknown').toString(),
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
}

class ShopTxnEntry {
  ShopTxnEntry({required this.amount, required this.method, required this.direction, required this.createdAt, this.description});
  final int amount;
  final String method;
  final String direction;
  final String? description;
  final DateTime createdAt;
  factory ShopTxnEntry.fromJson(Map<String, dynamic> json) => ShopTxnEntry(
        amount: ((json['amount'] ?? 0) as num).toInt(),
        method: (json['method'] ?? 'internal').toString(),
        direction: (json['direction'] ?? (((json['amount'] ?? 0) as num) >= 0 ? 'in' : 'out')).toString(),
        description: json['description']?.toString(),
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
}

extension ShopRepoExtras on ShopRepository {
  /// Update the salon's own profile (name, address, working hours, etc.).
  Future<void> updateMe(Map<String, dynamic> patch) async {
    await _dio.patch('/barbershop/me', data: patch);
  }

  Future<List<ShopClient>> clients({int page = 1, int limit = 50, String? search}) async {
    final res = await _dio.get('/barbershop/clients', queryParameters: {
      'page': page, 'limit': limit,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    final data = res.data;
    final list = (data is List)
        ? data
        : (data is Map && data['data'] is List ? data['data'] as List : <dynamic>[]);
    return list.cast<Map<String, dynamic>>().map(ShopClient.fromJson).toList();
  }

  Future<List<ShopSmsLogEntry>> smsLog({int page = 1, int limit = 30}) async {
    final res = await _dio.get('/barbershop/sms', queryParameters: {'page': page, 'limit': limit});
    final data = res.data;
    final list = (data is List)
        ? data
        : (data is Map && data['data'] is List ? data['data'] as List : <dynamic>[]);
    return list.cast<Map<String, dynamic>>().map(ShopSmsLogEntry.fromJson).toList();
  }

  Future<List<ShopTxnEntry>> transactions({int page = 1, int limit = 30}) async {
    final res = await _dio.get('/barbershop/transactions', queryParameters: {'page': page, 'limit': limit});
    final data = res.data;
    final list = (data is List)
        ? data
        : (data is Map && data['data'] is List ? data['data'] as List : <dynamic>[]);
    return list.cast<Map<String, dynamic>>().map(ShopTxnEntry.fromJson).toList();
  }
}

final shopClientsProvider = FutureProvider<List<ShopClient>>(
    (ref) => ref.watch(shopRepositoryProvider).clients());
final shopSmsLogProvider = FutureProvider<List<ShopSmsLogEntry>>(
    (ref) => ref.watch(shopRepositoryProvider).smsLog());
final shopTransactionsProvider = FutureProvider<List<ShopTxnEntry>>(
    (ref) => ref.watch(shopRepositoryProvider).transactions());
