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

class LopepayRepository {
  LopepayRepository(this._dio);
  final Dio _dio;

  Future<LopepayDashboard> dashboard() async {
    final res = await _dio.get('/lopepay/dashboard');
    return LopepayDashboard.fromJson(Map<String, dynamic>.from(res.data as Map));
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
}

final lopepayRepositoryProvider = Provider<LopepayRepository>(
    (ref) => LopepayRepository(ref.watch(dioProvider)));

final lopepayDashboardProvider = FutureProvider<LopepayDashboard>(
    (ref) => ref.watch(lopepayRepositoryProvider).dashboard());

final lopepayCustomersProvider = FutureProvider<List<LopepayCustomer>>(
    (ref) => ref.watch(lopepayRepositoryProvider).customers());

final lopepayProductsProvider = FutureProvider<List<LopepayProduct>>(
    (ref) => ref.watch(lopepayRepositoryProvider).products());
