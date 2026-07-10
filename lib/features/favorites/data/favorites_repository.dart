import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../barbers/domain/barber.dart';

class FavoritesRepository {
  FavoritesRepository(this._dio);
  final Dio _dio;

  Future<List<Barber>> list() async {
    final res = await _dio.get('/favorites');
    final data = res.data;
    final raw = (data is List)
        ? data
        : (data is Map && data['data'] is List ? data['data'] as List : <dynamic>[]);
    return raw.cast<Map<String, dynamic>>().map(Barber.fromJson).toList();
  }

  Future<bool> toggle(String barberId) async {
    final res = await _dio.post('/favorites/$barberId/toggle');
    if (res.data is Map && (res.data as Map)['favorited'] is bool) {
      return (res.data as Map)['favorited'] as bool;
    }
    return false;
  }
}

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
    (ref) => FavoritesRepository(ref.watch(dioProvider)));

/// Watches the auth state so a fresh login (or logout → re-login as a
/// different account) re-fetches favourites instead of returning the
/// previous user's cached list. The user.id is not actually used by the
/// /favorites endpoint (the backend resolves it from the JWT) but reading
/// it makes the provider's identity depend on the auth state.
final favoritesProvider = FutureProvider<List<Barber>>((ref) {
  final _ = ref.watch(authControllerProvider.select((s) => s.user?.id));
  return ref.watch(favoritesRepositoryProvider).list();
});

/// Optimistic favourite-ids store. UI reads this Set for the heart
/// state and calls [FavoritesController.toggleOptimistic] on tap — the
/// heart turns red immediately without waiting for the network round-
/// trip. If the API call fails, we revert.
class FavoritesController extends StateNotifier<Set<String>> {
  FavoritesController(this._ref) : super(const {});

  final Ref _ref;

  /// Seed the set from the server list. Called from a listener on
  /// [favoritesProvider] so a fresh fetch keeps this store in sync.
  void seed(Iterable<String> ids) {
    state = ids.toSet();
  }

  bool contains(String id) => state.contains(id);

  Future<void> toggleOptimistic(String barberId) async {
    final wasFav = state.contains(barberId);
    // 1. Optimistic flip
    state = wasFav
        ? (state.toSet()..remove(barberId))
        : (state.toSet()..add(barberId));
    try {
      final serverFav =
          await _ref.read(favoritesRepositoryProvider).toggle(barberId);
      // 2. Reconcile: server tells us the true state
      state = serverFav
          ? (state.toSet()..add(barberId))
          : (state.toSet()..remove(barberId));
      // 3. Refetch the list so the /favorites screen reflects the change
      _ref.invalidate(favoritesProvider);
    } catch (_) {
      // 4. Revert on error
      state = wasFav
          ? (state.toSet()..add(barberId))
          : (state.toSet()..remove(barberId));
    }
  }
}

final favoritesControllerProvider =
    StateNotifierProvider<FavoritesController, Set<String>>((ref) {
  final ctrl = FavoritesController(ref);
  // Whenever the server list resolves, seed the optimistic store.
  ref.listen(favoritesProvider, (_, next) {
    next.whenData((list) => ctrl.seed(list.map((b) => b.id)));
  });
  return ctrl;
});
