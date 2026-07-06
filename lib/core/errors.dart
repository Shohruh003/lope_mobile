import 'package:dio/dio.dart';

/// User-facing exception with an Uzbek message that's safe to render in UI.
/// Callers should NEVER show DioException / e.toString() to the user again —
/// always route through [AppException.from] first.
class AppException implements Exception {
  const AppException(this.message, {this.kind = AppErrorKind.unknown, this.statusCode});

  final String message;
  final AppErrorKind kind;
  final int? statusCode;

  static AppException from(Object e) {
    if (e is AppException) return e;
    if (e is DioException) return _fromDio(e);
    // Anything else — hide the raw text, use a generic Uzbek message.
    return const AppException(
      "Kutilmagan xatolik. Iltimos, qayta urinib ko'ring.",
    );
  }

  @override
  String toString() => message;
}

enum AppErrorKind { network, timeout, unauthorized, forbidden, notFound, server, validation, unknown }

AppException _fromDio(DioException e) {
  final status = e.response?.statusCode;

  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return const AppException(
        "Server javob bermayapti. Internetni tekshiring va qayta urinib ko'ring.",
        kind: AppErrorKind.timeout,
      );
    case DioExceptionType.connectionError:
    case DioExceptionType.unknown:
      if (e.error?.toString().toLowerCase().contains('socket') ?? false) {
        return const AppException(
          "Internet aloqasi yo'q. Ulanishni tekshiring.",
          kind: AppErrorKind.network,
        );
      }
      break;
    case DioExceptionType.cancel:
      return const AppException("So'rov bekor qilindi.", kind: AppErrorKind.unknown);
    case DioExceptionType.badCertificate:
      return const AppException(
        "Xavfsizlik sertifikati muammosi. Iltimos, keyinroq urinib ko'ring.",
        kind: AppErrorKind.network,
      );
    case DioExceptionType.badResponse:
      break;
  }

  // Serverdan kelgan aniq xabarni ustuvor qilamiz (agar bor bo'lsa).
  final serverMsg = _extractServerMessage(e.response?.data);

  switch (status) {
    case 401:
      return AppException(
        serverMsg ?? "Sessiya tugagan. Iltimos, qaytadan kiring.",
        kind: AppErrorKind.unauthorized,
        statusCode: 401,
      );
    case 403:
      return AppException(
        serverMsg ?? "Bu amalni bajarish uchun ruxsat yo'q.",
        kind: AppErrorKind.forbidden,
        statusCode: 403,
      );
    case 404:
      return AppException(
        serverMsg ?? "Ma'lumot topilmadi.",
        kind: AppErrorKind.notFound,
        statusCode: 404,
      );
    case 400:
    case 409:
    case 422:
      return AppException(
        serverMsg ?? "So'rov noto'g'ri. Ma'lumotlarni tekshiring.",
        kind: AppErrorKind.validation,
        statusCode: status,
      );
    case 429:
      return const AppException(
        "Juda ko'p urinish. Bir oz kuting va qayta urinib ko'ring.",
        kind: AppErrorKind.validation,
      );
  }

  if (status != null && status >= 500) {
    return AppException(
      serverMsg ?? "Serverda vaqtincha xatolik. Iltimos, keyinroq urinib ko'ring.",
      kind: AppErrorKind.server,
      statusCode: status,
    );
  }

  return AppException(
    serverMsg ?? "Kutilmagan xatolik. Iltimos, qayta urinib ko'ring.",
    kind: AppErrorKind.unknown,
    statusCode: status,
  );
}

String? _extractServerMessage(dynamic data) {
  if (data is Map) {
    // NestJS default: { message: string | string[], statusCode: number }
    final m = data['message'];
    if (m is String && m.isNotEmpty && !m.startsWith('DioException')) return m;
    if (m is List && m.isNotEmpty && m.first is String) return m.first as String;
    final err = data['error'];
    if (err is String && err.isNotEmpty && err != 'Bad Request') return err;
  }
  if (data is String && data.isNotEmpty && !data.contains('DioException')) {
    return data;
  }
  return null;
}

/// Convenience — swap any raw error to a user-friendly Uzbek string.
/// Use in catch blocks: `catch (e) { setState(() => _error = humanize(e)); }`.
String humanize(Object e) => AppException.from(e).message;
