import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../data/shop_repository.dart';

class BulkSendProgressModal {
  static Future<void> show(BuildContext context,
      {required String jobId}) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _BulkSendProgress(jobId: jobId),
    );
  }
}

class _BulkSendProgress extends ConsumerStatefulWidget {
  const _BulkSendProgress({required this.jobId});
  final String jobId;
  @override
  ConsumerState<_BulkSendProgress> createState() => _BulkSendProgressState();
}

class _BulkSendProgressState extends ConsumerState<_BulkSendProgress> {
  Timer? _timer;
  Map<String, dynamic>? _job;
  bool _loading = true;
  String? _error;
  bool _wasRunning = false;

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final j = await ref.read(shopRepositoryProvider).blastJob(widget.jobId);
      if (!mounted) return;
      final isRun = j['status'] == 'RUNNING';
      if (_wasRunning && !isRun) {
        AppHaptics.success();
      }
      _wasRunning = isRun;
      setState(() {
        _job = j;
        _loading = false;
      });
      if (!isRun) {
        _timer?.cancel();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final j = _job;
    final status = (j?['status'] ?? '').toString();
    final isRunning = status == 'RUNNING';
    final isDone = status == 'COMPLETED';
    final isFailed = status == 'FAILED';
    final total = ((j?['total'] ?? 0) as num).toInt();
    final processed = ((j?['processed'] ?? 0) as num).toInt();
    final sent = ((j?['sent'] ?? 0) as num).toInt();
    final skipped = ((j?['skipped'] ?? 0) as num).toInt();
    final oob = ((j?['outOfBalance'] ?? 0) as num).toInt();
    final pct = total == 0 ? 0 : ((processed / total) * 100).round();
    final failed = (j?['failed'] is Map ? j!['failed'] as Map : {});
    final failedData = (failed['data'] as List?) ?? const [];

    final heroColor = isDone
        ? AppColors.success
        : isFailed
            ? AppColors.danger
            : AppColors.primary;

    return Dialog(
      backgroundColor: context.colors.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: heroColor.withValues(alpha: 0.12),
                  borderRadius: AppRadius.rMd,
                ),
                child: isRunning
                    ? Padding(
                        padding: const EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: heroColor),
                      )
                    : Icon(
                        isDone
                            ? Icons.check_circle
                            : isFailed
                                ? Icons.cancel
                                : Icons.sms_outlined,
                        color: heroColor,
                        size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                    isRunning
                        ? tr(ref, 'blast.runningTitle',
                            "SMS yuborilmoqda...")
                        : isDone
                            ? tr(ref, 'blast.doneTitle', "Yuborildi")
                            : isFailed
                                ? tr(ref, 'blast.failedTitle',
                                    "Xatolik bilan tugadi")
                                : tr(ref, 'common.loading', 'Yuklanmoqda…'),
                    style: AppText.titleMd),
              ),
              if (!isRunning)
                IconButton(
                  icon:
                      Icon(Icons.close, color: context.colors.textMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
            ]),
            const SizedBox(height: AppSpacing.md),

            if (_loading && j == null) ...[
              const SizedBox(height: AppSpacing.lg),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: AppSpacing.lg),
            ] else if (_error != null && j == null) ...[
              Text("${tr(ref, 'common.error', 'Xatolik')}: $_error",
                  style: AppText.body.copyWith(color: AppColors.danger)),
            ] else if (j != null) ...[
              Row(children: [
                Expanded(
                  child: Text(tr(ref, 'blast.progress', "Jarayon"),
                      style: AppText.caption),
                ),
                Text("$processed / $total ($pct%)",
                    style: AppText.button.copyWith(fontSize: 13)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: total == 0 ? null : processed / total,
                  minHeight: 8,
                  backgroundColor:
                      heroColor.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(heroColor),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              Row(children: [
                Expanded(
                    child: _Counter(
                        label: tr(ref, 'blast.sent', "Yuborildi"),
                        value: sent,
                        color: AppColors.success)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                    child: _Counter(
                        label: tr(ref, 'blast.skipped', "O'tkazib yuborildi"),
                        value: skipped,
                        color: AppColors.warning)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                    child: _Counter(
                        label: tr(ref, 'blast.outOfBalance', "Balans yo'q"),
                        value: oob,
                        color: AppColors.danger)),
              ]),

              if (failedData.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Row(children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 16, color: AppColors.warning),
                  const SizedBox(width: 4),
                  Text(
                      "${tr(ref, 'blast.failedList', "Muvaffaqiyatsizlar")} (${failedData.length})",
                      style: AppText.titleSm.copyWith(fontSize: 13)),
                ]),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: failedData.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final f = failedData[i] as Map;
                      return AppCard(
                        variant: AppCardVariant.flat,
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(
                                  child: Text(
                                      (f['name'] ?? '—').toString(),
                                      style: AppText.titleSm
                                          .copyWith(fontSize: 13)),
                                ),
                                Text((f['phone'] ?? '').toString(),
                                    style: AppText.caption),
                              ]),
                              if (f['errorMessage'] != null) ...[
                                const SizedBox(height: 2),
                                Text(f['errorMessage'].toString(),
                                    style: AppText.caption.copyWith(
                                        color: AppColors.danger,
                                        fontSize: 12)),
                              ],
                            ]),
                      );
                    },
                  ),
                ),
              ],
            ],

            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: isRunning
                  ? tr(ref, 'blast.waitingHint', "Tugaganda yopiladi…")
                  : tr(ref, 'common.close', "Yopish"),
              onPressed:
                  isRunning ? null : () => Navigator.of(context).pop(),
              fullWidth: true,
            ),
          ]),
        ),
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter(
      {required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.14),
            color.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.rMd,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        Text("$value",
            style: AppText.numeric.copyWith(color: color, fontSize: 20)),
        const SizedBox(height: 2),
        Text(label,
            textAlign: TextAlign.center,
            style: AppText.caption.copyWith(fontSize: 10)),
      ]),
    );
  }
}
