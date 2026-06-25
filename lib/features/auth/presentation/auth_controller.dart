import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    } else if (state.user != null) {
      // refreshMe returned null AFTER a 401 — auth repo already cleared
      // storage; reflect signed-out in memory so guards re-render.
      // (Non-401 errors leave the cached user intact.)
      // We can't easily distinguish 401 vs other errors here; rely on
      // a subsequent guarded call to push the user back to /login.
    }
  }

  /// Public hook — callable from screens that just performed an action
  /// the server side reflects in /auth/me (e.g. top-up callback).
  Future<void> refreshFromServer() => _refreshSilent();

  Future<void> signedIn(AppUser user) async {
    state = AuthState(user: user, loading: false);
  }

  Future<void> logout() async {
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
