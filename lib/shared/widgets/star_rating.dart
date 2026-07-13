import 'package:flutter/material.dart';

import '../../config/app_colors.dart';

class StarRating extends StatelessWidget {
  final int value;
  final ValueChanged<int>? onChanged;
  final double size;
  final Color color;

  const StarRating({
    super.key,
    required this.value,
    this.onChanged,
    this.size = 32,
    this.color = AppColors.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < value;
        final star = Icon(
          filled ? Icons.star_rounded : Icons.star_border_rounded,
          size: size,
          color: color,
        );
        if (onChanged == null) return star;
        return InkWell(
          borderRadius: BorderRadius.circular(size),
          onTap: () => onChanged!(i + 1),
          child: Padding(padding: const EdgeInsets.all(2), child: star),
        );
      }),
    );
  }
}