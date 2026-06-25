import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';

/// Public barbershop marker returned by `GET /barbershops` — the same shape
/// web's `listPublicBarbershopsAPI` consumes for its customer-facing map and
/// the merged "barbers + shops" grid.
class PublicBarbershop {
  PublicBarbershop({
    required this.id,
    required this.name,
    required this.address,
    required this.barberCount,
    this.phone,
    this.lat,
    this.lng,
    this.geoAddress,
  });

  final String id;
  final String name;
  final String address;
  final String? phone;
  final int barberCount;
  final double? lat;
  final double? lng;
  final String? geoAddress;

  factory PublicBarbershop.fromJson(Map<String, dynamic> json) {
    final count = json['_count'] is Map
        ? (((json['_count'] as Map)['barbers'] ?? 0) as num).toInt()
        : ((json['barberCount'] ?? 0) as num).toInt();
    return PublicBarbershop(
      id: json['id']?.toString() ?? '',
      name: (json['name'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      phone: json['phone']?.toString(),
      barberCount: count,
      lat: (json['latitude'] as num?)?.toDouble(),
      lng: (json['longitude'] as num?)?.toDouble(),
      geoAddress: json['geoAddress']?.toString(),
    );
  }
}

class PublicBarbershopRepository {
  PublicBarbershopRepository(this._dio);
  final Dio _dio;

  Future<List<PublicBarbershop>> list() async {
    try {
      final res = await _dio.get('/barbershops');
      final data = res.data;
      final raw = (data is List)
          ? data
          : (data is Map && data['data'] is List ? data['data'] as List : <dynamic>[]);
      return raw
          .cast<Map<String, dynamic>>()
          .map(PublicBarbershop.fromJson)
          .toList();
    } catch (_) {
      // Soft-fail — the merged grid still renders barbers if the shop
      // listing 5xx's or the user is offline.
      return const [];
    }
  }
}

final publicBarbershopRepositoryProvider = Provider<PublicBarbershopRepository>(
    (ref) => PublicBarbershopRepository(ref.watch(dioProvider)));

final publicBarbershopsProvider = FutureProvider<List<PublicBarbershop>>(
    (ref) => ref.watch(publicBarbershopRepositoryProvider).list());
