import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Bridges incoming URIs (Android App Links, iOS Universal Links, and
/// the custom `lopestyle://` scheme) into the [GoRouter] so a link
/// tapped from SMS, Telegram, email or a browser lands on the right
/// screen inside the app instead of the launcher / splash.
///
/// URL mapping — every path that the web frontend serves should also
/// have a matching in-app route so users bounced from the browser
/// don't feel lost. The subset we support today:
///
///   https://lopestyle.uz/book/:barberId          -> /book/:barberId
///   https://lopestyle.uz/barber/:id              -> /barber/:id
///   https://lopestyle.uz/b/:slug                 -> /book/:slug (public
///                                                   short link shape
///                                                   from barber_public_link_screen)
///   https://app.lopestyle.uz/`<anything>`        -> forwarded verbatim
///   lopestyle://`<anything>`                     -> forwarded verbatim
///
/// Anything unrecognised falls through to the router's error page
/// which lands the user on /home so they see a working screen.
class DeepLinkService {
  DeepLinkService();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  Future<void> initIfPossible(GoRouter router) async {
    if (kIsWeb) return;
    try {
      // Cold-start: app launched by tapping a link. Read once.
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _handle(router, initial);

      // Warm-start: app already running, another link arrives.
      _sub?.cancel();
      _sub = _appLinks.uriLinkStream.listen((uri) => _handle(router, uri));
    } catch (_) {
      // Best-effort — a plugin failure should never block the app.
    }
  }

  void _handle(GoRouter router, Uri uri) {
    final path = uri.path;
    final host = uri.host;
    // Custom scheme (`lopestyle://xxx`) — the path is what matters.
    if (uri.scheme == 'lopestyle') {
      final target = path.isEmpty ? '/' : path;
      router.push(target.startsWith('/') ? target : '/$target');
      return;
    }
    // Universal / App Links from either subdomain.
    if (host == 'lopestyle.uz' || host == 'app.lopestyle.uz') {
      // Handle the couple of shortlink shapes that don't map 1:1.
      if (path.startsWith('/b/') && path.length > 3) {
        final slug = path.substring(3);
        router.push('/book/$slug');
        return;
      }
      // Everything else is forwarded — /home, /barber/:id, /book/:id,
      // /transactions, /promo, /notifications all exist in the router.
      router.push(path.isEmpty ? '/' : path);
      return;
    }
    // Unknown host — silently ignore, opening the browser was the
    // browser's decision.
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}

final deepLinkServiceProvider =
    Provider<DeepLinkService>((ref) => DeepLinkService());
