import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../auth/presentation/auth_controller.dart';

class ShopDailyPoint {
  ShopDailyPoint(
      {required this.date,
      required this.bookings,
      required this.revenue,
      required this.newClients});
  final String date;
  final int bookings;
  final int revenue;
  final int newClients;
}

class ShopStats {
  ShopStats({
    required this.bookings,
    required this.clients,
    required this.revenue,
    required this.messages,
    required this.todayRevenue,
    required this.todayBookings,
    required this.todayCompleted,
    required this.uniqueClients,
    required this.newClients,
    required this.manualBookings,
    required this.fromSmsBookings,
    required this.barbersCount,
    required this.clientsDueForReminder,
    required this.smsConfirmation,
    required this.smsReminder,
    required this.smsRetention,
    required this.daily,
  });
  final int bookings;
  final int clients;
  final int revenue;
  final int messages;
  final int todayRevenue;
  final int todayBookings;
  final int todayCompleted;
  final int uniqueClients;
  final int newClients;
  final int manualBookings;
  final int fromSmsBookings;
  final int barbersCount;
  final int clientsDueForReminder;
  final int smsConfirmation;
  final int smsReminder;
  final int smsRetention;
  final List<ShopDailyPoint> daily;

  factory ShopStats.fromJson(Map<String, dynamic> json) {
    // Accept either flat keys (older shape) or the canonical
    // `{totals, daily, sms}` wrapper returned by the backend today.
    final totals = json['totals'] is Map
        ? (json['totals'] as Map).cast<String, dynamic>()
        : json;
    final sms = json['sms'] is Map
        ? (json['sms'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    final dailyRaw =
        (json['daily'] is List ? json['daily'] as List : const []);
    int pickInt(Map<String, dynamic> m, String key) =>
        ((m[key] ?? 0) as num).toInt();
    return ShopStats(
      bookings: pickInt(totals, 'bookings'),
      clients: pickInt(totals, 'uniqueClients') == 0
          ? pickInt(totals, 'clients')
          : pickInt(totals, 'uniqueClients'),
      revenue: pickInt(totals, 'revenue'),
      messages: ((sms['total'] ?? totals['messages'] ?? 0) as num).toInt(),
      todayRevenue: pickInt(totals, 'todayRevenue'),
      todayBookings: pickInt(totals, 'todayBookings'),
      todayCompleted: pickInt(totals, 'todayCompleted'),
      uniqueClients: pickInt(totals, 'uniqueClients'),
      newClients: pickInt(totals, 'newClients'),
      manualBookings: pickInt(totals, 'manualBookings'),
      fromSmsBookings: pickInt(totals, 'fromSmsBookings'),
      barbersCount: pickInt(totals, 'barbersCount'),
      clientsDueForReminder: pickInt(totals, 'clientsDueForReminder'),
      smsConfirmation: ((sms['confirmation'] ?? 0) as num).toInt(),
      smsReminder: ((sms['reminder'] ?? 0) as num).toInt(),
      smsRetention: ((sms['retention'] ?? 0) as num).toInt(),
      daily: dailyRaw
          .map((e) => e as Map<String, dynamic>)
          .map((m) => ShopDailyPoint(
                date: (m['date'] ?? '').toString(),
                bookings: ((m['bookings'] ?? 0) as num).toInt(),
                revenue: ((m['revenue'] ?? 0) as num).toInt(),
                newClients: ((m['newClients'] ?? 0) as num).toInt(),
              ))
          .toList(),
    );
  }
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
    required this.barberId,
    required this.barberName,
    required this.barberAvatar,
    required this.userName,
    required this.userPhone,
    required this.totalPrice,
    required this.totalDuration,
    required this.notes,
    required this.isManual,
  });
  final String id;
  final String date;
  final String time;
  final String status;
  final String barberId;
  final String barberName;
  final String? barberAvatar;
  final String userName;
  final String? userPhone;
  final int totalPrice;
  final int totalDuration;
  final String? notes;
  final bool isManual;

  factory ShopBooking.fromJson(Map<String, dynamic> json) => ShopBooking(
        id: json['id'].toString(),
        date: (json['date'] ?? '').toString(),
        time: (json['time'] ?? '').toString(),
        status: (json['status'] ?? 'confirmed').toString(),
        barberId: (json['barberId'] ?? '').toString(),
        barberName: (json['barberName'] ?? '').toString(),
        barberAvatar: (json['barberAvatar'] as String?)?.isEmpty ?? true
            ? null
            : json['barberAvatar'] as String,
        userName: (json['clientName'] ??
                json['userName'] ??
                json['guestName'] ??
                'Mijoz')
            .toString(),
        // Prefer guest* but fall through to user* — guest fields can be
        // nulled by the registration claim flow (when a guest later
        // signs up, the booking is linked to their userId + guest*
        // cleared). Mirrors web's BarberScheduleScreen fallback.
        userPhone: (() {
          final raw = json['clientPhone'] ??
              json['guestPhone'] ??
              json['userPhone'];
          if (raw is! String || raw.isEmpty) return null;
          return raw;
        })(),
        totalPrice: ((json['totalPrice'] ?? 0) as num).toInt(),
        totalDuration: ((json['totalDuration'] ?? 0) as num).toInt(),
        notes: (json['notes'] as String?)?.isEmpty ?? true
            ? null
            : json['notes'] as String,
        isManual: json['isManual'] == true,
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
    final r = await barbersPaged(page: page, limit: limit, search: search);
    return r.data;
  }

  /// Paged variant returning total + page metadata. Mirrors web
  /// `listShopBarbersAPI` envelope so the UI can render Prev/Next.
  Future<({List<ShopBarber> data, int total, int totalPages, bool hasMore})>
      barbersPaged({int page = 1, int limit = 20, String? search}) async {
    final res = await _dio.get('/barbershop/barbers', queryParameters: {
      'page': page,
      'limit': limit,
      'search': ?(search?.isEmpty ?? true) ? null : search,
    });
    final data = res.data;
    final raw = (data is List)
        ? data
        : (data is Map && data['data'] is List ? data['data'] as List : <dynamic>[]);
    final meta = data is Map && data['meta'] is Map
        ? (data['meta'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    return (
      data: raw
          .cast<Map<String, dynamic>>()
          .map(ShopBarber.fromJson)
          .toList(),
      total: ((meta['total'] ?? raw.length) as num).toInt(),
      totalPages: ((meta['totalPages'] ?? 1) as num).toInt(),
      hasMore: meta['hasMore'] == true,
    );
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

  /// Poll the blast job's current state. The progress modal calls this
  /// on a 2-second interval while status == RUNNING.
  Future<Map<String, dynamic>> blastJob(String jobId) async {
    final res = await _dio.get('/blast-jobs/$jobId');
    return Map<String, dynamic>.from(res.data as Map);
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

  /// GET /barbershop/balance — owner's balance for the transactions
  /// screen header.
  Future<int> balance() async {
    final res = await _dio.get('/barbershop/balance');
    final data = res.data;
    if (data is Map && data['balance'] != null) {
      return ((data['balance']) as num).toInt();
    }
    return 0;
  }

  // Bookings
  Future<List<ShopBooking>> bookings({
    String? date,
    String? barberId,
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final r = await bookingsPaged(
        date: date,
        barberId: barberId,
        status: status,
        page: page,
        limit: limit);
    return r.data;
  }

  /// Paged variant — used by ShopBookings screen so the owner can browse
  /// past dates without the single-day filter. Web returns
  /// {data, meta:{total,totalPages,hasMore}}.
  Future<({List<ShopBooking> data, int total, int totalPages, bool hasMore})>
      bookingsPaged({
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
      if (status != null && status.isNotEmpty && status != 'all')
        'status': status,
      'page': page,
      'limit': limit,
    });
    final data = res.data;
    final raw = (data is List)
        ? data
        : (data is Map && data['data'] is List ? data['data'] as List : <dynamic>[]);
    final meta = data is Map && data['meta'] is Map
        ? (data['meta'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    return (
      data: raw
          .cast<Map<String, dynamic>>()
          .map(ShopBooking.fromJson)
          .toList(),
      total: ((meta['total'] ?? raw.length) as num).toInt(),
      totalPages: ((meta['totalPages'] ?? 1) as num).toInt(),
      hasMore: meta['hasMore'] == true,
    );
  }
}

final shopRepositoryProvider =
    Provider<ShopRepository>((ref) => ShopRepository(ref.watch(dioProvider)));

/// Watching the auth state ensures a fresh /barbershop/me call after a
/// logout + re-login as a different shop owner — otherwise the cached
/// previous shop's name + balance would persist until manual refresh.
final shopMeProvider = FutureProvider<Map<String, dynamic>>((ref) {
  ref.watch(authControllerProvider.select((s) => s.user?.id));
  return ref.watch(shopRepositoryProvider).me();
});
final shopStatsProvider = FutureProvider<ShopStats>((ref) {
  ref.watch(authControllerProvider.select((s) => s.user?.id));
  return ref.watch(shopRepositoryProvider).stats();
});

/// Filtered stats keyed on (from, to) — used by the dashboard's date-range
/// picker. Mirrors web's `getShopStatsAPI({from, to})`. Pass `null` for both
/// to fall through to the default 30-day window.
typedef ShopStatsKey = ({String? from, String? to});
final shopStatsFilteredProvider =
    FutureProvider.family<ShopStats, ShopStatsKey>((ref, k) async {
  return ref.watch(shopRepositoryProvider).stats(from: k.from, to: k.to);
});
final shopBarbersProvider = FutureProvider<List<ShopBarber>>((ref) {
  ref.watch(authControllerProvider.select((s) => s.user?.id));
  return ref.watch(shopRepositoryProvider).barbers(limit: 100);
});

typedef ShopBarbersKey = ({String? search, int page});

final shopBarbersPagedProvider = FutureProvider.family<
    ({List<ShopBarber> data, int total, int totalPages, bool hasMore}),
    ShopBarbersKey>((ref, k) {
  return ref
      .watch(shopRepositoryProvider)
      .barbersPaged(page: k.page, search: k.search);
});
final shopBookingsProvider = FutureProvider<List<ShopBooking>>((ref) {
  ref.watch(authControllerProvider.select((s) => s.user?.id));
  return ref.watch(shopRepositoryProvider).bookings();
});
final shopBalanceProvider = FutureProvider<int>((ref) {
  ref.watch(authControllerProvider.select((s) => s.user?.id));
  return ref.watch(shopRepositoryProvider).balance();
});

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
    final r = await smsLogFiltered(page: page, limit: limit);
    return r.data;
  }

  /// Filtered + paginated. Mirrors web `getShopSmsLogsAPI` — barberId,
  /// type and date range are all server-side.
  Future<({List<ShopSmsLogEntry> data, int total})> smsLogFiltered({
    String? barberId,
    String? type,
    String? from,
    String? to,
    int page = 1,
    int limit = 30,
  }) async {
    // Backend: GET /barbershop/sms-logs (barbershop.controller.ts:278).
    // Old /barbershop/sms had no handler — shop SMS history always empty.
    final res = await _dio.get('/barbershop/sms-logs', queryParameters: {
      'page': page,
      'limit': limit,
      'barberId': ?barberId,
      'type': ?type,
      'from': ?from,
      'to': ?to,
    });
    final data = res.data;
    final list = (data is List)
        ? data
        : (data is Map && data['data'] is List ? data['data'] as List : <dynamic>[]);
    final meta = data is Map && data['meta'] is Map
        ? (data['meta'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    return (
      data: list
          .cast<Map<String, dynamic>>()
          .map(ShopSmsLogEntry.fromJson)
          .toList(),
      total: ((meta['total'] ?? list.length) as num).toInt(),
    );
  }

  Future<List<ShopTxnEntry>> transactions({int page = 1, int limit = 30}) async {
    final r = await transactionsFiltered(page: page, limit: limit);
    return r.data;
  }

  /// Filtered + paginated. Mirrors web `getShopTransactionsAPI`: type,
  /// direction (income/expense), barberId, smsType, date range.
  Future<({List<ShopTxnEntry> data, int total})> transactionsFiltered({
    String? type,
    String? direction,
    String? barberId,
    String? smsType,
    String? from,
    String? to,
    int page = 1,
    int limit = 20,
  }) async {
    final res =
        await _dio.get('/barbershop/transactions', queryParameters: {
      'page': page,
      'limit': limit,
      'type': ?type,
      'direction': ?direction,
      'barberId': ?barberId,
      'smsType': ?smsType,
      'from': ?from,
      'to': ?to,
    });
    final data = res.data;
    final list = (data is List)
        ? data
        : (data is Map && data['data'] is List ? data['data'] as List : <dynamic>[]);
    final meta = data is Map && data['meta'] is Map
        ? (data['meta'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    return (
      data: list
          .cast<Map<String, dynamic>>()
          .map(ShopTxnEntry.fromJson)
          .toList(),
      total: ((meta['total'] ?? list.length) as num).toInt(),
    );
  }
}

final shopClientsProvider = FutureProvider<List<ShopClient>>((ref) {
  ref.watch(authControllerProvider.select((s) => s.user?.id));
  return ref.watch(shopRepositoryProvider).clients();
});
final shopSmsLogProvider = FutureProvider<List<ShopSmsLogEntry>>((ref) {
  ref.watch(authControllerProvider.select((s) => s.user?.id));
  return ref.watch(shopRepositoryProvider).smsLog();
});

typedef ShopSmsKey = ({
  String? barberId,
  String? type,
  String? from,
  String? to,
  int page,
});

final shopSmsFilteredProvider = FutureProvider.family<
    ({List<ShopSmsLogEntry> data, int total}), ShopSmsKey>((ref, k) async {
  return ref.watch(shopRepositoryProvider).smsLogFiltered(
      barberId: k.barberId,
      type: k.type,
      from: k.from,
      to: k.to,
      page: k.page);
});
final shopTransactionsProvider = FutureProvider<List<ShopTxnEntry>>((ref) {
  ref.watch(authControllerProvider.select((s) => s.user?.id));
  return ref.watch(shopRepositoryProvider).transactions();
});

typedef ShopTxnKey = ({
  String? type,
  String? direction,
  String? barberId,
  String? smsType,
  String? from,
  String? to,
  int page,
});

final shopTxnFilteredProvider = FutureProvider.family<
    ({List<ShopTxnEntry> data, int total}), ShopTxnKey>((ref, k) async {
  return ref.watch(shopRepositoryProvider).transactionsFiltered(
      type: k.type,
      direction: k.direction,
      barberId: k.barberId,
      smsType: k.smsType,
      from: k.from,
      to: k.to,
      page: k.page);
});
