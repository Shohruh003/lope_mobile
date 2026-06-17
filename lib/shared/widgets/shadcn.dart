import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Shared building blocks that mirror the web's shadcn/ui primitives. These
/// keep the mobile and web app looking identical without each screen having
/// to re-implement the same border / radius / padding values.

/// `<Card>` — bg = scaffold bg, 1px border, 10px radius. Pass `padding`
/// (default 20) for the inner spacing.
class ShadCard extends StatelessWidget {
  const ShadCard({super.key, required this.child, this.padding = const EdgeInsets.all(20)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

/// `<Label>` — small (13px), medium (w500), secondary text color.
class ShadLabel extends StatelessWidget {
  const ShadLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      );
}

/// `<CardTitle>` — 18-22px, w700, bright text.
class ShadCardTitle extends StatelessWidget {
  const ShadCardTitle(this.text, {super.key, this.fontSize = 20});
  final String text;
  final double fontSize;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          color: AppColors.textBright,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      );
}

/// `<CardDescription>` — muted, 13px.
class ShadCardDescription extends StatelessWidget {
  const ShadCardDescription(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.5),
      );
}

/// Small circular "bubble" icon used as a card header avatar — matches the
/// web's `bg-primary/10 rounded-full h-12 w-12` pattern. Size defaults to
/// 48px to match the web.
class ShadIconBubble extends StatelessWidget {
  const ShadIconBubble({super.key, required this.icon, this.size = 48, this.color = AppColors.primary});
  final IconData icon;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: size * 0.5),
      );
}

/// Inline form field row used across login/register/profile: label above,
/// input below, optional helper/error text underneath.
class ShadField extends StatelessWidget {
  const ShadField({
    super.key,
    required this.label,
    required this.child,
    this.error,
  });
  final String label;
  final Widget child;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShadLabel(label),
        const SizedBox(height: 6),
        child,
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
        ],
      ],
    );
  }
}

/// SECTION label — small caps tracked, muted-foreground. Sits above a
/// `ShadTileGroup` to separate clusters of settings.
class ShadSectionLabel extends StatelessWidget {
  const ShadSectionLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 1,
            )),
      );
}

/// Rounded group container — `Card` minus the padding — for stacking
/// `ShadTile`s with internal dividers.
class ShadTileGroup extends StatelessWidget {
  const ShadTileGroup({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final out = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      out.add(children[i]);
      if (i < children.length - 1) {
        out.add(const Divider(height: 1, indent: 48, color: AppColors.border));
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: out),
    );
  }
}

/// Settings tile — leading colored icon + label + optional trailing widget
/// + chevron. Matches the web sidebar's link rows.
class ShadTile extends StatelessWidget {
  const ShadTile({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.trailing,
    this.destructive = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.danger : AppColors.textPrimary;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Icon(icon, color: destructive ? AppColors.danger : AppColors.primary, size: 18),
          const SizedBox(width: 14),
          Expanded(
              child: Text(label,
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: color))),
          // ignore: use_null_aware_elements
          if (trailing != null) trailing!,
          if (onTap != null && !destructive)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.chevron_right, color: AppColors.textMuted, size: 16),
            ),
        ]),
      ),
    );
  }
}

/// "OR" divider used between primary and secondary auth actions.
class ShadOrDivider extends StatelessWidget {
  const ShadOrDivider({super.key, this.label = 'YOKI'});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const Expanded(child: Divider(color: AppColors.border)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(label,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
      ),
      const Expanded(child: Divider(color: AppColors.border)),
    ]);
  }
}
