import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'l10n/generated/app_l10n.dart';

class CriadorProApp extends ConsumerStatefulWidget {
  const CriadorProApp({super.key});

  @override
  ConsumerState<CriadorProApp> createState() => _CriadorProAppState();
}

class _CriadorProAppState extends ConsumerState<CriadorProApp> {
  @override
  void initState() {
    super.initState();
    // Arranca la sincronización en cuanto hay primer frame: antes de eso el
    // contenedor de providers todavía no está listo para leerse.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final sync = ref.read(syncServiceProvider);
      // Antes de arrancar: si el esquema local cambió, hay que volver a bajarlo
      // todo en vez de pedir solo lo modificado desde la última vez.
      await sync.resetWatermarksIfSchemaChanged(ref.read(appDatabaseProvider).schemaVersion);
      sync.start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppL10n.of(context).appName,
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(routerProvider),
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.themeMode,
      locale: settings.locale,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
    );
  }
}
