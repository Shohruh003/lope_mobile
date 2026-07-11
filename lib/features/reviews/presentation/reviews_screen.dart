import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../data/reviews_repository.dart';

class ReviewsScreen extends ConsumerWidget {
  const ReviewsScreen({super.key, required this.barberId});
  final String barberId;

  // Locale-neutral formatter — the pattern renders identically without
  // the ru_RU locale, so dropping it removes an accidental "Russian
  // date format" signal on a UZ-first app.
  static final _df = DateFormat('dd.MM.yyyy');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(barberReviewsProvider(barberId));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr(ref, 'mobile.reviews.title', 'Sharhlar'),
          style: AppText.titleMd,
        ),
      ),
      floatingActionButton: TapScale(
        onTap: () => _openSubmitSheet(context, ref),
        scale: 0.94,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: AppRadius.rPill,
            boxShadow: AppShadows.primaryGlow(AppColors.primary),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.rate_review_outlined,
                color: Colors.white, size: 18),
            AppSpacing.hGapSm,
            Text(
              tr(ref, 'mobile.reviews.leaveReview', 'Sharh qoldirish'),
              style: AppText.button.copyWith(color: Colors.white),
            ),
          ]),
        ),
      ),
      body: async.when(
        loading: () => const AppListSkeleton(itemCount: 5),
        error: (e, _) => AppErrorState(
          message: humanize(e),
          onRetry: () => ref.invalidate(barberReviewsProvider(barberId)),
        ),
        data: (list) {
          if (list.isEmpty) {
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async =>
                  ref.refresh(barberReviewsProvider(barberId).future),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: 420,
                    child: AppEmptyState(
                      icon: Icons.rate_review_outlined,
                      title: tr(ref, 'mobile.reviews.empty',
                          "Hali sharhlar yo'q"),
                      message: tr(
                        ref,
                        'mobile.reviews.emptyHint',
                        "Birinchi bo'lib sharh qoldiring — boshqa mijozlarga tanlashda yordam beradi.",
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async =>
                ref.refresh(barberReviewsProvider(barberId).future),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                96,
              ),
              itemCount: list.length,
              separatorBuilder: (_, _) => AppSpacing.gapSm,
              itemBuilder: (context, i) {
                final r = list[i];
                return AppCard(
                  variant: AppCardVariant.outlined,
                  padding: AppSpacing.cardPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            (r.userName.isNotEmpty ? r.userName[0] : 'M')
                                .toUpperCase(),
                            style: AppText.titleSm
                                .copyWith(color: Colors.white),
                          ),
                        ),
                        AppSpacing.hGapMd,
                        Expanded(
                          child: Text(
                            r.userName.isEmpty
                                ? tr(ref, 'mobile.barber.bookingsAll.client',
                                    'Mijoz')
                                : r.userName,
                            style: AppText.titleSm,
                          ),
                        ),
                        Row(
                            children: List.generate(
                                5,
                                (idx) => Icon(
                                      idx < r.rating
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: AppColors.warning,
                                      size: 14,
                                    ))),
                      ]),
                      if (r.comment.isNotEmpty) ...[
                        AppSpacing.gapSm,
                        Text(
                          r.comment,
                          style: AppText.bodySm.copyWith(
                            color: context.colors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                      AppSpacing.gapXs,
                      Text(_df.format(r.createdAt.toLocal()),
                          style: AppText.caption),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(duration: 250.ms, delay: (i * 30).ms)
                    .slideY(begin: 0.1, end: 0);
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _openSubmitSheet(
      BuildContext context, WidgetRef ref) async {
    AppHaptics.light();
    int rating = 5;
    final commentCtrl = TextEditingController();
    bool busy = false;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.rTopXl),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.md,
            bottom:
                AppSpacing.lg + MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.border,
                    borderRadius: AppRadius.rPill,
                  ),
                ),
              ),
              AppSpacing.gapMd,
              Text(
                tr(ref, 'mobile.reviews.leaveReview', 'Sharh qoldirish'),
                style: AppText.titleMd,
              ),
              AppSpacing.gapLg,
              Center(
                child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (i) {
                      final filled = i < rating;
                      return TapScale(
                        onTap: () {
                          AppHaptics.selection();
                          setSheet(() => rating = i + 1);
                        },
                        scale: 0.85,
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            filled ? Icons.star : Icons.star_border,
                            color: AppColors.warning,
                            size: 40,
                          ),
                        ),
                      );
                    })),
              ),
              AppSpacing.gapMd,
              TextField(
                controller: commentCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: tr(ref, 'mobile.reviews.commentPlaceholder',
                      'Sharhingiz (ixtiyoriy)'),
                ),
              ),
              AppSpacing.gapLg,
              AppButton(
                label: tr(ref, 'mobile.reviews.submit', 'Yuborish'),
                variant: AppButtonVariant.primary,
                size: AppButtonSize.lg,
                fullWidth: true,
                loading: busy,
                onPressed: busy
                    ? null
                    : () async {
                        setSheet(() => busy = true);
                        try {
                          await ref
                              .read(reviewsRepositoryProvider)
                              .submit(
                                barberId: barberId,
                                rating: rating,
                                comment: commentCtrl.text.trim(),
                              );
                          AppHaptics.success();
                          if (sheetCtx.mounted) {
                            Navigator.of(sheetCtx).pop(true);
                          }
                        } catch (e) {
                          AppHaptics.error();
                          if (sheetCtx.mounted) {
                            ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        "${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
                          }
                        } finally {
                          setSheet(() => busy = false);
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
    commentCtrl.dispose();
    if (result == true) {
      ref.invalidate(barberReviewsProvider(barberId));
    }
  }
}
