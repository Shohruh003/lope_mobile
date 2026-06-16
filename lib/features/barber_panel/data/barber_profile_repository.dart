import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';

/// Barber-self profile editing: bio, services CRUD, working hours, gallery,
/// avatar, public-link, reminder settings. Backed by NestJS endpoints:
///   GET    /barbers/:id
///   PATCH  /barbers/:id
///   POST   /barbers/:id/gallery       (FormData, multipart)
///   DELETE /barbers/:id/gallery       body: { url }
///   POST   /users/:id/avatar          (FormData, multipart)
///   GET    /barbers/:id/services
///   POST   /barbers/:id/services
///   PATCH  /barbers/:id/services/:sid
///   DELETE /barbers/:id/services/:sid
class BarberProfileRepository {
  BarberProfileRepository(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> getBarber(String id) async {
    final res = await _dio.get('/barbers/$id');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> updateBarber(String id, Map<String, dynamic> patch) async {
    final res = await _dio.patch('/barbers/$id', data: patch);
    return Map<String, dynamic>.from(res.data as Map);
  }

  // Services
  Future<List<Map<String, dynamic>>> services(String barberId) async {
    final res = await _dio.get('/barbers/$barberId/services');
    final raw = res.data;
    final list = (raw is List) ? raw : (raw is Map && raw['data'] is List ? raw['data'] as List : <dynamic>[]);
    return list.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createService(String barberId, Map<String, dynamic> body) async {
    final res = await _dio.post('/barbers/$barberId/services', data: body);
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> updateService(String barberId, String serviceId, Map<String, dynamic> body) async {
    await _dio.patch('/barbers/$barberId/services/$serviceId', data: body);
  }

  Future<void> deleteService(String barberId, String serviceId) async {
    await _dio.delete('/barbers/$barberId/services/$serviceId');
  }

  // Gallery
  Future<List<String>> uploadGallery(String barberId, List<File> files) async {
    final form = FormData();
    for (final f in files) {
      form.files.add(MapEntry(
        'files',
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

  Future<void> deleteGalleryImage(String barberId, String url) async {
    await _dio.delete('/barbers/$barberId/gallery', data: {'url': url});
  }

  // Avatar
  Future<String> uploadAvatar(String userId, File file) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path,
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
