import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/colors.dart';
import '../theme/lope_colors.dart';

/// Foydalanuvchi ko'radigan xatolik holati — Click/Payme uslubida: ikon +
/// qisqa sarlavha + hikoya + "Qayta urinish" tugmasi. Xech qachon
/// DioException matni ekranga chiqmaydi.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.message,
    this.title,
    this.onRetry,
    this.icon = Icons.wifi_off_rounded,
  });

  final String message;
  final String? title;
  final VoidCallback? onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.danger, size: 34),
            ),
            const SizedBox(height: 20),
            Text(
              title ?? "Xatolik yuz berdi",
              style: TextStyle(
                color: palette.textBright,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onRetry!();
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text("Qayta urinish"),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bo'sh natija holati — Click/Payme uslubida yumshoq, "Sizda hali hech
/// narsa yo'q" ko'rinishi. Ikon + sarlavha + tavsif + ixtiyoriy CTA.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_rounded,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.14),
                    AppColors.primary.withValues(alpha: 0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                color: palette.textBright,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onAction!();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shimmer skelet — bare CircularProgressIndicator o'rniga ishlatiladi.
/// Click/Payme uslubidagi loyq animatsiya, xotira arzon.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
    this.margin,
  });

  final double? width;
  final double height;
  final double borderRadius;
  final EdgeInsets? margin;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final border = context.colors.border;
    return Container(
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + _c.value * 2, 0),
              end: Alignment(1 + _c.value * 2, 0),
              colors: [
                border.withValues(alpha: 0.3),
                border.withValues(alpha: 0.6),
                border.withValues(alpha: 0.3),
              ],
            ),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        ),
      ),
    );
  }
}

/// Umumiy list-item skeleton — kartochka + avatar + 2 qator matn.
class AppListSkeleton extends StatelessWidget {
  const AppListSkeleton({super.key, this.itemCount = 6});
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            const AppSkeleton(width: 44, height: 44, borderRadius: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSkeleton(width: MediaQuery.of(context).size.width * 0.4, height: 14),
                  const SizedBox(height: 8),
                  AppSkeleton(width: MediaQuery.of(context).size.width * 0.25, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
