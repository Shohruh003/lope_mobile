import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/errors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/app_states.dart';
import '../data/reviews_repository.dart';

class ReviewsScreen extends ConsumerWidget {
  const ReviewsScreen({super.key, required this.barberId});
  final String barberId;

  static final _df = DateFormat('dd.MM.yyyy', 'ru_RU');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(barberReviewsProvider(barberId));
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'mobile.reviews.title', "Sharhlar"))),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => _openSubmitSheet(context, ref),
        icon: const Icon(Icons.rate_review_outlined),
        label: Text(tr(ref, 'mobile.reviews.leaveReview', "Sharh qoldirish")),
      ),
      body: async.when(
        loading: () => const AppListSkeleton(itemCount: 5),
        error: (e, _) => AppErrorState(
          message: humanize(e),
          onRetry: () => ref.invalidate(barberReviewsProvider(barberId)),
        ),
        data: (list) {
          if (list.isEmpty) {
            return AppEmptyState(
              icon: Icons.rate_review_outlined,
              title: tr(ref, 'mobile.reviews.empty', "Hali sharhlar yo'q"),
              message: tr(
                ref,
                'mobile.reviews.emptyHint',
                "Birinchi bo'lib sharh qoldiring — boshqa mijozlarga tanlashda yordam beradi.",
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.refresh(barberReviewsProvider(barberId).future),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: list.length,
              separatorBuilder: (context, i) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final r = list[i];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Text(
                            r.userName.isEmpty
                                ? tr(ref, 'mobile.barber.bookingsAll.client', 'Mijoz')
                                : r.userName,
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14))),
                        Row(children: List.generate(5, (idx) => Icon(
                              idx < r.rating ? Icons.star : Icons.star_border,
                              color: const Color(0xFFFBBF24), size: 14,
                            ))),
                      ]),
                      if (r.comment.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(r.comment, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4)),
                      ],
                      const SizedBox(height: 6),
                      Text(_df.format(r.createdAt.toLocal()),
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                ).animate().fadeIn(duration: 250.ms, delay: (i * 30).ms).slideY(begin: 0.1, end: 0);
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _openSubmitSheet(BuildContext context, WidgetRef ref) async {
    int rating = 5;
    final commentCtrl = TextEditingController();
    bool busy = false;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 18,
            bottom: 20 + MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr(ref, 'mobile.reviews.leaveReview', "Sharh qoldirish"),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.3)),
              const SizedBox(height: 16),
              Center(
                child: Row(mainAxisSize: MainAxisSize.min, children: List.generate(5, (i) {
                  final filled = i < rating;
                  return IconButton(
                    icon: Icon(filled ? Icons.star : Icons.star_border, color: AppColors.warning, size: 36),
                    onPressed: () => setSheet(() => rating = i + 1),
                  );
                })),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: commentCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                    hintText: tr(ref, 'mobile.reviews.commentPlaceholder',
                        "Sharhingiz (ixtiyoriy)")),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: busy ? null : () async {
                    setSheet(() => busy = true);
                    try {
                      await ref.read(reviewsRepositoryProvider).submit(
                            barberId: barberId,
                            rating: rating,
                            comment: commentCtrl.text.trim(),
                          );
                      if (sheetCtx.mounted) Navigator.of(sheetCtx).pop(true);
                    } catch (e) {
                      if (sheetCtx.mounted) {
                        ScaffoldMessenger.of(sheetCtx).showSnackBar(SnackBar(
                            content: Text("${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
                      }
                    } finally {
                      setSheet(() => busy = false);
                    }
                  },
                  child: busy
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(tr(ref, 'mobile.reviews.submit', "Yuborish")),
                ),
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
