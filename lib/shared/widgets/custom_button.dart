import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_colors.dart';
import '../../config/app_sizes.dart';

enum CustomButtonStyle { primary, outlined, text, danger }


class CustomButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool loading;
  final bool outlined;
  final CustomButtonStyle style;
  final double? height;
  final IconData? icon;
  final bool expand;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.loading = false,
    this.outlined = false,
    this.style = CustomButtonStyle.primary,
    this.height,
    this.icon,
    this.expand = true,
  });

  const CustomButton.danger({
    super.key,
    required this.text,
    this.onPressed,
    this.loading = false,
    this.height,
    this.icon,
    this.expand = true,
  })  : outlined = false,
        style = CustomButtonStyle.danger;

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppSizes.durationFast,
    lowerBound: 0.0,
    upperBound: 1.0,
    value: 0.0,
  );

  late final Animation<double> _scale = Tween(begin: 1.0, end: 0.97)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  bool get _enabled => widget.onPressed != null && !widget.loading;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (!_enabled) return;
    _controller.forward();
  }

  void _onTapCancel() => _controller.reverse();

  void _onTapUp(TapUpDetails _) {
    _controller.reverse();
  }

  CustomButtonStyle get _effectiveStyle =>
      widget.outlined ? CustomButtonStyle.outlined : widget.style;

  @override
  Widget build(BuildContext context) {
    final child = widget.loading
        ? SizedBox(
      height: 20,
      width: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2.4,
        color: _effectiveStyle == CustomButtonStyle.outlined ||
            _effectiveStyle == CustomButtonStyle.text
            ? AppColors.primary
            : Colors.white,
      ),
    )
        : Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: AppSizes.iconS),
          const SizedBox(width: AppSizes.spacing8),
        ],
        Flexible(
          child: Text(
            widget.text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: -0.1),
          ),
        ),
      ],
    );

    Widget button;
    switch (_effectiveStyle) {
      case CustomButtonStyle.outlined:
        button = OutlinedButton(onPressed: widget.loading ? null : widget.onPressed, child: child);
        break;
      case CustomButtonStyle.text:
        button = TextButton(onPressed: widget.loading ? null : widget.onPressed, child: child);
        break;
      case CustomButtonStyle.danger:
        button = ElevatedButton(
          onPressed: widget.loading ? null : widget.onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            disabledBackgroundColor: AppColors.error.withValues(alpha: 0.4),
          ),
          child: child,
        );
        break;
      case CustomButtonStyle.primary:
        button = DecoratedBox(
          decoration: BoxDecoration(
            gradient: _enabled ? AppColors.heroGradient : null,
            color: _enabled ? null : AppColors.primary.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(AppSizes.radiusCircular),

          ),
          child: ElevatedButton(
            onPressed: widget.loading ? null : widget.onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
            ),
            child: child,
          ),
        );
        break;
    }

    final sized = SizedBox(
      width: widget.expand ? double.infinity : null,
      height: widget.height ?? AppSizes.buttonHeightM,
      child: button,
    );

    return GestureDetector(
      onTapDown: (d) {
        _onTapDown(d);
        if (_enabled) HapticFeedback.selectionClick();
      },
      onTapCancel: _onTapCancel,
      onTapUp: _onTapUp,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, c) => Transform.scale(scale: _scale.value, child: c),
        child: sized,
      ),
    );
  }
}