import 'dart:async';

import '../../../core/base/base_viewmodel.dart';
import '../../../core/config/app_config.dart';
import '../../../core/db/daos/clutches_dao.dart';
import '../../../core/domain/sex.dart';
import '../../../core/sync/sync_service.dart';
import '../../auth/model/profile.dart';
import '../../auth/repository/profile_repository.dart';
import '../../birds/repository/birds_repository.dart';

/// Resumen del criadero. Todo sale de streams de Drift, así que también
/// funciona sin conexión.
class DashboardViewModel extends BaseViewModel {
  DashboardViewModel({
    required BirdsRepository birds,
    required ProfileRepository profiles,
    required ClutchesDao clutches,
    required SyncService sync,
    required String ownerId,
  }) : _birds = birds,
       _profiles = profiles,
       _clutches = clutches,
       _sync = sync,
       _ownerId = ownerId {
    _subscribe();
  }

  final BirdsRepository _birds;
  final ProfileRepository _profiles;
  final ClutchesDao _clutches;
  final SyncService _sync;
  final String _ownerId;

  final List<StreamSubscription<Object?>> _subscriptions = [];

  Map<Sex, int> _tally = const {};
  int _activeCount = 0;
  int _clutchCount = 0;
  Profile? _profile;
  int _pendingChanges = 0;
  SyncStatus _syncStatus = SyncStatus.idle;

  int get total => _tally.values.fold(0, (sum, value) => sum + value);
  int get males => _tally[Sex.male] ?? 0;
  int get females => _tally[Sex.female] ?? 0;
  int get unsexed => _tally[Sex.unknown] ?? 0;

  /// Cuarto contador de Inicio — `RF-REG-01`: totales, machos, hembras y
  /// camadas.
  int get clutches => _clutchCount;

  /// Nombre del criadero para el encabezado (PRD, pantalla 15). Vacío mientras
  /// el perfil no ha bajado; la cabecera cae entonces al nombre del producto.
  String get farmName => _profile?.farmName ?? '';
  int get pendingChanges => _pendingChanges;
  SyncStatus get syncStatus => _syncStatus;

  /// Ejemplares que consumen cupo — solo los activos (`RS-02`).
  int get activeCount => _activeCount;

  SubscriptionPlan get plan => _profile?.effectivePlan ?? SubscriptionPlan.free;

  /// `null` en el plan Élite, que no tiene tope.
  int? get planLimit => plan.birdLimit;

  /// `RF-REG-02` — avisa al llegar al 80 % de la capacidad del plan. El umbral
  /// deja margen para reaccionar antes de que la app deje de admitir altas, que
  /// es lo que evita que el criador se quede a medias con la camada delante.
  bool get isNearPlanLimit {
    final limit = planLimit;
    if (limit == null) return false;
    return _activeCount >= limit * AppConfig.planWarningThreshold && _activeCount < limit;
  }

  /// `RF-REG-16` — alcanzado el tope no se puede crear, pero consultar y
  /// exportar siguen disponibles.
  bool get isAtPlanLimit {
    final limit = planLimit;
    return limit != null && _activeCount >= limit;
  }

  Future<void> syncNow() => _sync.syncNow();

  void _subscribe() {
    setLoading();
    _subscriptions
      ..add(
        _birds.watchSexTally(_ownerId).listen((tally) {
          _tally = tally;
          setReady();
        }),
      )
      ..add(
        _birds.watchCount(_ownerId).listen((count) {
          _activeCount = count;
          safeNotify();
        }),
      )
      ..add(
        _clutches.watchCountForOwner(_ownerId).listen((count) {
          _clutchCount = count;
          safeNotify();
        }),
      )
      ..add(
        _profiles.watchProfile(_ownerId).listen((profile) {
          _profile = profile;
          safeNotify();
        }),
      )
      ..add(
        _sync.pendingCount.listen((count) {
          _pendingChanges = count;
          safeNotify();
        }),
      )
      ..add(
        _sync.status.listen((status) {
          _syncStatus = status;
          safeNotify();
        }),
      );
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }
}
