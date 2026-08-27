import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/db/daos/birds_dao.dart';
import '../../../core/db/daos/clutches_dao.dart';
import '../../../core/db/daos/evaluations_dao.dart';
import '../../../core/db/daos/payroll_dao.dart';
import '../../../core/db/daos/profiles_dao.dart';
import '../../../core/db/daos/sync_queue_dao.dart';
import '../../../core/db/daos/transactions_dao.dart';
import '../../../core/error/failure.dart';
import '../../../core/network/supabase_service.dart';
import '../../../core/sync/sync_service.dart';
import '../../../core/utils/result.dart';
import '../../../core/utils/validators.dart';
import '../model/country.dart';
import 'auth_preferences.dart';

/// Resultado de un alta: Supabase puede dejar la sesión abierta o exigir que
/// el usuario confirme el correo antes de entrar.
enum SignUpOutcome { signedIn, needsEmailConfirmation }

/// Para qué se pide el código de seis dígitos. Determina el `OtpType` de
/// Supabase y a qué pantalla se vuelve al terminar.
enum VerificationPurpose { signUp, passwordRecovery }

/// Proveedores externos de acceso — `RF-AUT-11`.
enum SocialProvider { google, apple }

class AuthRepository {
  AuthRepository({
    required SupabaseService supabase,
    required ProfilesDao profilesDao,
    required BirdsDao birdsDao,
    required ClutchesDao clutchesDao,
    required EvaluationsDao evaluationsDao,
    required TransactionsDao transactionsDao,
    required PayrollDao payrollDao,
    required SyncQueueDao syncQueue,
    required SyncService syncService,
    required AuthPreferences preferences,
  }) : _supabase = supabase,
       _profilesDao = profilesDao,
       _birdsDao = birdsDao,
       _clutchesDao = clutchesDao,
       _evaluationsDao = evaluationsDao,
       _transactionsDao = transactionsDao,
       _payrollDao = payrollDao,
       _syncQueue = syncQueue,
       _syncService = syncService,
       _preferences = preferences;

  final SupabaseService _supabase;
  final ProfilesDao _profilesDao;
  final BirdsDao _birdsDao;
  final ClutchesDao _clutchesDao;
  final EvaluationsDao _evaluationsDao;
  final TransactionsDao _transactionsDao;
  final PayrollDao _payrollDao;
  final SyncQueueDao _syncQueue;
  final SyncService _syncService;
  final AuthPreferences _preferences;

  bool get isEnabled => _supabase.isEnabled;

  bool get isSignedIn => _supabase.hasSession;

  String? get currentUserId => _supabase.currentUserId;

  String? get currentEmail => _supabase.currentUser?.email;

  Stream<AuthState> get authStateChanges => _supabase.authStateChanges;

  // --- Sesión --------------------------------------------------------------

  /// `RF-AUT-09`. Ante credenciales inválidas devuelve siempre el mismo motivo,
  /// sin distinguir si el correo existe — `RF-AUT-10` · `E-AUTH-01`.
  Future<Result<void>> signIn({required String email, required String password}) => _run(() async {
    await _supabase.client.auth.signInWithPassword(
      email: Validators.normalizeEmail(email),
      password: password,
    );
    await _adoptSession();
  });

  /// `RF-AUT-03`. Los datos del perfil viajan como metadatos del usuario para
  /// que el trigger `handle_new_user()` pueda sembrar la fila de `profiles`.
  Future<Result<SignUpOutcome>> signUp({
    required String email,
    required String password,
    required String fullName,
    required Country country,
    required String locale,
    String? phone,
  }) => _run(() async {
    final response = await _supabase.client.auth.signUp(
      email: Validators.normalizeEmail(email),
      password: password,
      data: {
        'full_name': fullName.trim(),
        'country_code': country.code,
        // `profiles.locale` solo admite es o en; cualquier otra cosa haría
        // fallar el CHECK y con él el alta entera.
        'locale': AppConfig.supportedLocales.contains(locale) ? locale : AppConfig.defaultLocale,
        if (phone != null && phone.trim().isNotEmpty) 'phone': country.toE164(phone),
      },
    );
    return response.session == null ? SignUpOutcome.needsEmailConfirmation : SignUpOutcome.signedIn;
  });

  /// Cierra sesión y borra los datos locales.
  ///
  /// `RF-AUT-15` pide conservarlos cifrados y reasociarlos si vuelve el mismo
  /// usuario, pero eso depende de que la base esté cifrada (`RNF-15`, todavía
  /// sin implementar). Mientras no lo esté, borrar es lo correcto: otro usuario
  /// podría entrar en el mismo dispositivo. La UI avisa si quedan cambios sin
  /// sincronizar.
  /// `RF-AUT-15` — cerrar sesión **conserva los datos locales**.
  ///
  /// Antes se borraba todo, y era lo correcto mientras la base estaba en claro:
  /// en un teléfono compartido, dejar el libro de otro criadero legible era
  /// peor que hacerle volver a descargarlo. Con la base cifrada (`RNF-15`) esa
  /// razón desaparece: los datos quedan, y volver a entrar es instantáneo en
  /// lugar de exigir una descarga completa en medio del galpón.
  ///
  /// Lo que sí se limpia son las marcas de sincronización, para que la próxima
  /// entrada compruebe contra el servidor en vez de fiarse de una foto vieja.
  Future<Result<void>> signOut() async {
    final result = await _run(() async {
      if (isEnabled) await _supabase.client.auth.signOut();
    });
    if (result case Err(:final failure)) return Err(failure);

    await _syncService.clearWatermarks();
    return const Ok(null);
  }

  /// Deja la base local lista para quien acaba de entrar.
  ///
  /// Si es otro criadero, se borra todo lo del anterior. Las consultas ya
  /// filtran por `owner_id` y no mezclarían nada, pero los datos seguirían en
  /// el dispositivo, y `RF-AUT-15` conserva el libro **de su dueño**, no el de
  /// cualquiera que haya pasado por aquí.
  Future<void> _adoptSession() async {
    final ownerId = _supabase.currentUserId;
    if (ownerId == null) return;
    await adoptSession(ownerId);
  }

  /// Público para poder verificarlo: es la regla que impide que dos criadores
  /// que comparten teléfono acaben viendo el libro del otro.
  @visibleForTesting
  Future<void> adoptSession(String ownerId) async {
    final previous = _preferences.lastOwnerId;
    if (previous != null && previous != ownerId) await _wipeLocalData();

    await _preferences.rememberOwner(ownerId);
  }

  /// **Todas** las tablas de datos del criadero, sin excepción.
  ///
  /// Cada módulo nuevo tiene que añadirse aquí. Olvidarse de uno no rompe nada
  /// visible —las consultas filtran por `owner_id`— pero deja los datos del
  /// criadero anterior en el teléfono de otro, que es exactamente lo que
  /// `RF-AUT-15` no permite.
  Future<void> _wipeLocalData() async {
    await _birdsDao.clear();
    await _clutchesDao.clear();
    await _evaluationsDao.clear();
    await _transactionsDao.clear();
    await _payrollDao.clear();
    await _profilesDao.clear();
    await _syncQueue.clear();
    await _syncService.clearWatermarks();
  }

  // --- Verificación por código --------------------------------------------

  /// `RF-AUT-06` para el alta y `RF-AUT-12` para la recuperación.
  ///
  /// Ambos flujos verifican con el mismo código de seis dígitos; lo que cambia
  /// es el `OtpType`. Al terminar queda una sesión activa: en la recuperación
  /// es justo lo que habilita [updatePassword].
  Future<Result<void>> verifyCode({
    required String email,
    required String code,
    required VerificationPurpose purpose,
  }) => _run(() async {
    await _supabase.client.auth.verifyOTP(
      email: Validators.normalizeEmail(email),
      token: code.trim(),
      type: switch (purpose) {
        VerificationPurpose.signUp => OtpType.signup,
        VerificationPurpose.passwordRecovery => OtpType.recovery,
      },
    );
    await _adoptSession();
  });

  /// `RF-AUT-08` — reenvío tras la cuenta regresiva.
  Future<Result<void>> resendCode({required String email, required VerificationPurpose purpose}) =>
      _run(() async {
        final normalized = Validators.normalizeEmail(email);
        switch (purpose) {
          case VerificationPurpose.signUp:
            await _supabase.client.auth.resend(type: OtpType.signup, email: normalized);
          case VerificationPurpose.passwordRecovery:
            // La recuperación no tiene `resend`: se vuelve a pedir el código.
            await _supabase.client.auth.resetPasswordForEmail(normalized);
        }
      });

  // --- Recuperación de contraseña -----------------------------------------

  /// `RF-AUT-12` — envía el código al correo. Es gratuito y no depende del
  /// plan; tampoco revela si el correo está registrado.
  Future<Result<void>> sendPasswordResetCode({required String email}) => _run(
    () async => _supabase.client.auth.resetPasswordForEmail(Validators.normalizeEmail(email)),
  );

  /// Cambia la contraseña de la sesión abierta por [verifyCode]. Tras esto,
  /// `RF-AUT-13` obliga a llevar al usuario a iniciar sesión, no a la app.
  Future<Result<void>> updatePassword({required String password}) =>
      _run(() async => _supabase.client.auth.updateUser(UserAttributes(password: password)));

  // --- Acceso con proveedor externo ---------------------------------------

  /// `RF-AUT-11` — Google en ambas plataformas, Apple en iOS.
  ///
  /// Pendiente de credenciales de plataforma: hacen falta los client ID de
  /// Google Cloud, «Sign in with Apple» habilitado en el perfil de
  /// aprovisionamiento y los proveedores activados en Supabase. La pantalla de
  /// bienvenida ya muestra los botones, deshabilitados con este motivo.
  Future<Result<void>> signInWithProvider(SocialProvider provider) async =>
      const Err(AuthFailure(reason: AuthFailureReason.providerUnavailable));

  // --- Traducción de errores ----------------------------------------------

  /// Envuelve una llamada a Supabase: comprueba que haya backend, ejecuta y
  /// traduce cualquier excepción a un [Failure]. Ninguna excepción sale de aquí
  /// hacia arriba.
  Future<Result<T>> _run<T>(Future<T> Function() action) async {
    if (!isEnabled) {
      return const Err(AuthFailure(reason: AuthFailureReason.notConfigured));
    }
    try {
      return Ok(await action());
    } on AuthException catch (error) {
      return Err(_mapAuthException(error));
    } catch (error) {
      return Err(NetworkFailure(debugMessage: error.toString(), cause: error));
    }
  }

  AuthFailure _mapAuthException(AuthException error) {
    final code = error.code ?? '';
    final message = error.message.toLowerCase();

    AuthFailure of(AuthFailureReason reason) =>
        AuthFailure(reason: reason, debugMessage: '$code: ${error.message}');

    if (code == 'invalid_credentials' || message.contains('invalid login')) {
      return of(AuthFailureReason.invalidCredentials);
    }
    if (code == 'user_already_exists' ||
        code == 'email_exists' ||
        message.contains('already registered')) {
      return of(AuthFailureReason.emailAlreadyRegistered);
    }
    if (code == 'otp_expired' || message.contains('expired')) {
      return of(AuthFailureReason.codeExpired);
    }
    if (message.contains('token') || message.contains('otp')) {
      return of(AuthFailureReason.codeInvalid);
    }
    // `RNF-18`: 5 intentos de sesión en 15 minutos, 3 envíos de código por hora.
    if (code.startsWith('over_') || code == 'too_many_requests' || error.statusCode == '429') {
      return of(AuthFailureReason.tooManyAttempts);
    }
    if (code == 'same_password') {
      return of(AuthFailureReason.samePassword);
    }
    if (code == 'session_not_found' || message.contains('jwt')) {
      return of(AuthFailureReason.notAuthenticated);
    }
    return of(AuthFailureReason.unknown);
  }
}
