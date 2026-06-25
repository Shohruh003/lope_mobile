import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../auth/presentation/auth_controller.dart';

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

  /// Backend exposes TWO separate endpoints:
  ///   * `/user-notifications` — for customers
  ///   * `/notifications/barber/:barberId` — for barbers
  ///   * (no separate inbox for barbershop / shop yet — they reuse
  ///      whichever role the underlying user holds)
  /// The old code probed `/notifications/me` then `/notifications/:role/me`
  /// — neither route exists, so the inbox always rendered empty.
  Future<List<AppNotification>> mine(String role, String userId) async {
    if (role == 'barber') {
      final res = await _dio.get('/notifications/barber/$userId');
      return _parse(res.data);
    }
    // Default: customer endpoint. barbershop / shop also use this since
    // backend routes them via the User model not the Barber model.
    final res = await _dio.get('/user-notifications');
    return _parse(res.data);
  }

  List<AppNotification> _parse(dynamic data) {
    final list = (data is List)
        ? data
        : (data is Map && data['data'] is List ? data['data'] as List : <dynamic>[]);
    return list.cast<Map<String, dynamic>>().map(AppNotification.fromJson).toList();
  }

  Future<void> markRead(String id, {required String role}) async {
    final base = role == 'barber' ? '/notifications' : '/user-notifications';
    await _dio.patch('$base/$id/read');
  }

  Future<void> markAllRead({required String role, required String userId}) async {
    if (role == 'barber') {
      await _dio.patch('/notifications/barber/$userId/read-all');
    } else {
      await _dio.patch('/user-notifications/read-all');
    }
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
    (ref) => NotificationsRepository(ref.watch(dioProvider)));

/// Family keyed on role — listens to the current user so the right
/// endpoint gets hit. The id comes from the auth controller.
final notificationsProvider = FutureProvider.family<List<AppNotification>, String>(
    (ref, role) async {
  final user = ref.watch(authControllerProvider).user;
  final id = user?.id ?? '';
  return ref.watch(notificationsRepositoryProvider).mine(role, id);
});
