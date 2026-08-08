import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/network/supabase_service.dart';
import 'core/providers/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ambas dependencias son asíncronas, así que se resuelven aquí y se inyectan
  // en el contenedor ya construidas.
  final preferences = await SharedPreferences.getInstance();
  final supabase = await SupabaseService.initialize();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        supabaseServiceProvider.overrideWithValue(supabase),
      ],
      child: const CriadorProApp(),
    ),
  );
}
