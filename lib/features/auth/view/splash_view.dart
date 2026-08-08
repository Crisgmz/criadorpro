import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/brand.dart';
import '../viewmodel/splash_viewmodel.dart';

/// Pantalla 1 — fondo navy, logotipo centrado, indicador de carga.
///
/// Es la única pantalla que decide su propio destino: el `redirect` del router
/// la deja pasar a propósito para que `RF-AUT-01` pueda cumplirse.
class SplashView extends ConsumerStatefulWidget {
  const SplashView({super.key});

  @override
  ConsumerState<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends ConsumerState<SplashView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  Future<void> _resolve() async {
    final destination = await ref.read(splashViewModelProvider).resolve();
    if (!mounted) return;

    context.go(switch (destination) {
      SplashDestination.home => Routes.home,
      SplashDestination.onboarding => Routes.onboarding,
      SplashDestination.welcome => Routes.welcome,
    });
  }

  @override
  Widget build(BuildContext context) {
    // Sobre el navy, la hora y la batería se pintan en negro y no se leen. Va
    // en un AnnotatedRegion y no en un ajuste global para que el estilo vuelva
    // solo al salir de aquí: el resto de la app tiene fondo claro.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, // Android
        statusBarBrightness: Brightness.dark, // iOS
        systemNavigationBarColor: AppColors.navy,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.navy,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // El lockup ya incluye el nombre del producto: repetirlo debajo
              // sería decir dos veces lo mismo.
              const BrandLockup(width: 200, onDark: true),
              const SizedBox(height: AppSpacing.xl),
              const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
