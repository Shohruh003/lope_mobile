import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/asset_url.dart';
import '../../core/tr.dart';
import '../shared.dart';

/// Uzum/Click-style gradient profile card. Shows avatar + name + phone
/// on the primary gradient, with an optional pill-tap balance row
/// underneath so 'Hisobim' info lives on the profile tab too.
///
/// Extracted from the customer profile screen so the barber profile
/// can reuse the same visual — barber settings previously opened with
/// a bare 'Profilni tahrirlash' tile, which felt like a raw list next
/// to the customer's polished card. One shared widget also means
/// balance-tile design tweaks land in both roles at once.
///
///     ProfileHeroCard(
///       user: ref.watch(authControllerProvider).user,
///       balance: ref.watch(myBalanceProvider(user.id)),
///       onEdit: () => context.push('/profile-edit'),
///       onTopUp: () => context.push('/transactions'),
///     )
class ProfileHeroCard extends ConsumerWidget {
  const ProfileHeroCard({
    super.key,
    required this.user,
    required this.onEdit,
    required this.onTopUp,
    this.balance,
  });

  /// Auth user with .avatar / .name / .phone. Kept as `dynamic` so the
  /// shared widget doesn't have to import the auth-controller's User
  /// model (which would create a shared → feature import cycle).
  final dynamic user;

  /// Optional balance AsyncValue. When null the balance row is hidden
  /// — useful for roles that don't have a balance surface yet.
  final AsyncValue<dynamic>? balance;

  final VoidCallback onEdit;
  final VoidCallback onTopUp;

  String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final ri = s.length - i;
      buf.write(s[i]);
      if (ri > 1 && ri % 3 == 1) buf.write(' ');
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: AppSpacing.cardPaddingLg,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: AppRadius.rXl,
        boxShadow: AppShadows.primaryGlow(AppColors.primary),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with white ring
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: (user?.avatar?.isNotEmpty == true)
                      ? CachedNetworkImage(
                          imageUrl: assetUrl(user!.avatar),
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          placeholder: (_, _) =>
                              const SkeletonCircle(size: 64),
                          errorWidget: (_, _, _) =>
                              _Fallback(name: user?.name ?? '?'),
                        )
                      : _Fallback(name: user?.name ?? '?'),
                ),
              ),
              AppSpacing.hGapMd,
              // Name + phone
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? '—',
                      style: AppText.titleLg.copyWith(color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user?.phone ?? '',
                      style: AppText.bodySm.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              // Edit
              TapScale(
                onTap: onEdit,
                scale: 0.9,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit,
                      color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
          if (balance != null) ...[
            AppSpacing.gapLg,
            balance!.when(
              loading: () => const SkeletonLine(width: 180, height: 32),
              error: (e, _) => const SizedBox.shrink(),
              data: (b) {
                final amount = (b.amount as int?) ?? 0;
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: AppRadius.rMd,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: AppRadius.rSm,
                      ),
                      child: const Icon(Icons.account_balance_wallet,
                          color: Colors.white, size: 20),
                    ),
                    AppSpacing.hGapMd,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(ref, 'mobile.lopepay.home.balance',
                                'Balans'),
                            style: AppText.caption.copyWith(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            "${_fmt(amount)} ${tr(ref, 'common.currency', "so'm")}",
                            style: AppText.numeric.copyWith(
                              color: Colors.white,
                              fontSize: 22,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TapScale(
                      onTap: onTopUp,
                      scale: 0.94,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: AppRadius.rPill,
                        ),
                        child: Row(children: [
                          const Icon(Icons.add,
                              color: AppColors.primary, size: 16),
                          AppSpacing.hGapXs,
                          Text(
                            tr(ref, 'topUp.short', "To'ldirish"),
                            style: AppText.body.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ]),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.name});
  final String name;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.35),
            Colors.white.withValues(alpha: 0.15),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        (name.isNotEmpty ? name[0] : '?').toUpperCase(),
        style: AppText.titleLg.copyWith(
          color: Colors.white,
          fontSize: 28,
        ),
      ),
    );
  }
}
