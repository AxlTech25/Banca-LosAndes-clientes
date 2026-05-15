import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class UnderlinedLosAndesTextField extends StatelessWidget {
  const UnderlinedLosAndesTextField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
    this.textInputAction = TextInputAction.next,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        validator: validator,
        textInputAction: textInputAction,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: suffixIcon,
          contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.outlineVariant, width: 2),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.primaryContainer, width: 2),
          ),
          errorBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.error, width: 2),
          ),
          focusedErrorBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.error, width: 2),
          ),
          labelStyle: const TextStyle(color: AppColors.outline),
          floatingLabelStyle: const TextStyle(
            color: AppColors.primaryContainer,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
