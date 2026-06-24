import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';

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

  Future<LopepayDashboard> dashboard() async {
    final res = await _dio.get('/lopepay/dashboard');
    return LopepayDashboard.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  /// GET /shops/me — returns the owner's shop with balance + total
  /// installment count for the dashboard header.
  Future<LopepayShopMe> shopMe() async {
    final res = await _dio.get('/shops/me');
    return LopepayShopMe.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<List<LopepayCustomer>> customers({int page = 1, int limit = 30, String? search}) async {
    final res = await _dio.get('/lopepay/customers', queryParameters: {
      'page': page, 'limit': limit,
      // ignore: use_null_aware_elements
      if (search != null && search.isNotEmpty) 'search': search,
    });
    final data = res.data;
    final list = (data is List)
        ? data
        : (data is Map && data['data'] is List ? data['data'] as List : <dynamic>[]);
    return list.cast<Map<String, dynamic>>().map(LopepayCustomer.fromJson).toList();
  }

  Future<List<LopepayProduct>> products({String? search}) async {
    final res = await _dio.get('/lopepay/products', queryParameters: {
      'search': ?search,
    });
    final data = res.data;
    final list = (data is List)
        ? data
        : (data is Map && data['data'] is List ? data['data'] as List : <dynamic>[]);
    return list.cast<Map<String, dynamic>>().map(LopepayProduct.fromJson).toList();
  }

  /// PATCH /lopepay/products/:id — update name/price/isActive.
  Future<void> updateProduct(String id,
      {String? name, int? defaultPrice, bool? isActive}) async {
    await _dio.patch('/lopepay/products/$id', data: {
      'name': ?name,
      'defaultPrice': ?defaultPrice,
      'isActive': ?isActive,
    });
  }

  /// DELETE /lopepay/products/:id.
  Future<void> deleteProduct(String id) async {
    await _dio.delete('/lopepay/products/$id');
  }

  Future<void> recordPayment(String customerId, int amount) async {
    await _dio.post('/lopepay/customers/$customerId/payments', data: {'amount': amount});
  }

  /// POST /lopepay/installments — creates a new installment plan for a
  /// customer. Server creates the customer record if one with the given
  /// phone doesn't already exist. Returns the new installment id.
  Future<String> createInstallment(Map<String, dynamic> data) async {
    final res = await _dio.post('/lopepay/installments', data: data);
    final body = res.data;
    if (body is Map && body['id'] != null) return body['id'].toString();
    return '';
  }

  /// PATCH /lopepay/installments/:id — updates plan fields. Money/date
  /// fields are validated server-side.
  Future<void> updateInstallment(String id, Map<String, dynamic> data) async {
    await _dio.patch('/lopepay/installments/$id', data: data);
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

  /// GET /lopepay/installments/:id — used by the edit form to seed the
  /// fields.
  Future<Map<String, dynamic>> getInstallment(String id) async {
    final res = await _dio.get('/lopepay/installments/$id');
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// POST /lopepay/products — quick add from the customer form's product
  /// dropdown. Returns the new product so the form can select it.
  Future<LopepayProduct> createProduct({required String name, int? defaultPrice}) async {
    final res = await _dio.post('/lopepay/products', data: {
      'name': name,
      'defaultPrice': ?defaultPrice,
    });
    return LopepayProduct.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<List<Map<String, dynamic>>> sms() async {
    final res = await _dio.get('/lopepay/sms');
    final data = res.data;
    final list = (data is List)
        ? data
        : (data is Map && data['data'] is List ? data['data'] as List : <dynamic>[]);
    return list.cast<Map<String, dynamic>>();
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
    final res = await _dio.get('/lopepay/transactions', queryParameters: {
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
      final res = await _dio.get('/lopepay/installments/due-today');
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
    final res = await _dio.get('/lopepay/installments', queryParameters: {
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
      final res = await _dio.get('/lopepay/installments',
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

final lopepaySmsProvider = FutureProvider<List<Map<String, dynamic>>>(
    (ref) => ref.watch(lopepayRepositoryProvider).sms());
final lopepayTxnProvider = FutureProvider<List<Map<String, dynamic>>>(
    (ref) => ref.watch(lopepayRepositoryProvider).transactions());

typedef LopepayTxnKey = ({String? type, String? from, String? to, int page});

final lopepayTxnFilteredProvider = FutureProvider.family<
    ({List<Map<String, dynamic>> data, int total, int balance}),
    LopepayTxnKey>((ref, k) async {
  return ref.watch(lopepayRepositoryProvider).transactionsFiltered(
      type: k.type, from: k.from, to: k.to, page: k.page);
});

final lopepayRepositoryProvider = Provider<LopepayRepository>(
    (ref) => LopepayRepository(ref.watch(dioProvider)));

final lopepayDashboardProvider = FutureProvider<LopepayDashboard>(
    (ref) => ref.watch(lopepayRepositoryProvider).dashboard());

final lopepayShopMeProvider = FutureProvider<LopepayShopMe>(
    (ref) => ref.watch(lopepayRepositoryProvider).shopMe());

final lopepayCustomersProvider = FutureProvider<List<LopepayCustomer>>(
    (ref) => ref.watch(lopepayRepositoryProvider).customers());

final lopepayProductsProvider = FutureProvider<List<LopepayProduct>>(
    (ref) => ref.watch(lopepayRepositoryProvider).products());

/// Search-filtered variant — used by the products screen's search bar.
final lopepayProductsFilteredProvider =
    FutureProvider.family<List<LopepayProduct>, String>((ref, search) =>
        ref.watch(lopepayRepositoryProvider).products(
            search: search.isEmpty ? null : search));

final lopepayDueTodayProvider = FutureProvider<List<Map<String, dynamic>>>(
    (ref) => ref.watch(lopepayRepositoryProvider).dueTodayInstallments());

final lopepayOverdueProvider = FutureProvider<List<Map<String, dynamic>>>(
    (ref) => ref.watch(lopepayRepositoryProvider).overdueInstallments());
