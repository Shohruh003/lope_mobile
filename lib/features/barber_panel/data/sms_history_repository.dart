import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';

class SmsLogEntry {
  SmsLogEntry({
    required this.id,
    required this.phone,
    required this.message,
    required this.status,
    required this.createdAt,
    this.type,
  });
  final String id;
  final String phone;
  final String message;
  final String status;
  final String? type;
  final DateTime createdAt;

  factory SmsLogEntry.fromJson(Map<String, dynamic> json) => SmsLogEntry(
        id: json['id']?.toString() ?? '',
        phone: (json['phone'] ?? '').toString(),
        message: (json['message'] ?? '').toString(),
        status: (json['status'] ?? 'unknown').toString(),
        type: json['type']?.toString(),
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
}

class SmsHistoryRepository {
  SmsHistoryRepository(this._dio);
  final Dio _dio;

  Future<List<SmsLogEntry>> fetch({
    required String barberId,
    int page = 1,
    int limit = 20,
    String? type,
    String? from,
    String? to,
  }) async {
    final res = await _dio.get('/barbers/$barberId/sms-log', queryParameters: {
      'page': page,
      'limit': limit,
      if (type != null && type.isNotEmpty && type != 'all') 'type': type,
      // ignore: use_null_aware_elements
      if (from != null) 'from': from,
      // ignore: use_null_aware_elements
      if (to != null) 'to': to,
    });
    final data = res.data;
    final list = (data is List)
        ? data
        : (data is Map && data['data'] is List ? data['data'] as List : <dynamic>[]);
    return list.cast<Map<String, dynamic>>().map(SmsLogEntry.fromJson).toList();
  }
}

final smsHistoryRepositoryProvider = Provider<SmsHistoryRepository>(
    (ref) => SmsHistoryRepository(ref.watch(dioProvider)));

final smsHistoryProvider = FutureProvider.family<List<SmsLogEntry>, String>(
    (ref, barberId) async => ref.watch(smsHistoryRepositoryProvider).fetch(barberId: barberId));
