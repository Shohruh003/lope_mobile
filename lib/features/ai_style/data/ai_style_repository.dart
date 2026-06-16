import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';

class AiStyleResult {
  AiStyleResult({required this.imageUrl, this.balanceAfter, this.aiFreeRemaining});
  final String imageUrl;
  final int? balanceAfter;
  final int? aiFreeRemaining;

  factory AiStyleResult.fromJson(Map<String, dynamic> json) => AiStyleResult(
        imageUrl: (json['url'] ?? json['imageUrl'] ?? json['image'] ?? '').toString(),
        balanceAfter: json['balanceAfter'] == null ? null : ((json['balanceAfter']) as num).toInt(),
        aiFreeRemaining:
            json['aiFreeRemaining'] == null ? null : ((json['aiFreeRemaining']) as num).toInt(),
      );
}

class AiStyleRepository {
  AiStyleRepository(this._dio);
  final Dio _dio;

  Future<AiStyleResult> generate({
    required File selfie,
    required String gender, // 'male' | 'female'
    required List<File> references,
    Map<String, String> extra = const {},
  }) async {
    final form = FormData();
    form.files.add(MapEntry(
      'selfie',
      await MultipartFile.fromFile(selfie.path, filename: selfie.path.split(Platform.pathSeparator).last),
    ));
    for (final ref in references) {
      form.files.add(MapEntry(
        'references',
        await MultipartFile.fromFile(ref.path, filename: ref.path.split(Platform.pathSeparator).last),
      ));
    }
    form.fields.add(MapEntry('gender', gender));
    extra.forEach((k, v) => form.fields.add(MapEntry(k, v)));
    final res = await _dio.post('/ai-style/generate', data: form, options: Options(
      sendTimeout: const Duration(minutes: 2),
      receiveTimeout: const Duration(minutes: 2),
    ));
    final raw = res.data;
    if (raw is Map) return AiStyleResult.fromJson(Map<String, dynamic>.from(raw));
    return AiStyleResult(imageUrl: raw?.toString() ?? '');
  }
}

final aiStyleRepositoryProvider =
    Provider<AiStyleRepository>((ref) => AiStyleRepository(ref.watch(dioProvider)));
