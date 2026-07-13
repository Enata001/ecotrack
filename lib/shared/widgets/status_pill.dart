import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../config/app_sizes.dart';
import '../../core/utils/enums.dart';
import '../../core/utils/extensions.dart';

class StatusPill extends StatelessWidget {
  final RequestStatus status;
  final bool dense;

  const StatusPill({super.key, required this.status, this.dense = false});

  static Color colorFor(RequestStatus status) {
    switch (status) {
      case RequestStatus.completed:
        return AppColors.success;
      case RequestStatus.cancelled:
        return AppColors.error;
      case RequestStatus.pending:
        return AppColors.warning;
      case RequestStatus.accepted:
      case RequestStatus.enroute:
        return AppColors.primary;
    }
  }

  static IconData _iconFor(RequestStatus status) {
    switch (status) {
      case RequestStatus.completed:
        return Icons.check_circle_rounded;
      case RequestStatus.cancelled:
        return Icons.cancel_rounded;
      case RequestStatus.pending:
        return Icons.hourglass_top_rounded;
      case RequestStatus.accepted:
        return Icons.task_alt_rounded;
      case RequestStatus.enroute:
        return Icons.local_shipping_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(status);
    final isLive = status == RequestStatus.enroute;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSizes.spacing8 : AppSizes.spacing12,
        vertical: dense ? 3 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusCircular),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive)
            _PulsingDot(color: color)
          else
            Icon(_iconFor(status), size: dense ? 11 : 13, color: color),
          SizedBox(width: dense ? 4 : 6),
          Text(
            status.name.capitalize,
            style: TextStyle(
              color: color,
              fontSize: dense ? AppSizes.fontXS : AppSizes.fontS,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(_controller),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}