import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';

/// Barber-self profile editing: bio, services CRUD, working hours, gallery,
/// avatar, public-link, reminder settings.
///
/// Backend has NO `/barbers/:id/services` CRUD nor `DELETE /barbers/:id/gallery`
/// — services and the gallery list are PATCHed in place via
/// `PATCH /barbers/:id/profile` with the full updated array. We mirror the web
/// flow: read full barber, mutate the array, PATCH it back.
///
/// Endpoints actually used:
///   GET    /barbers/:id
///   PATCH  /barbers/:id/profile        (services, gallery, bio, location, etc.)
///   POST   /barbers/:id/gallery        (FormData, field name 'images')
///   POST   /users/:id/avatar           (FormData, field name 'avatar')
class BarberProfileRepository {
  BarberProfileRepository(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> getBarber(String id) async {
    final res = await _dio.get('/barbers/$id');
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// PATCH /barbers/:id/profile — the only generic update route on the
  /// backend. Old code used /barbers/:id which returned 404, so every
  /// barber profile edit silently failed.
  Future<Map<String, dynamic>> updateBarber(String id, Map<String, dynamic> patch) async {
    final res = await _dio.patch('/barbers/$id/profile', data: patch);
    return Map<String, dynamic>.from(res.data as Map);
  }

  // Services — derived from /barbers/:id; CRUD goes through PATCH profile.
  Future<List<Map<String, dynamic>>> services(String barberId) async {
    final barber = await getBarber(barberId);
    final raw = barber['services'];
    final list = (raw is List) ? raw : <dynamic>[];
    return list.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createService(String barberId, Map<String, dynamic> body) async {
    final current = await services(barberId);
    final newSvc = {...body};
    // Server generates ids on its side, but the web seeds one client-side too.
    newSvc['id'] = newSvc['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
    final next = [...current, newSvc];
    await updateBarber(barberId, {'services': next});
    return newSvc;
  }

  Future<void> updateService(String barberId, String serviceId, Map<String, dynamic> body) async {
    final current = await services(barberId);
    final next = current
        .map((s) => s['id'] == serviceId ? {...s, ...body} : s)
        .toList();
    await updateBarber(barberId, {'services': next});
  }

  Future<void> deleteService(String barberId, String serviceId) async {
    final current = await services(barberId);
    final next = current.where((s) => s['id'] != serviceId).toList();
    await updateBarber(barberId, {'services': next});
  }

  // Gallery
  Future<List<String>> uploadGallery(String barberId, List<File> files) async {
    // Backend field name is 'images' (barbers.controller.ts:147), not 'files'.
    // The old field name made every gallery upload fail with 400.
    final form = FormData();
    for (final f in files) {
      form.files.add(MapEntry(
        'images',
        await MultipartFile.fromFile(f.path, filename: f.path.split(Platform.pathSeparator).last),
      ));
    }
    final res = await _dio.post('/barbers/$barberId/gallery', data: form);
    final data = res.data;
    if (data is Map && data['gallery'] is List) {
      return (data['gallery'] as List).map((e) => e.toString()).toList();
    }
    if (data is List) return data.map((e) => e.toString()).toList();
    return [];
  }

  /// No DELETE /barbers/:id/gallery handler exists — we PATCH profile with
  /// the gallery array minus the deleted URL.
  Future<void> deleteGalleryImage(String barberId, String url) async {
    final barber = await getBarber(barberId);
    final raw = barber['gallery'];
    final current = (raw is List) ? raw.map((e) => e.toString()).toList() : <String>[];
    final next = current.where((u) => u != url).toList();
    await updateBarber(barberId, {'gallery': next});
  }

  // Avatar
  Future<String> uploadAvatar(String userId, File file) async {
    // Backend field name is 'avatar' (users.controller.ts:79), not 'file'.
    // The old field name made every avatar upload fail with 400.
    final form = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(file.path,
          filename: file.path.split(Platform.pathSeparator).last),
    });
    final res = await _dio.post('/users/$userId/avatar', data: form);
    if (res.data is Map && (res.data as Map)['avatar'] != null) {
      return (res.data as Map)['avatar'].toString();
    }
    return '';
  }
}

final barberProfileRepositoryProvider = Provider<BarberProfileRepository>((ref) {
  return BarberProfileRepository(ref.watch(dioProvider));
});

final barberProfileProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  return ref.watch(barberProfileRepositoryProvider).getBarber(id);
});

final barberServicesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, barberId) async {
  return ref.watch(barberProfileRepositoryProvider).services(barberId);
});
