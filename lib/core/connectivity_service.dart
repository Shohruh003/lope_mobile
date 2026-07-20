import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Streams the device's online / offline status.
///
/// `connectivity_plus` gives us the transport (wifi, mobile, ethernet,
/// none). We treat anything other than `ConnectivityResult.none` as
/// "online" — actual reachability of `api.barberbook.uz` is proven by
/// individual API calls elsewhere (they surface errors via
/// [AppErrorState] when the DNS is up but the API host is down).
///
/// Consumers just watch [connectivityProvider] and render a banner /
/// retry action when the value flips to `false`.
class ConnectivityService {
  ConnectivityService(this._connectivity);
  final Connectivity _connectivity;

  Stream<bool> onlineStream() {
    // The onConnectivityChanged stream emits List<ConnectivityResult>
    // (multiple transports possible on some devices — e.g. wifi + mobile).
    // We flatten to a single bool: online iff at least one transport
    // isn't `none`.
    return _connectivity.onConnectivityChanged
        .map(_hasConnection)
        .distinct();
  }

  Future<bool> isOnlineNow() async {
    if (kIsWeb) return true; // web tab is trivially online
    try {
      final list = await _connectivity.checkConnectivity();
      return _hasConnection(list);
    } catch (_) {
      // Plugin failed — pretend online so we don't block the whole
      // app on a plugin bug.
      return true;
    }
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    for (final r in results) {
      if (r != ConnectivityResult.none) return true;
    }
    return false;
  }
}

final connectivityServiceProvider =
    Provider<ConnectivityService>((_) => ConnectivityService(Connectivity()));

/// True when the device has any network transport, false when
/// completely offline. Watch this from any widget that wants to
/// render an offline banner or gate a network-only action.
final connectivityProvider = StreamProvider<bool>((ref) async* {
  final svc = ref.watch(connectivityServiceProvider);
  // Emit the current state immediately so the UI doesn't flicker
  // "unknown" -> "online" on cold-start.
  yield await svc.isOnlineNow();
  yield* svc.onlineStream();
});
