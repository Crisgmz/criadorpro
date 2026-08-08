import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../l10n/generated/app_l10n.dart';

/// Contenedor de las pestañas principales. La franja de "sin conexión" vive
/// aquí para que se vea en las tres sin repetirla en cada pantalla.
///
/// El panel lateral **no** puede vivir aquí: cada pantalla trae su propio
/// `Scaffold` con su `AppBar`, y un `AppBar` solo dibuja el ☰ si encuentra un
/// `drawer` en el `Scaffold` más cercano. Por eso cada pestaña declara
/// `drawer: AppDrawer()` — es la misma instancia lógica, no tres menús.
class DashboardShell extends StatelessWidget {
  const DashboardShell({required this.child, required this.location, super.key});

  final Widget child;
  final String location;

  static const _tabs = [Routes.home, Routes.birds, Routes.settings];

  int get _selectedIndex {
    final index = _tabs.indexWhere((tab) => location.startsWith(tab));
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => context.go(_tabs[index]),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.navHome,
          ),
          NavigationDestination(
            // `BrandIcon` y no `BrandSymbol`: hereda del `IconTheme` que la
            // barra fija por estado, así que se tiñe y se dimensiona como sus
            // vecinos de Material en vez de quedarse apagado al lado.
            //
            // El símbolo es sólido y no tiene variante de contorno; lo que
            // distingue el destino activo es el color y la píldora.
            icon: const BrandIcon(),
            selectedIcon: const BrandIcon(),
            label: l10n.navBirds,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.navSettings,
          ),
        ],
      ),
    );
  }
}
