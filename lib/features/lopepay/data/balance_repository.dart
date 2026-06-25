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
    // Backend endpoint: GET /balance/me (JWT-resolved). The old
    // /users/:id/balance call hit a non-existent route and returned 404
    // → 0 balance everywhere, top-up button hidden, low-balance modal
    // perpetually popped.
    final res = await _dio.get('/balance/me');
    final raw = res.data;
    if (raw is Map) {
      return BalanceState(
        amount: ((raw['amount'] ?? raw['balance'] ?? 0) as num).toInt(),
        aiFreeRemaining: raw['aiFreeRemaining'] == null
            ? null
            : ((raw['aiFreeRemaining']) as num).toInt(),
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
    final r = await historyEnvelope(
        userId: userId,
        direction: direction,
        method: method,
        from: from,
        to: to,
        page: page,
        limit: limit);
    return r.data;
  }

  /// Full envelope variant — returns {data, balance, meta, stats}. Used by
  /// the customer transactions screen so the balance + income/expense
  /// totals can be rendered without a second round-trip. Mirrors web
  /// `fetchMyPaymentHistoryAPI`.
  Future<({
    List<PaymentEntry> data,
    int balance,
    int total,
    int totalPages,
    int totalIncome,
    int totalExpense,
  })> historyEnvelope({
    required String userId,
    String direction = 'all',
    String method = 'all',
    String? from,
    String? to,
    int page = 1,
    int limit = 20,
  }) async {
    // Backend endpoint is /balance/my-history (auth user resolved from JWT).
    // The old /users/:id/payment-history call hit a non-existent route and
    // returned 404 → empty list → customer transactions UI showed
    // "Hech narsa topilmadi" even when the user had real history.
    final res = await _dio.get('/balance/my-history', queryParameters: {
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
    final meta = data is Map && data['meta'] is Map
        ? (data['meta'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    final stats = data is Map && data['stats'] is Map
        ? (data['stats'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    final balance = data is Map ? data['balance'] : null;
    return (
      data: list
          .cast<Map<String, dynamic>>()
          .map(PaymentEntry.fromJson)
          .toList(),
      balance: ((balance ?? 0) as num).toInt(),
      total: ((meta['total'] ?? list.length) as num).toInt(),
      totalPages: ((meta['totalPages'] ?? 1) as num).toInt(),
      totalIncome: ((stats['totalIncome'] ?? 0) as num).toInt(),
      totalExpense: ((stats['totalExpense'] ?? 0) as num).toInt(),
    );
  }

  /// Returns the gateway URL the user should be redirected to.
  /// Backend (POST /click/initiate, POST /payme/initiate) takes the
  /// authenticated user from the JWT and returns
  /// `{payment_url, order_id}`. The old code read `url`/`redirectUrl`
  /// which never existed in the response → empty string → silent fail.
  Future<String> initiateTopUp({
    required String userId,
    required int amount,
    required String gateway, // 'click' | 'payme'
  }) async {
    final path = gateway == 'payme' ? '/payme/initiate' : '/click/initiate';
    final res = await _dio.post(path, data: {'amount': amount});
    final paymentUrl = (res.data is Map)
        ? (res.data['payment_url'] ?? res.data['paymentUrl'])
        : null;
    return paymentUrl?.toString() ?? '';
  }
}

final balanceRepositoryProvider =
    Provider<BalanceRepository>((ref) => BalanceRepository(ref.watch(dioProvider)));

final myBalanceProvider = FutureProvider.family<BalanceState, String>(
    (ref, userId) => ref.watch(balanceRepositoryProvider).myBalance(userId));

final paymentHistoryProvider = FutureProvider.family<List<PaymentEntry>, String>(
    (ref, userId) => ref.watch(balanceRepositoryProvider).history(userId: userId));

typedef PaymentHistoryKey = ({
  String userId,
  String direction,
  String method,
  String? from,
  String? to,
  int page,
});

final paymentHistoryFilteredProvider = FutureProvider.family<
    ({
      List<PaymentEntry> data,
      int balance,
      int total,
      int totalPages,
      int totalIncome,
      int totalExpense,
    }),
    PaymentHistoryKey>((ref, k) async {
  return ref.watch(balanceRepositoryProvider).historyEnvelope(
      userId: k.userId,
      direction: k.direction,
      method: k.method,
      from: k.from,
      to: k.to,
      page: k.page);
});
