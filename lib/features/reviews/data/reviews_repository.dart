import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';

class Review {
  Review({required this.id, required this.rating, required this.comment, required this.userName, required this.createdAt});
  final String id;
  final int rating;
  final String comment;
  final String userName;
  final DateTime createdAt;

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        id: json['id']?.toString() ?? '',
        rating: ((json['rating'] ?? 0) as num).toInt(),
        comment: (json['comment'] ?? json['text'] ?? '').toString(),
        userName: (json['userName'] ?? json['user']?['name'] ?? '').toString(),
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
}

class ReviewsRepository {
  ReviewsRepository(this._dio);
  final Dio _dio;

  Future<List<Review>> forBarber(String barberId) async {
    // Backend: GET /reviews/barber/:barberId (reviews.controller.ts:9).
    // The old /barbers/:id/reviews path had no handler — barber detail
    // page always loaded "no reviews".
    final res = await _dio.get('/reviews/barber/$barberId');
    final data = res.data;
    final list = (data is List)
        ? data
        : (data is Map && data['data'] is List ? data['data'] as List : <dynamic>[]);
    return list.cast<Map<String, dynamic>>().map(Review.fromJson).toList();
  }

  Future<void> submit({required String barberId, required int rating, required String comment, String? bookingId}) async {
    // Backend: POST /reviews (reviews.controller.ts:15) — barberId goes in body.
    await _dio.post('/reviews', data: {
      'barberId': barberId,
      'rating': rating,
      'comment': comment,
      // ignore: use_null_aware_elements
      if (bookingId != null) 'bookingId': bookingId,
    });
  }
}

final reviewsRepositoryProvider = Provider<ReviewsRepository>(
    (ref) => ReviewsRepository(ref.watch(dioProvider)));

final barberReviewsProvider = FutureProvider.family<List<Review>, String>(
    (ref, barberId) => ref.watch(reviewsRepositoryProvider).forBarber(barberId));
