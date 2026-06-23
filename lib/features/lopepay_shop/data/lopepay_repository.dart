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
  LopepayProduct({required this.id, required this.name, required this.price});
  final String id;
  final String name;
  final int price;
  factory LopepayProduct.fromJson(Map<String, dynamic> json) => LopepayProduct(
        id: json['id']?.toString() ?? '',
        name: (json['name'] ?? '').toString(),
        price: ((json['price'] ?? 0) as num).toInt(),
      );
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

  Future<List<LopepayProduct>> products() async {
    final res = await _dio.get('/lopepay/products');
    final data = res.data;
    final list = (data is List)
        ? data
        : (data is Map && data['data'] is List ? data['data'] as List : <dynamic>[]);
    return list.cast<Map<String, dynamic>>().map(LopepayProduct.fromJson).toList();
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
    final res = await _dio.get('/lopepay/transactions');
    final data = res.data;
    final list = (data is List)
        ? data
        : (data is Map && data['data'] is List ? data['data'] as List : <dynamic>[]);
    return list.cast<Map<String, dynamic>>();
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

final lopepayDueTodayProvider = FutureProvider<List<Map<String, dynamic>>>(
    (ref) => ref.watch(lopepayRepositoryProvider).dueTodayInstallments());

final lopepayOverdueProvider = FutureProvider<List<Map<String, dynamic>>>(
    (ref) => ref.watch(lopepayRepositoryProvider).overdueInstallments());
