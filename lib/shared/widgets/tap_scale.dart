import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_sizes.dart';

class TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool haptic;

  const TapScale({
    super.key,
    required this.child,
    this.onTap,
    this.haptic = true,
  });

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppSizes.durationFast,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap == null
          ? null
          : () {
        if (widget.haptic) HapticFeedback.selectionClick();
        widget.onTap!.call();
      },
      onTapDown: widget.onTap == null ? null : (_) => _controller.forward(),
      onTapCancel: widget.onTap == null ? null : () => _controller.reverse(),
      onTapUp: widget.onTap == null ? null : (_) => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final scale = 1.0 - (_controller.value * 0.03);
          return Transform.scale(scale: scale, child: child);
        },
        child: widget.child,
      ),
    );
  }
}