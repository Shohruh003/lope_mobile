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

  /// POST /ai-style/generate — backend uses FileFieldsInterceptor and expects:
  ///   - field `photo`  (the selfie, single file)
  ///   - field `ref_<key>` per reference (one file per style key)
  ///   - field `styles` repeated for each selected style key
  /// Old code used `selfie`/`references` field names + no styles, so the
  /// backend always 400'd with "No photo uploaded" or dropped references.
  Future<AiStyleResult> generate({
    required File selfie,
    required String gender,
    required List<String> styles,
    required Map<String, File> references,
    Map<String, String> extra = const {},
  }) async {
    final form = FormData();
    form.files.add(MapEntry(
      'photo',
      await MultipartFile.fromFile(selfie.path,
          filename: selfie.path.split(Platform.pathSeparator).last),
    ));
    for (final entry in references.entries) {
      form.files.add(MapEntry(
        'ref_${entry.key}',
        await MultipartFile.fromFile(entry.value.path,
            filename: entry.value.path.split(Platform.pathSeparator).last),
      ));
    }
    // Multi-style "styles" field — NestJS reads repeated form keys as an array.
    for (final s in styles) {
      form.fields.add(MapEntry('styles', s));
    }
    // Gender is informational — backend doesn't use it directly but keeps
    // parity with web's payload.
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
