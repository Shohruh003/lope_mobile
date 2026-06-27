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
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);
