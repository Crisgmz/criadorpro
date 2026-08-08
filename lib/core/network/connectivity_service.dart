import 'package:connectivity_plus/connectivity_plus.dart';

/// Estado de red reducido a lo único que le importa a la app: hay salida o no.
///
/// Ojo: tener interfaz no garantiza que el backend responda. El sistema de
/// sincronización trata igual un fallo de red que una desconexión.
class ConnectivityService {
  ConnectivityService([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  Future<bool> isOnline() async => _hasConnection(await _connectivity.checkConnectivity());

  Stream<bool> get onStatusChange =>
      _connectivity.onConnectivityChanged.map(_hasConnection).distinct();

  static bool _hasConnection(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}
