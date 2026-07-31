import 'dart:developer' as developer;
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';

class AiStyleResult {
  AiStyleResult({required this.imageUrl, this.balanceAfter, this.aiFreeRemaining});
  final String imageUrl;
  final int? balanceAfter;
  final int? aiFreeRemaining;

  factory AiStyleResult.fromJson(Map<String, dynamic> json) {
    // Backend ai-style.service returns {images: [...], generatedImage}
    // (ai-style.service.ts:113). The old key probes (url/imageUrl/image)
    // never matched and the result image area always rendered blank.
    String image = '';
    final list = json['images'];
    if (list is List && list.isNotEmpty) {
      image = list.first.toString();
    } else if (json['generatedImage'] is String) {
      image = (json['generatedImage'] as String);
    } else if (json['url'] is String) {
      image = json['url'] as String;
    } else if (json['imageUrl'] is String) {
      image = json['imageUrl'] as String;
    } else if (json['image'] is String) {
      image = json['image'] as String;
    }
    return AiStyleResult(
      imageUrl: image,
      balanceAfter: json['balanceAfter'] == null
          ? null
          : ((json['balanceAfter']) as num).toInt(),
      aiFreeRemaining: json['aiFreeRemaining'] == null
          ? null
          : ((json['aiFreeRemaining']) as num).toInt(),
    );
  }
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
    final startedAt = DateTime.now();
    developer.log(
      'AI START photoBytes=${await selfie.length()} '
      'styles=${styles.join(",")} refs=${references.keys.join(",")}',
      name: 'ai-style',
    );
    late final Response<dynamic> res;
    try {
      res = await _dio.post('/ai-style/generate', data: form, options: Options(
        sendTimeout: const Duration(minutes: 2),
        receiveTimeout: const Duration(minutes: 2),
      ));
    } on DioException catch (e) {
      developer.log(
        'AI DIO ERROR status=${e.response?.statusCode} type=${e.type.name} '
        'msg=${e.message} took=${DateTime.now().difference(startedAt).inMilliseconds}ms',
        name: 'ai-style',
        error: e,
      );
      rethrow;
    }
    final raw = res.data;
    developer.log(
      'AI HTTP OK status=${res.statusCode} '
      'took=${DateTime.now().difference(startedAt).inMilliseconds}ms '
      'contentType=${res.headers.value('content-type')} '
      'bodyType=${raw.runtimeType} '
      'bodyPreview=${raw is Map ? raw.keys.take(6).join(",") : raw.toString().substring(0, raw.toString().length > 80 ? 80 : raw.toString().length)}',
      name: 'ai-style',
    );
    final result = raw is Map
        ? AiStyleResult.fromJson(Map<String, dynamic>.from(raw))
        : AiStyleResult(imageUrl: raw?.toString() ?? '');
    // Guard against a "success" response that carries an empty or
    // truncated data URL — the mobile customer previously saw a red
    // broken-image tile while the 1000 so'm deduction still stuck.
    // Throwing here surfaces the standard 'generatsiya bajarilmadi'
    // toast and, importantly, tells the customer the render actually
    // failed so they don't quietly move on thinking they lost the money.
    // Backend has a matching size guard that refunds when this fires
    // there, so this is belt-and-suspenders.
    final url = result.imageUrl;
    final isDataUrl = url.startsWith('data:');
    final urlKb = (url.length / 1024).round();
    if (url.isEmpty ||
        (isDataUrl && url.length < _minDataUrlChars) ||
        (!isDataUrl && url.startsWith('http') == false && !url.startsWith('/'))) {
      developer.log(
        'AI REJECT reason=${url.isEmpty ? "empty" : isDataUrl ? "short-data-url" : "invalid-scheme"} '
        'urlLen=${url.length} isDataUrl=$isDataUrl urlPreview=${url.length > 60 ? "${url.substring(0, 60)}..." : url}',
        name: 'ai-style',
      );
      throw Exception('empty-or-invalid-image');
    }
    developer.log(
      'AI ACCEPT scheme=${isDataUrl ? "data" : "http"} sizeKB=$urlKb '
      'balanceAfter=${result.balanceAfter} freeRemaining=${result.aiFreeRemaining}',
      name: 'ai-style',
    );
    return result;
  }

  // ~5KB base64 + the 22-char 'data:image/png;base64,' prefix. Anything
  // shorter than this is guaranteed truncated Gemini output.
  static const int _minDataUrlChars = 5000;

  /// Fetches an external asset (curated preset thumbnail) and writes
  /// it to [saveTo] as raw bytes. Used by the AI Style screen to turn
  /// a HairstylePreset.imageUrl into a File that can be POSTed as a
  /// reference. Uses a fresh Dio instance so the request bypasses the
  /// authenticated `_dio` (external URL — no JWT needed).
  Future<void> downloadAsset({required String url, required File saveTo}) async {
    final client = Dio();
    final res = await client.get<List<int>>(url,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 15),
        ));
    final bytes = res.data;
    if (bytes == null || bytes.isEmpty) return;
    await saveTo.writeAsBytes(bytes, flush: true);
  }
}

final aiStyleRepositoryProvider =
    Provider<AiStyleRepository>((ref) => AiStyleRepository(ref.watch(dioProvider)));
