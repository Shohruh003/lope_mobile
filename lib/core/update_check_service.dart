import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'api_client.dart';

/// Server-side mobile config: latest + minimum versions per platform,
/// plus the App Store / Play Market URL the "Update" button opens.
class MobileConfig {
  const MobileConfig({
    required this.latestVersion,
    required this.minVersion,
    required this.storeUrl,
  });

  final String latestVersion;
  final String minVersion;
  final String storeUrl;
}

/// Update decision — what modal (if any) the app should render at startup.
enum UpdateStatus {
  upToDate,   // current >= latestVersion → no modal
  softUpdate, // latestVersion > current >= minVersion → dismissible modal
  hardUpdate, // current < minVersion → non-dismissible modal
}

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.status,
    required this.currentVersion,
    required this.config,
  });

  final UpdateStatus status;
  final String currentVersion;
  final MobileConfig? config;
}

/// Fetches /config/mobile once at app startup and compares the server's
/// latest+min version against pubspec's build. Callers watch this and
/// show the update modal when needed.
///
/// Returns [UpdateStatus.upToDate] on any failure (network down, backend
/// missing endpoint) so a broken config never blocks the app.
final updateCheckProvider = FutureProvider<UpdateCheckResult>((ref) async {
  // Web has no store — skip entirely and never show the modal on
  // Flutter Web builds.
  if (kIsWeb) {
    return const UpdateCheckResult(
      status: UpdateStatus.upToDate,
      currentVersion: '',
      config: null,
    );
  }

  try {
    final info = await PackageInfo.fromPlatform();
    final currentVersion = info.version;

    final dio = ref.read(dioProvider);
    final res = await dio.get(
      '/config/mobile',
      options: Options(
        // Startup call — don't let a slow config hold the UI back.
        receiveTimeout: const Duration(seconds: 5),
        sendTimeout: const Duration(seconds: 5),
      ),
    );
    final data = res.data as Map<String, dynamic>;

    final isIos = !kIsWeb && Platform.isIOS;
    final config = MobileConfig(
      latestVersion: (isIos
              ? data['iosLatestVersion']
              : data['androidLatestVersion'])
          ?.toString() ??
          '',
      minVersion: (isIos ? data['iosMinVersion'] : data['androidMinVersion'])
              ?.toString() ??
          '',
      storeUrl: (isIos ? data['iosStoreUrl'] : data['androidStoreUrl'])
              ?.toString() ??
          '',
    );

    // Empty latestVersion means admin hasn't configured this platform
    // yet — skip the modal, don't accidentally force everyone to
    // "update" to nothing.
    if (config.latestVersion.isEmpty || config.storeUrl.isEmpty) {
      return UpdateCheckResult(
        status: UpdateStatus.upToDate,
        currentVersion: currentVersion,
        config: config,
      );
    }

    final cmpLatest = compareVersions(currentVersion, config.latestVersion);
    final cmpMin = compareVersions(currentVersion, config.minVersion);

    UpdateStatus status;
    if (cmpMin < 0) {
      status = UpdateStatus.hardUpdate;
    } else if (cmpLatest < 0) {
      status = UpdateStatus.softUpdate;
    } else {
      status = UpdateStatus.upToDate;
    }

    return UpdateCheckResult(
      status: status,
      currentVersion: currentVersion,
      config: config,
    );
  } catch (_) {
    return const UpdateCheckResult(
      status: UpdateStatus.upToDate,
      currentVersion: '',
      config: null,
    );
  }
});

/// Semantic version comparison — returns -1/0/1 the same way as strcmp,
/// where "1.2.3" < "1.10.0" (numeric, not string). Extra parts are
/// treated as 0 so "1.20" == "1.20.0". Non-numeric parts fall back to 0.
int compareVersions(String a, String b) {
  final aParts = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  final bParts = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  final len = aParts.length > bParts.length ? aParts.length : bParts.length;
  for (var i = 0; i < len; i++) {
    final ai = i < aParts.length ? aParts[i] : 0;
    final bi = i < bParts.length ? bParts[i] : 0;
    if (ai < bi) return -1;
    if (ai > bi) return 1;
  }
  return 0;
}
