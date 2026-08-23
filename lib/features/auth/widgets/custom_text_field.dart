import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';

/// A styled text field with icon, label, and validation support.
class CustomTextField extends StatelessWidget {
  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.helperText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.textInputAction,
    this.onFieldSubmitted,
    this.maxLength,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? helperText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final int? maxLength;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      maxLength: maxLength,
      maxLines: maxLines,
      style: Theme.of(context).textTheme.bodyLarge,
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        counterText: '',
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 22, color: AppColors.textSecondary)
            : null,
        suffixIcon: suffixIcon,
      ),
    );
  }
}
