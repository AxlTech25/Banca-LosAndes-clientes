import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

abstract final class AppAssets {
  static const logo = 'assets/images/logo_banco_los_andes.png';
}

class BancoLosAndesLogo extends StatelessWidget {
  const BancoLosAndesLogo({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.borderRadius,
  });

  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      AppAssets.logo,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return SizedBox(
          width: width ?? 48,
          height: height ?? 48,
          child: const Icon(
            Icons.account_balance,
            color: AppColors.primary,
          ),
        );
      },
    );

    if (borderRadius == null) {
      return image;
    }

    return ClipRRect(borderRadius: borderRadius!, child: image);
  }
}
