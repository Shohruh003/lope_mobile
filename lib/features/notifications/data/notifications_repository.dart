import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';

class AppNotification {
  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
    this.type,
  });
  final String id;
  final String title;
  final String body;
  final bool read;
  final String? type;
  final DateTime createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id']?.toString() ?? '',
        title: (json['title'] ?? '').toString(),
        body: (json['body'] ?? json['message'] ?? '').toString(),
        read: json['read'] == true || json['isRead'] == true,
        type: json['type']?.toString(),
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
}

class NotificationsRepository {
  NotificationsRepository(this._dio);
  final Dio _dio;

  /// Backend supports either `/notifications/me` (role-agnostic) or
  /// `/notifications/:role/me`. We probe the simpler one first; on 404 fall
  /// back to the role-scoped variant.
  Future<List<AppNotification>> mine(String role) async {
    try {
      final res = await _dio.get('/notifications/me');
      return _parse(res.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        final res = await _dio.get('/notifications/$role/me');
        return _parse(res.data);
      }
      rethrow;
    }
  }

  List<AppNotification> _parse(dynamic data) {
    final list = (data is List)
        ? data
        : (data is Map && data['data'] is List ? data['data'] as List : <dynamic>[]);
    return list.cast<Map<String, dynamic>>().map(AppNotification.fromJson).toList();
  }

  Future<void> markRead(String id) async {
    await _dio.patch('/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    try {
      await _dio.patch('/notifications/read-all');
    } on DioException catch (e) {
      // Fall back to POST if backend exposes /read-all as POST.
      if (e.response?.statusCode == 404 || e.response?.statusCode == 405) {
        await _dio.post('/notifications/read-all');
      } else {
        rethrow;
      }
    }
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
    (ref) => NotificationsRepository(ref.watch(dioProvider)));

final notificationsProvider = FutureProvider.family<List<AppNotification>, String>(
    (ref, role) async => ref.watch(notificationsRepositoryProvider).mine(role));
