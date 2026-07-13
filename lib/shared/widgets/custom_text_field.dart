import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../config/app_sizes.dart';

class CustomTextField extends StatefulWidget {
  final String? label;
  final String? hint;
  final String? helperText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? Function(String?)? validator;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final Widget? prefix;
  final Widget? suffix;
  final int? maxLines;
  final void Function(String)? onChanged;
  final bool enabled;
  final bool autofocus;

  const CustomTextField({
    super.key,
    this.label,
    this.hint,
    this.helperText,
    this.controller,
    this.focusNode,
    this.validator,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onFieldSubmitted,
    this.prefix,
    this.suffix,
    this.maxLines = 1,
    this.onChanged,
    this.enabled = true,
    this.autofocus = false,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (_focused != _focusNode.hasFocus) {
      setState(() => _focused = _focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          AnimatedDefaultTextStyle(
            duration: AppSizes.durationFast,
            style: TextStyle(
              fontSize: AppSizes.fontM,
              fontWeight: FontWeight.w600,
              color: _focused ? AppColors.primary : AppColors.textPrimary,
            ),
            child: Text(widget.label!),
          ),
          const SizedBox(height: AppSizes.spacing8),
        ],
        AnimatedContainer(
          duration: AppSizes.durationFast,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
            boxShadow: _focused
                ? [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ]
                : null,
          ),
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            validator: widget.validator,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            onFieldSubmitted: widget.onFieldSubmitted,
            maxLines: widget.obscureText ? 1 : widget.maxLines,
            onChanged: widget.onChanged,
            enabled: widget.enabled,
            autofocus: widget.autofocus,
            style: const TextStyle(fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: widget.hint,
              helperText: widget.helperText,
              prefixIcon: widget.prefix,
              suffixIcon: widget.suffix,
            ),
          ),
        ),
      ],
    );
  }
}