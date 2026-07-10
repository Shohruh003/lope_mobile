import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/push_service.dart';
import '../data/auth_repository.dart';
import '../domain/user.dart';

/// Auth state. `null` user means signed out; presence means signed in.
/// `loading` distinguishes the initial restore-from-storage check from a
/// genuine signed-out state so the splash can wait for a definitive answer.
class AuthState {
  const AuthState({this.user, this.loading = true});
  final AppUser? user;
  final bool loading;

  AuthState copyWith({AppUser? user, bool? loading, bool clearUser = false}) =>
      AuthState(
        user: clearUser ? null : (user ?? this.user),
        loading: loading ?? this.loading,
      );
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Kick off the restore on construction; UI watches `loading` to gate.
    _restore();
    return const AuthState();
  }

  Future<void> _restore() async {
    final repo = ref.read(authRepositoryProvider);
    final user = await repo.restoreSession();
    state = AuthState(user: user, loading: false);
    // Always re-fetch /auth/me on app open (silently) so server-side
    // balance / VIP grant / role changes propagate without forcing a
    // logout. Mirrors web's `loadUser().finally(setInitializing(false))`
    // pattern from App.tsx.
    if (user != null) {
      // ignore: unawaited_futures
      _refreshSilent();
    }
  }

  Future<void> _refreshSilent() async {
    final fresh = await ref.read(authRepositoryProvider).refreshMe();
    if (fresh != null) {
      state = state.copyWith(user: fresh);
      // Legacy customer accounts (created before server-side auto-gen)
      // ship a null referralCode. Silently claim one via the existing
      // PATCH endpoint so the promo screen always has a code ready
      // without any manual step from the user. Mobile-only fix — the
      // server is unmodified.
      // ignore: unawaited_futures
      _ensureReferralCode(fresh);
      return;
    }
    // refreshMe returned null — could be a 401 (auth repo already cleared
    // storage) or a transient network error. Check storage: if the token
    // is gone the session is definitively over and the in-memory user
    // should follow so router guards bounce to /login on the next build.
    // Transient errors leave the storage intact, so we keep the cached
    // user and try again on the next /auth/me refresh.
    final token = await ref.read(authRepositoryProvider).peekToken();
    if (token == null || token.isEmpty) {
      state = state.copyWith(loading: false, clearUser: true);
    }
  }

  /// Public hook — callable from screens that just performed an action
  /// the server side reflects in /auth/me (e.g. top-up callback).
  Future<void> refreshFromServer() => _refreshSilent();

  Future<void> signedIn(AppUser user) async {
    state = AuthState(user: user, loading: false);
    // PushService.initIfPossible ran before login so the first
    // /auth/register-device call had no Authorization header. Retry now
    // that we have a token so future pushes are routed to this device.
    // ignore: unawaited_futures
    ref.read(pushServiceProvider).registerCurrentToken();
    // Same legacy-account backfill as _refreshSilent: fresh logins
    // whose accounts predate auto-generation get their promo code
    // filled in the background before they ever open the promo screen.
    // ignore: unawaited_futures
    _ensureReferralCode(user);
  }

  Future<void> logout() async {
    await ref.read(pushServiceProvider).deregisterOnLogout();
    await ref.read(authRepositoryProvider).logout();
    state = const AuthState(loading: false);
  }

  /// Patch the in-memory user with a new referral code (after a
  /// successful PATCH /auth/me/referral-code). Keeps the rest of the
  /// user record intact.
  Future<void> updateReferralCode(String newCode) async {
    final current = state.user;
    if (current == null) return;
    final next = current.copyWith(referralCode: newCode);
    state = state.copyWith(user: next);
  }

  /// Silently claim a referral code for legacy accounts that shipped
  /// with a null one. Uses the existing PATCH /auth/me/referral-code
  /// endpoint — no backend changes. Retries up to 4 times on 409
  /// (collision with an existing user's code) before giving up.
  Future<void> _ensureReferralCode(AppUser user) async {
    if ((user.referralCode ?? '').isNotEmpty) return;
    final repo = ref.read(authRepositoryProvider);
    final rnd = Random();
    for (var attempt = 0; attempt < 4; attempt++) {
      final candidate = _seedReferralCode(user.name, rnd);
      try {
        final newCode = await repo.updateMyReferralCode(candidate);
        final current = state.user;
        if (current != null) {
          state = state.copyWith(
              user: current.copyWith(referralCode: newCode));
        }
        return;
      } catch (e) {
        // 409 → collision; loop with a fresh candidate. Any other error
        // is transient / permission-related and we just leave the code
        // null — the user can still enter one manually from the promo
        // screen's pencil button.
        if (!e.toString().contains('409')) return;
      }
    }
  }

  static String _seedReferralCode(String name, Random rnd) {
    final letters = name
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z]'), '')
        .padRight(4, 'X')
        .substring(0, 4);
    final digits = (100 + rnd.nextInt(900)).toString();
    return '$letters$digits';
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);
