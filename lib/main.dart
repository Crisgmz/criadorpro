import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/db/app_database.dart';
import 'core/db/encrypted_connection.dart';
import 'core/network/supabase_service.dart';
import 'core/providers/providers.dart';
import 'core/security/secure_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Estas dependencias son asíncronas, así que se resuelven aquí y se inyectan
  // en el contenedor ya construidas.
  final preferences = await SharedPreferences.getInstance();
  final secureStore = SecureStore();

  // La clave va primero: sin ella no hay base que abrir. La primera vez se
  // genera y se guarda en el almacén seguro del sistema (`RNF-15`).
  final databaseKey = await secureStore.databaseKey();
  final database = AppDatabase(await EncryptedConnection.open(key: databaseKey));

  final supabase = await SupabaseService.initialize(secureStore: secureStore);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        supabaseServiceProvider.overrideWithValue(supabase),
        appDatabaseProvider.overrideWithValue(database),
        secureStoreProvider.overrideWithValue(secureStore),
      ],
      child: const CriadorProApp(),
    ),
  );
}
