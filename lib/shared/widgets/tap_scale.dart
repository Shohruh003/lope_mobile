import 'package:flutter/widgets.dart';

import '../haptics.dart';
import '../theme/motion.dart';

/// Har tap'da element ozgina kichrayadi (0.96 gacha) + haptik feedback.
/// Uzum Bank / Click ilovalarida asosiy "signature" effekti shu — har card,
/// har tugma tap qilinganda bu jarangdorlikni beradi.
///
/// Ishlatish:
/// ```
/// TapScale(
///   onTap: () => Navigator.push(...),
///   child: MyCard(...),
/// )
/// ```
class TapScale extends StatefulWidget {
  const TapScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.96,
    this.duration = AppMotion.short,
    this.haptic = HapticStrength.light,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final Duration duration;
  final HapticStrength haptic;
  final bool enabled;

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.duration,
      reverseDuration: widget.duration,
      lowerBound: 0.0,
      upperBound: 1.0,
      value: 0.0,
    );
    _scale = Tween<double>(begin: 1.0, end: widget.scale).animate(
      CurvedAnimation(parent: _ctrl, curve: AppMotion.standard),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _fireHaptic() {
    switch (widget.haptic) {
      case HapticStrength.none:
        return;
      case HapticStrength.light:
        AppHaptics.light();
        break;
      case HapticStrength.medium:
        AppHaptics.medium();
        break;
      case HapticStrength.selection:
        AppHaptics.selection();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && (widget.onTap != null || widget.onLongPress != null);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: active ? (_) => _ctrl.forward() : null,
      onTapUp: active
          ? (_) {
              _ctrl.reverse();
              _fireHaptic();
              widget.onTap?.call();
            }
          : null,
      onTapCancel: active ? () => _ctrl.reverse() : null,
      onLongPress: active && widget.onLongPress != null
          ? () {
              _fireHaptic();
              widget.onLongPress!();
            }
          : null,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
