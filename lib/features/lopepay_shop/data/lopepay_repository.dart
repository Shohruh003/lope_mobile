import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../auth/presentation/auth_controller.dart';

class LopepayCustomer {
  LopepayCustomer({
    required this.id,
    required this.name,
    required this.phone,
    required this.totalDebt,
    this.nextDue,
    this.address,
  });
  final String id;
  final String name;
  final String phone;
  final int totalDebt;
  final DateTime? nextDue;
  final String? address;

  factory LopepayCustomer.fromJson(Map<String, dynamic> json) => LopepayCustomer(
        id: json['id']?.toString() ?? '',
        name: (json['name'] ?? '').toString(),
        phone: (json['phone'] ?? '').toString(),
        totalDebt: ((json['totalDebt'] ?? json['debt'] ?? 0) as num).toInt(),
        nextDue: json['nextDue'] != null ? DateTime.tryParse(json['nextDue'].toString()) : null,
        address: json['address']?.toString(),
      );
}

class LopepayProduct {
  LopepayProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.isActive,
    required this.installmentsCount,
  });
  final String id;
  final String name;
  final int price;
  final bool isActive;
  final int installmentsCount;

  factory LopepayProduct.fromJson(Map<String, dynamic> json) {
    final count = json['_count'] is Map
        ? (((json['_count'] as Map)['installments'] ?? 0) as num).toInt()
        : 0;
    return LopepayProduct(
      id: json['id']?.toString() ?? '',
      name: (json['name'] ?? '').toString(),
      price: ((json['price'] ?? json['defaultPrice'] ?? 0) as num).toInt(),
      isActive: json['isActive'] != false,
      installmentsCount: count,
    );
  }
}

class LopepayDashboard {
  LopepayDashboard({required this.dueToday, required this.overdue, required this.totalReceivable, required this.activeCustomers});
  final int dueToday;
  final int overdue;
  final int totalReceivable;
  final int activeCustomers;

  factory LopepayDashboard.fromJson(Map<String, dynamic> json) => LopepayDashboard(
        dueToday: ((json['dueToday'] ?? 0) as num).toInt(),
        overdue: ((json['overdue'] ?? 0) as num).toInt(),
        totalReceivable: ((json['totalReceivable'] ?? 0) as num).toInt(),
        activeCustomers: ((json['activeCustomers'] ?? 0) as num).toInt(),
      );
}

/// GET /shops/me — shop record for the logged-in owner. Used by the
/// LopePay dashboard header (shop name + address) and the balance tile.
class LopepayShopMe {
  LopepayShopMe({
    required this.name,
    required this.address,
    required this.ownerBalance,
    required this.totalInstallments,
  });
  final String name;
  final String address;
  final int ownerBalance;
  final int totalInstallments;

  factory LopepayShopMe.fromJson(Map<String, dynamic> json) {
    final owner = (json['owner'] is Map)
        ? Map<String, dynamic>.from(json['owner'] as Map)
        : <String, dynamic>{};
    final count = (json['_count'] is Map)
        ? Map<String, dynamic>.from(json['_count'] as Map)
        : <String, dynamic>{};
    return LopepayShopMe(
      name: (json['name'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      ownerBalance: ((owner['balance'] ?? 0) as num).toInt(),
      totalInstallments: ((count['installments'] ?? 0) as num).toInt(),
    );
  }
}

class LopepayRepository {
  LopepayRepository(this._dio);
  final Dio _dio;

  /// There's no single dashboard endpoint on the backend — web composes
  /// these tiles from /installments and /installments/due-today client-side.
  /// We mirror that here so the LopePay shop home doesn't 404.
  Future<LopepayDashboard> dashboard() async {
    int dueToday = 0;
    int overdue = 0;
    int totalReceivable = 0;
    final customerPhones = <String>{};
    try {
      final res = await _dio.get('/installments/due-today');
      final data = res.data;
      final list = (data is List)
          ? data
          : (data is Map && data['data'] is List ? data['data'] as List : <dynamic>[]);
      dueToday = list.length;
    } catch (_) {}
    try {
      // All active installments — sum of remainingAmount + customer set.
      final res = await _dio.get('/installments', queryParameters: {
        'isActive': true,
        'limit': 500,
      });
      final data = res.data;
      final list = (data is List)
          ? data
          : (data is Map && data['data'] is List ? data['data'] as List : <dynamic>[]);
      for (final raw in list) {
        if (raw is! Map) continue;
        final m = raw.cast<String, dynamic>();
        // Backend exposes the calculated remaining as `debt` (installments.
        // service.ts:67), not `remainingAmount`. Reading the wrong key made
        // the 'Total receivable' tile read 0 for every active loan.
        final remaining = m['debt'] ?? m['totalPrice'] ?? 0;
        totalReceivable += (remaining as num).toInt();
        final status = (m['status'] ?? '').toString();
        if (status == 'overdue') overdue += 1;
        final phone = (m['customerPhone'] ?? '').toString();
        if (phone.isNotEmpty) customerPhones.add(phone);
      }
    } catch (_) {}
    return LopepayDashboard(
      dueToday: dueToday,
      overdue: overdue,
      totalReceivable: totalReceivable,
      activeCustomers: customerPhones.length,
    );
  }

  /// GET /shops/me — returns the owner's shop with balance + total
  /// installment count for the dashboard header.
  Future<LopepayShopMe> shopMe() async {
    final res = await _dio.get('/shops/me');
    return LopepayShopMe.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  /// There's no /lopepay/customers endpoint — backend doesn't expose a
  /// dedicated customer list. We aggregate from /installments grouped by
  /// customer phone, the same shape the web's customer list uses.
  Future<List<LopepayCustomer>> customers({int page = 1, int limit = 30, String? search}) async {
    final res = await _dio.get('/installments', queryParameters: {
      // ignore: use_null_aware_elements
      if (search != null && search.isNotEmpty) 'search': search,
      'limit': 500,
    });
    final data = res.data;
    final list = (data is List)
        ? data
        : (data is Map && data['data'] is List ? data['data'] as List : <dynamic>[]);
    // Backend's installment response has flat customerName / customerPhone
    // columns + a `debt` snapshot (installments.service.ts:67) — there is
    // NO nested `customer` object and no `remainingAmount` field. Reading
    // those would silently return null + 0, so every customer card showed
    // 0 so'm debt regardless of how much they owed.
    final byPhone = <String, LopepayCustomer>{};
    for (final raw in list) {
      if (raw is! Map) continue;
      final m = raw.cast<String, dynamic>();
      final phone = (m['customerPhone'] ?? '').toString();
      if (phone.isEmpty) continue;
      final remaining = ((m['debt'] ?? m['remainingAmount'] ?? 0) as num).toInt();
      final next = m['nextDueDate']?.toString();
      final existing = byPhone[phone];
      byPhone[phone] = LopepayCustomer(
        id: phone,
        name: (m['customerName'] ?? existing?.name ?? '').toString(),
        phone: phone,
        totalDebt: (existing?.totalDebt ?? 0) + remaining,
        nextDue: next != null ? DateTime.tryParse(next) : existing?.nextDue,
        address: existing?.address,
      );
    }
    final result = byPhone.values.toList()
      ..sort((a, b) => b.totalDebt.compareTo(a.totalDebt));
    return result;
  }

  Future<List<LopepayProduct>> products({String? search}) async {
    // Backend: GET /shop-products (shop-products.controller.ts:25).
    // /lopepay/products had no handler — products screen always 404'd.
    final res = await _dio.get('/shop-products', queryParameters: {
      'search': ?search,
    });
    final data = res.data;
    final list = (data is List)
        ? data
        : (data is Map && data['data'] is List ? data['data'] as List : <dynamic>[]);
    return list.cast<Map<String, dynamic>>().map(LopepayProduct.fromJson).toList();
  }

  /// PATCH /shop-products/:id — update name/price/isActive.
  Future<void> updateProduct(String id,
      {String? name, int? defaultPrice, bool? isActive}) async {
    await _dio.patch('/shop-products/$id', data: {
      'name': ?name,
      'defaultPrice': ?defaultPrice,
      'isActive': ?isActive,
    });
  }

  /// DELETE /shop-products/:id.
  Future<void> deleteProduct(String id) async {
    await _dio.delete('/shop-products/$id');
  }

  /// POST /installments — creates a new installment plan for a
  /// customer. Server creates the customer record if one with the given
  /// phone doesn't already exist. Returns the new installment id.
  Future<String> createInstallment(Map<String, dynamic> data) async {
    final res = await _dio.post('/installments', data: data);
    final body = res.data;
    if (body is Map && body['id'] != null) return body['id'].toString();
    return '';
  }

  /// PATCH /installments/:id — updates plan fields. Money/date
  /// fields are validated server-side.
  Future<void> updateInstallment(String id, Map<String, dynamic> data) async {
    await _dio.patch('/installments/$id', data: data);
  }

  /// POST /installments/:id/mark-paid — marks the next outstanding
  /// month as paid. Optional amount lets the shop owner record a
  /// partial / over payment; otherwise the server uses monthlyPayment.
  Future<void> markInstallmentPaid(String id, {int? amount}) async {
    await _dio.post('/installments/$id/mark-paid',
        data: amount == null ? <String, dynamic>{} : {'amount': amount});
  }

  /// POST /installments/:id/undo-last-payment — reverses the most
  /// recent month-paid action (mistakes happen).
  Future<void> undoLastInstallmentPayment(String id) async {
    await _dio.post('/installments/$id/undo-last-payment');
  }

  /// DELETE /installments/:id — owner deletes the whole installment.
  /// Server soft-deletes / removes per its policy.
  Future<void> deleteInstallment(String id) async {
    await _dio.delete('/installments/$id');
  }

  /// GET /installments/:id — used by the edit form to seed the
  /// fields.
  Future<Map<String, dynamic>> getInstallment(String id) async {
    final res = await _dio.get('/installments/$id');
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// POST /shop-products — quick add from the customer form's product
  /// dropdown. Returns the new product so the form can select it.
  Future<LopepayProduct> createProduct({required String name, int? defaultPrice}) async {
    final res = await _dio.post('/shop-products', data: {
      'name': name,
      'defaultPrice': ?defaultPrice,
    });
    return LopepayProduct.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<List<Map<String, dynamic>>> sms() async {
    final r = await smsFiltered();
    return r.data;
  }

  /// Filtered + paginated variant — matches web `shopSmsHistoryAPI`.
  Future<({List<Map<String, dynamic>> data, int total}) > smsFiltered({
    String? phone,
    String? type,
    String? productId,
    String? from,
    String? to,
    int page = 1,
    int limit = 20,
  }) async {
    // Backend: GET /shop-history/sms (shop-history.controller.ts:14).
    final res = await _dio.get('/shop-history/sms', queryParameters: {
      'phone': ?phone,
      'type': ?type,
      'productId': ?productId,
      'from': ?from,
      'to': ?to,
      'page': page,
      'limit': limit,
    });
    final data = res.data;
    final list = (data is List)
        ? data
        : (data is Map && data['data'] is List ? data['data'] as List : <dynamic>[]);
    final meta = data is Map && data['meta'] is Map
        ? (data['meta'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    return (
      data: list.cast<Map<String, dynamic>>(),
      total: ((meta['total'] ?? list.length) as num).toInt(),
    );
  }

  Future<List<Map<String, dynamic>>> transactions() async {
    final r = await transactionsFiltered();
    return r.data;
  }

  /// Filtered + paginated variant. Returns the balance the backend sends
  /// alongside the page so the screen can render the "current balance"
  /// card without a second round-trip. Mirrors web `shopTransactionsAPI`.
  Future<({List<Map<String, dynamic>> data, int total, int balance})>
      transactionsFiltered({
    String? type,
    String? from,
    String? to,
    int page = 1,
    int limit = 20,
  }) async {
    // Backend: GET /shop-history/transactions (shop-history.controller.ts:36).
    final res = await _dio.get('/shop-history/transactions', queryParameters: {
      'type': ?type,
      'from': ?from,
      'to': ?to,
      'page': page,
      'limit': limit,
    });
    final data = res.data;
    final list = (data is List)
        ? data
        : (data is Map && data['data'] is List ? data['data'] as List : <dynamic>[]);
    final meta = data is Map && data['meta'] is Map
        ? (data['meta'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    final balance = data is Map ? data['balance'] : null;
    return (
      data: list.cast<Map<String, dynamic>>(),
      total: ((meta['total'] ?? list.length) as num).toInt(),
      balance: ((balance ?? 0) as num).toInt(),
    );
  }

  /// Installments due today — used by the dashboard's "Bugun" section.
  /// Web: `dueTodayInstallmentsAPI()`.
  Future<List<Map<String, dynamic>>> dueTodayInstallments() async {
    try {
      // Backend: GET /installments/due-today (installments.controller.ts:51).
      final res = await _dio.get('/installments/due-today');
      final data = res.data;
      final list = (data is List)
          ? data
          : (data is Map && data['data'] is List ? data['data'] as List : <dynamic>[]);
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// GET /lopepay/installments — full installment list with filters.
  /// Web's listInstallmentsAPI shape. Returns the raw map so callers
  /// can pluck status / daysLate / monthsPaid / nextDueDate without a
  /// per-row class.
  Future<({List<Map<String, dynamic>> data, int total})>
      listInstallments({
    String? search,
    String? phone,
    String? productId,
    String? status,
    String? from,
    String? to,
    int page = 1,
    int limit = 50,
  }) async {
    // Backend: GET /installments (installments.controller.ts:25).
    final res = await _dio.get('/installments', queryParameters: {
      'search': ?search,
      'phone': ?phone,
      'productId': ?productId,
      'status': ?status,
      'from': ?from,
      'to': ?to,
      'page': page,
      'limit': limit,
    });
    final data = res.data;
    if (data is List) {
      return (data: data.cast<Map<String, dynamic>>(), total: data.length);
    }
    if (data is Map) {
      final list = (data['data'] is List ? data['data'] as List : <dynamic>[])
          .cast<Map<String, dynamic>>();
      final meta = data['meta'] is Map ? data['meta'] as Map : null;
      final total = ((meta?['total'] ?? list.length) as num).toInt();
      return (data: list, total: total);
    }
    return (data: <Map<String, dynamic>>[], total: 0);
  }

  /// Active overdue installments — used by the dashboard's "Muddati o'tgan"
  /// section. Web: `listInstallmentsAPI({status: 'overdue', limit: 5})`.
  Future<List<Map<String, dynamic>>> overdueInstallments({int limit = 5}) async {
    try {
      final res = await _dio.get('/installments',
          queryParameters: {'status': 'overdue', 'limit': limit, 'isActive': true});
      final data = res.data;
      final list = (data is List)
          ? data
          : (data is Map && data['data'] is List ? data['data'] as List : <dynamic>[]);
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }
}

final lopepaySmsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  ref.watch(authControllerProvider.select((s) => s.user?.id));
  return ref.watch(lopepayRepositoryProvider).sms();
});
final lopepayTxnProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  ref.watch(authControllerProvider.select((s) => s.user?.id));
  return ref.watch(lopepayRepositoryProvider).transactions();
});

typedef LopepaySmsKey = ({
  String? phone,
  String? type,
  String? productId,
  String? from,
  String? to,
  int page,
});

final lopepaySmsFilteredProvider = FutureProvider.family<
    ({List<Map<String, dynamic>> data, int total}),
    LopepaySmsKey>((ref, k) async {
  return ref.watch(lopepayRepositoryProvider).smsFiltered(
      phone: k.phone,
      type: k.type,
      productId: k.productId,
      from: k.from,
      to: k.to,
      page: k.page);
});

typedef LopepayTxnKey = ({String? type, String? from, String? to, int page});

final lopepayTxnFilteredProvider = FutureProvider.family<
    ({List<Map<String, dynamic>> data, int total, int balance}),
    LopepayTxnKey>((ref, k) async {
  return ref.watch(lopepayRepositoryProvider).transactionsFiltered(
      type: k.type, from: k.from, to: k.to, page: k.page);
});

final lopepayRepositoryProvider = Provider<LopepayRepository>(
    (ref) => LopepayRepository(ref.watch(dioProvider)));

// Auth-watched so a logout + sign-in as a different shop owner triggers a
// fresh fetch. Without this, the dashboard / shop-me / customers / products
// would all return the previous user's cached snapshot until manually
// refreshed.
final lopepayDashboardProvider = FutureProvider<LopepayDashboard>((ref) {
  ref.watch(authControllerProvider.select((s) => s.user?.id));
  return ref.watch(lopepayRepositoryProvider).dashboard();
});

final lopepayShopMeProvider = FutureProvider<LopepayShopMe>((ref) {
  ref.watch(authControllerProvider.select((s) => s.user?.id));
  return ref.watch(lopepayRepositoryProvider).shopMe();
});

final lopepayCustomersProvider = FutureProvider<List<LopepayCustomer>>((ref) {
  ref.watch(authControllerProvider.select((s) => s.user?.id));
  return ref.watch(lopepayRepositoryProvider).customers();
});

final lopepayProductsProvider = FutureProvider<List<LopepayProduct>>((ref) {
  ref.watch(authControllerProvider.select((s) => s.user?.id));
  return ref.watch(lopepayRepositoryProvider).products();
});

/// Search-filtered variant — used by the products screen's search bar.
final lopepayProductsFilteredProvider =
    FutureProvider.family<List<LopepayProduct>, String>((ref, search) =>
        ref.watch(lopepayRepositoryProvider).products(
            search: search.isEmpty ? null : search));

final lopepayDueTodayProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  ref.watch(authControllerProvider.select((s) => s.user?.id));
  return ref.watch(lopepayRepositoryProvider).dueTodayInstallments();
});

final lopepayOverdueProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  ref.watch(authControllerProvider.select((s) => s.user?.id));
  return ref.watch(lopepayRepositoryProvider).overdueInstallments();
});
