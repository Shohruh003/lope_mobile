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
  }

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
