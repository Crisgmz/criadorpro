import 'dart:async';

import '../../../core/base/base_viewmodel.dart';
import '../../../core/config/app_config.dart';
import '../../../core/sync/sync_service.dart';
import '../../auth/model/profile.dart';
import '../../auth/repository/auth_repository.dart';
import '../../auth/repository/profile_repository.dart';
import '../../birds/repository/birds_repository.dart';

/// Pantalla de ajustes: cuenta, plan y estado de la sincronización.
class SettingsViewModel extends BaseViewModel {
  SettingsViewModel({
    required AuthRepository auth,
    required ProfileRepository profiles,
    required BirdsRepository birds,
    required SyncService sync,
    required String ownerId,
  }) : _auth = auth,
       _profiles = profiles,
       _birds = birds,
       _sync = sync,
       _ownerId = ownerId {
    _subscribe();
  }

  final AuthRepository _auth;
  final ProfileRepository _profiles;
  final BirdsRepository _birds;
  final SyncService _sync;
  final String _ownerId;

  final List<StreamSubscription<Object?>> _subscriptions = [];

  Profile? _profile;
  int _birdCount = 0;
  int _pendingChanges = 0;
  SyncStatus _syncStatus = SyncStatus.idle;

  String? get email => _auth.currentEmail;
  SubscriptionPlan get plan => _profile?.effectivePlan ?? SubscriptionPlan.free;
  String? get farmName => _profile?.farmName;
  int get birdCount => _birdCount;
  int get pendingChanges => _pendingChanges;
  bool get hasPendingChanges => _pendingChanges > 0;
  SyncStatus get syncStatus => _syncStatus;
  bool get isSyncAvailable => _auth.isEnabled;

  Future<void> syncNow() => _sync.retryFailed();

  /// `true` si la sesión se cerró. Cierra sesión aunque queden cambios sin
  /// subir: la View debe avisarlo antes con [hasPendingChanges].
  Future<bool> signOut() async {
    setLoading();
    final result = await _auth.signOut();
    return result.fold(
      ok: (_) {
        setReady();
        return true;
      },
      err: (failure) {
        setFailure(failure);
        return false;
      },
    );
  }

  void _subscribe() {
    setLoading();
    _subscriptions
      ..add(
        _profiles.watchProfile(_ownerId).listen((profile) {
          _profile = profile;
          setReady();
        }),
      )
      ..add(
        _birds.watchCount(_ownerId).listen((count) {
          _birdCount = count;
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
