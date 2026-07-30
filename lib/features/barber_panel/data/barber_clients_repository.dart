import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';

class BarberClient {
  BarberClient({
    required this.name,
    required this.phone,
    required this.bookingsCount,
    this.avatar,
    this.lastVisit,
    this.totalSpent = 0,
  });
  final String name;
  final String phone;
  final int bookingsCount;

  /// Client's uploaded profile photo (relative asset path). Null for
  /// guest bookings or when the linked user hasn't set an avatar.
  /// Backend returns this as `userAvatar` in the enriched response.
  final String? avatar;
  final DateTime? lastVisit;
  final int totalSpent;

  factory BarberClient.fromJson(Map<String, dynamic> json) => BarberClient(
        name: (json['name'] ?? json['guestName'] ?? '').toString(),
        phone: (json['phone'] ?? json['guestPhone'] ?? '').toString(),
        avatar: (json['avatar'] ?? json['userAvatar']) as String?,
        // Backend exposes `totalVisits` (bookings.service.ts:194); kept
        // bookingsCount/count fallbacks so older cached responses don't
        // suddenly read as 0.
        bookingsCount: ((json['totalVisits'] ?? json['bookingsCount'] ?? json['count'] ?? 0) as num).toInt(),
        lastVisit: json['lastVisit'] != null && (json['lastVisit'] as String).isNotEmpty
            ? DateTime.tryParse(json['lastVisit'].toString())
            : null,
        // Backend doesn't currently return totalSpent — keep the read
        // for forward compat but it will be 0 in production today.
        totalSpent: ((json['totalSpent'] ?? 0) as num).toInt(),
      );

  /// Merge two records for the same phone number — used to collapse
  /// duplicate entries the backend returns when a guest booking's
  /// phone was later linked to a registered user account, so both a
  /// `Shohruh Azimov` (user row) and `Shohruh` (guest row) can share
  /// the same +998... number. Takes the newer `lastVisit`, sums the
  /// booking counts and totals, prefers the user-side name / avatar.
  BarberClient mergeWith(BarberClient other) {
    // Prefer the entry with the more recent lastVisit for its
    // display name; a client's most recent booking usually has their
    // canonical name.
    final aNewer = (lastVisit == null && other.lastVisit == null)
        ? true
        : lastVisit != null &&
            (other.lastVisit == null ||
                lastVisit!.isAfter(other.lastVisit!));
    final winner = aNewer ? this : other;
    final loser = aNewer ? other : this;
    return BarberClient(
      // Prefer a non-empty avatar; then the newer record's name.
      name: winner.name.isNotEmpty ? winner.name : loser.name,
      phone: phone,
      avatar: (winner.avatar?.isNotEmpty ?? false)
          ? winner.avatar
          : loser.avatar,
      bookingsCount: bookingsCount + other.bookingsCount,
      lastVisit: winner.lastVisit ?? loser.lastVisit,
      totalSpent: totalSpent + other.totalSpent,
    );
  }
}

/// Deduplicate a raw list from the backend by phone number. Entries
/// without a phone (walk-in guests with no contact info) are kept
/// separate — we have no way to know if they're the same person.
List<BarberClient> mergeBarberClients(List<BarberClient> raw) {
  final byPhone = <String, BarberClient>{};
  final noPhone = <BarberClient>[];
  for (final c in raw) {
    if (c.phone.isEmpty) {
      noPhone.add(c);
      continue;
    }
    final key = c.phone.replaceAll(RegExp(r'\D'), '');
    final existing = byPhone[key];
    byPhone[key] = existing == null ? c : existing.mergeWith(c);
  }
  final merged = [...byPhone.values, ...noPhone];
  merged.sort((a, b) {
    // Most-recent visit first — a barber usually wants to see who
    // came in most recently at the top of the list.
    if (a.lastVisit == null && b.lastVisit == null) return 0;
    if (a.lastVisit == null) return 1;
    if (b.lastVisit == null) return -1;
    return b.lastVisit!.compareTo(a.lastVisit!);
  });
  return merged;
}

class BarberClientsRepository {
  BarberClientsRepository(this._dio);
  final Dio _dio;

  /// Single page of the barber's client list. Backend endpoint:
  /// GET /bookings/barber/:barberId/clients?page=N&limit=M
  /// (bookings.controller.ts:167). Server-side default is limit=20,
  /// max=100 — callers picking a large limit still get capped there.
  Future<List<BarberClient>> minePage(
    String barberId, {
    int page = 1,
    int limit = 100,
  }) async {
    final res = await _dio.get(
      '/bookings/barber/$barberId/clients',
      queryParameters: {'page': page, 'limit': limit},
    );
    final data = res.data;
    final list = (data is List)
        ? data
        : (data is Map && data['data'] is List
            ? data['data'] as List
            : <dynamic>[]);
    return list
        .cast<Map<String, dynamic>>()
        .map(BarberClient.fromJson)
        .toList();
  }

  /// Fetches EVERY client across all pages. Same shape as the shop
  /// panel's clientsAll — barber with 100+ clients used to only see
  /// the first 20 because /bookings/barber/:id/clients pages by
  /// default and the old mine() sent no ?page/?limit. Loops 100-row
  /// chunks and stops when a short chunk arrives, with a 50-page
  /// safety cap so a runaway backend can't spin forever.
  Future<List<BarberClient>> mine(String barberId) async {
    const pageSize = 100;
    final out = <BarberClient>[];
    var page = 1;
    while (true) {
      final chunk = await minePage(barberId, page: page, limit: pageSize);
      out.addAll(chunk);
      if (chunk.length < pageSize) break;
      page += 1;
      if (page > 50) break;
    }
    // Dedupe by phone before returning — the backend has been known
    // to return both the guest-side and user-side entries for the
    // same phone once a registered user's account was linked to a
    // previously-manual booking.
    return mergeBarberClients(out);
  }
}

final barberClientsRepositoryProvider = Provider<BarberClientsRepository>(
    (ref) => BarberClientsRepository(ref.watch(dioProvider)));

final barberClientsProvider = FutureProvider.family<List<BarberClient>, String>(
    (ref, barberId) => ref.watch(barberClientsRepositoryProvider).mine(barberId));
