import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Superficie navy de marca: la tarjeta del criadero, la de membresía y la de
/// nómina comparten este tratamiento.
///
/// El navy es fijo en los dos temas —es color de marca, no de superficie—, así
/// que en oscuro hay que separarlo del fondo con un borde: `navy` y `navyDeep`
/// se parecen lo suficiente como para que la tarjeta desaparezca sin él.
class NavySurface extends StatelessWidget {
  const NavySurface({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: borderRadius ?? BorderRadius.circular(AppRadius.card),
        border: isDark ? Border.all(color: AppColors.borderDark) : null,
      ),
      child: child,
    );
  }
}
