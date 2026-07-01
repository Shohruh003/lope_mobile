import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../data/shop_repository.dart';

/// Polls /blast-jobs/:id every 2s while the SMS blast is RUNNING and
/// renders a progress bar + sent/skipped/out-of-balance counters +
/// failed-row list. Mirrors web's BulkSendProgressModal.
///
/// Call via [show] — the future completes when the user closes the
/// dialog (only possible once the job leaves RUNNING).
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
      setState(() {
        _job = j;
        _loading = false;
      });
      if (j['status'] != 'RUNNING') {
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

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Header
            Row(children: [
              if (isRunning)
                const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5))
              else if (isDone)
                const Icon(Icons.check_circle,
                    color: AppColors.success, size: 22)
              else if (isFailed)
                const Icon(Icons.cancel,
                    color: AppColors.danger, size: 22)
              else
                const Icon(Icons.sms_outlined,
                    color: AppColors.textMuted, size: 22),
              const SizedBox(width: 8),
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
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textBright,
                        letterSpacing: -0.3)),
              ),
              if (!isRunning)
                IconButton(
                  icon:
                      const Icon(Icons.close, color: AppColors.textMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
            ]),
            const SizedBox(height: 14),

            if (_loading && j == null) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 16),
            ] else if (_error != null && j == null) ...[
              Text("${tr(ref, 'common.error', 'Xatolik')}: $_error",
                  style: const TextStyle(color: AppColors.danger)),
            ] else if (j != null) ...[
              // Progress bar
              Row(children: [
                Expanded(
                  child: Text(
                      tr(ref, 'blast.progress', "Jarayon"),
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                ),
                Text("$processed / $total ($pct%)",
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.textBright)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: total == 0 ? null : processed / total,
                  minHeight: 8,
                  backgroundColor:
                      AppColors.primary.withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
              const SizedBox(height: 14),

              // Counters
              Row(children: [
                Expanded(
                    child: _Counter(
                        label: tr(ref, 'blast.sent', "Yuborildi"),
                        value: sent,
                        color: AppColors.success)),
                const SizedBox(width: 8),
                Expanded(
                    child: _Counter(
                        label: tr(ref, 'blast.skipped', "O'tkazib yuborildi"),
                        value: skipped,
                        color: AppColors.warning)),
                const SizedBox(width: 8),
                Expanded(
                    child: _Counter(
                        label: tr(ref, 'blast.outOfBalance', "Balans yo'q"),
                        value: oob,
                        color: AppColors.danger)),
              ]),

              if (failedData.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 16, color: AppColors.warning),
                  const SizedBox(width: 4),
                  Text(
                      "${tr(ref, 'blast.failedList', "Muvaffaqiyatsizlar")} (${failedData.length})",
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textBright)),
                ]),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: failedData.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final f = failedData[i] as Map;
                      return Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(
                                  child: Text(
                                      (f['name'] ?? '—').toString(),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12)),
                                ),
                                Text((f['phone'] ?? '').toString(),
                                    style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 11)),
                              ]),
                              if (f['errorMessage'] != null) ...[
                                const SizedBox(height: 2),
                                Text(f['errorMessage'].toString(),
                                    style: const TextStyle(
                                        color: AppColors.danger,
                                        fontSize: 11)),
                              ],
                            ]),
                      );
                    },
                  ),
                ),
              ],
            ],

            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isRunning ? null : () => Navigator.of(context).pop(),
                child: Text(isRunning
                    ? tr(ref, 'blast.waitingHint',
                        "Tugaganda yopiladi…")
                    : tr(ref, 'common.close', "Yopish")),
              ),
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
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        Text("$value",
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 20,
                letterSpacing: -0.3)),
        const SizedBox(height: 2),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
