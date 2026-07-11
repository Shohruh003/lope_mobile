import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/auth_controller.dart';

class PromoCodeScreen extends ConsumerWidget {
  const PromoCodeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr(ref, 'promoCode.title', 'Promo kod'),
          style: AppText.titleMd,
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            // Rehydrate the AppUser (referral code + count) — the code
            // can be edited from web too, and referralsCount ticks up
            // whenever an invitee registers.
            await ref
                .read(authControllerProvider.notifier)
                .refreshFromServer();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              if (user != null) ...[
                _MyReferralCard(user: user)
                    .animate()
                    .fadeIn(duration: 400.ms),
                AppSpacing.gapLg,
                _InviteHint(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InviteHint extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      variant: AppCardVariant.outlined,
      padding: AppSpacing.cardPadding,
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.15),
            borderRadius: AppRadius.rSm,
          ),
          child: const Icon(Icons.tips_and_updates_outlined,
              color: AppColors.warning, size: 22),
        ),
        AppSpacing.hGapMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(ref, 'mobile.promo.hintTitle', 'Do\'stlaringizni taklif qiling'),
                style: AppText.titleSm,
              ),
              const SizedBox(height: 4),
              Text(
                tr(ref, 'mobile.promo.hintBody',
                    "Kodingizni yuboring — ular ro'yxatdan o'tganda ikkalangizga bonus tushadi."),
                style: AppText.bodySm,
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _MyReferralCard extends ConsumerStatefulWidget {
  const _MyReferralCard({required this.user});
  final AppUser user;

  @override
  ConsumerState<_MyReferralCard> createState() => _MyReferralCardState();
}

class _MyReferralCardState extends ConsumerState<_MyReferralCard> {
  bool _editing = false;
  bool _saving = false;
  final _editCtrl = TextEditingController();
  static final _allowed = RegExp(r'^[A-Z0-9]{1,20}$');

  @override
  void dispose() {
    _editCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    AppHaptics.medium();
    final next = _editCtrl.text.trim().toUpperCase();
    if (!_allowed.hasMatch(next)) {
      AppHaptics.error();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr(ref, 'promoCode.invalidFormat',
              'Faqat A-Z va 0-9 (1-20 belgi)'))));
      return;
    }
    if (next == (widget.user.referralCode ?? '')) {
      setState(() => _editing = false);
      return;
    }
    setState(() => _saving = true);
    try {
      final newCode =
          await ref.read(authRepositoryProvider).updateMyReferralCode(next);
      await ref
          .read(authControllerProvider.notifier)
          .updateReferralCode(newCode);
      if (mounted) {
        AppHaptics.success();
        setState(() => _editing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                tr(ref, 'promoCode.updated', 'Promo kod yangilandi'))));
      }
    } catch (e) {
      AppHaptics.error();
      if (mounted) {
        // The old `e.toString().contains('409')` sniff was fragile —
        // Dio's default toString doesn't include the status code
        // literally. Read the response's status directly instead.
        final isConflict =
            e is DioException && e.response?.statusCode == 409;
        final msg = isConflict
            ? tr(ref, 'promoCode.taken', 'Bu kod allaqachon olingan')
            : humanize(e);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.user.referralCode ?? '';
    return Container(
      padding: AppSpacing.cardPaddingLg,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: AppRadius.rXl,
        boxShadow: AppShadows.primaryGlow(AppColors.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: AppRadius.rSm,
              ),
              child: const Icon(Icons.card_giftcard,
                  color: Colors.white, size: 22),
            ),
            AppSpacing.hGapMd,
            Expanded(
              child: Text(
                tr(ref, 'mobile.promo.myCodeTitle',
                    'Sizning referral kodingiz'),
                style: AppText.titleMd.copyWith(color: Colors.white),
              ),
            ),
          ]),
          AppSpacing.gapLg,
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: AppRadius.rMd,
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: _editing
                ? Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _editCtrl,
                        autofocus: true,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Z0-9]')),
                          LengthLimitingTextInputFormatter(20),
                        ],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                          fontSize: 24,
                        ),
                        decoration: InputDecoration(
                          hintText: tr(ref,
                              'mobile.promo.hintExample', 'PROMO20'),
                          hintStyle: const TextStyle(
                              color: Colors.white54),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                      ),
                    ),
                    AppSpacing.hGapSm,
                    TapScale(
                      onTap: _saving
                          ? null
                          : () => setState(() => _editing = false),
                      scale: 0.9,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 18),
                      ),
                    ),
                    AppSpacing.hGapXs,
                    TapScale(
                      onTap: _saving ? null : _save,
                      scale: 0.9,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: _saving
                            ? const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary),
                              )
                            : const Icon(Icons.check,
                                color: AppColors.primary, size: 18),
                      ),
                    ),
                  ])
                : Row(children: [
                    Expanded(
                      child: Text(
                        code.isEmpty ? '—' : code,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 26,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                    if (code.isNotEmpty)
                      TapScale(
                        onTap: () async {
                          AppHaptics.light();
                          await Clipboard.setData(
                              ClipboardData(text: code));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(tr(
                                      ref,
                                      'mobile.barber.location.copied',
                                      'Nusxalandi'))));
                        },
                        scale: 0.9,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.copy,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    AppSpacing.hGapXs,
                    TapScale(
                      onTap: () {
                        AppHaptics.light();
                        _editCtrl.text = code;
                        setState(() => _editing = true);
                      },
                      scale: 0.9,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ]),
          ),
          AppSpacing.gapMd,
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: AppRadius.rPill,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.people_outline,
                  color: Colors.white, size: 16),
              AppSpacing.hGapSm,
              Flexible(
                child: Text(
                  tr(
                      ref,
                      'mobile.promo.invitedCount',
                      '{{n}} kishi sizning kodingizdan foydalandi',
                      {'n': '${widget.user.referralsCount}'}),
                  style: AppText.caption.copyWith(color: Colors.white),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
