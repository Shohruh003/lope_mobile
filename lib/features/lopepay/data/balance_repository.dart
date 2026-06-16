import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';

class BalanceState {
  BalanceState({required this.amount, this.aiFreeRemaining});
  final int amount;
  final int? aiFreeRemaining;
}

class PaymentEntry {
  PaymentEntry({
    required this.id,
    required this.amount,
    required this.method,
    required this.direction,
    required this.createdAt,
    this.description,
    this.balanceAfter,
  });
  final String id;
  final int amount;
  final String method;
  final String direction; // 'in' | 'out'
  final String? description;
  final int? balanceAfter;
  final DateTime createdAt;

  factory PaymentEntry.fromJson(Map<String, dynamic> json) => PaymentEntry(
        id: json['id']?.toString() ?? '',
        amount: ((json['amount'] ?? 0) as num).toInt(),
        method: (json['method'] ?? 'internal').toString(),
        direction: (json['direction'] ?? (((json['amount'] ?? 0) as num) >= 0 ? 'in' : 'out')).toString(),
        description: json['description']?.toString(),
        balanceAfter: json['balanceAfter'] == null ? null : ((json['balanceAfter']) as num).toInt(),
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
}

class BalanceRepository {
  BalanceRepository(this._dio);
  final Dio _dio;

  Future<BalanceState> myBalance(String userId) async {
    final res = await _dio.get('/users/$userId/balance');
    final raw = res.data;
    if (raw is Map) {
      return BalanceState(
        amount: ((raw['amount'] ?? raw['balance'] ?? 0) as num).toInt(),
        aiFreeRemaining: raw['aiFreeRemaining'] == null ? null : ((raw['aiFreeRemaining']) as num).toInt(),
      );
    }
    return BalanceState(amount: ((raw ?? 0) as num).toInt());
  }

  Future<List<PaymentEntry>> history({
    required String userId,
    String direction = 'all',
    String method = 'all',
    String? from,
    String? to,
    int page = 1,
    int limit = 20,
  }) async {
    final res = await _dio.get('/users/$userId/payment-history', queryParameters: {
      if (direction != 'all') 'direction': direction,
      if (method != 'all') 'method': method,
      // ignore: use_null_aware_elements
      if (from != null) 'from': from,
      // ignore: use_null_aware_elements
      if (to != null) 'to': to,
      'page': page,
      'limit': limit,
    });
    final data = res.data;
    final list = (data is List)
        ? data
        : (data is Map && data['data'] is List ? data['data'] as List : <dynamic>[]);
    return list.cast<Map<String, dynamic>>().map(PaymentEntry.fromJson).toList();
  }

  /// Returns the gateway URL the user should be redirected to.
  Future<String> initiateTopUp({
    required String userId,
    required int amount,
    required String gateway, // 'click' | 'payme'
  }) async {
    final path = gateway == 'payme' ? '/payme/initiate' : '/click/initiate';
    final res = await _dio.post(path, data: {'userId': userId, 'amount': amount});
    final url = (res.data is Map) ? (res.data['url'] ?? res.data['redirectUrl']) : null;
    return url?.toString() ?? '';
  }
}

final balanceRepositoryProvider =
    Provider<BalanceRepository>((ref) => BalanceRepository(ref.watch(dioProvider)));

final myBalanceProvider = FutureProvider.family<BalanceState, String>(
    (ref, userId) => ref.watch(balanceRepositoryProvider).myBalance(userId));

final paymentHistoryProvider = FutureProvider.family<List<PaymentEntry>, String>(
    (ref, userId) => ref.watch(balanceRepositoryProvider).history(userId: userId));
