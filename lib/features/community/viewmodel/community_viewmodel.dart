import '../../../core/base/base_viewmodel.dart';
import '../model/community.dart';
import '../repository/community_repository.dart';

/// Qué se está mirando en Comunidad.
enum CommunityTab { directory, requests }

/// Comunidad — `RF-COM`.
///
/// A diferencia del resto del producto no observa Drift: Comunidad exige
/// conexión (`RNF-08`) y se lee de una vez, con recarga manual. Un stream de
/// datos que solo existen en el servidor daría la impresión de estar al día
/// cuando lo que hay es una foto de hace rato.
class CommunityViewModel extends BaseViewModel {
  CommunityViewModel({required CommunityRepository repository, required String ownerId})
    : _repository = repository,
      _ownerId = ownerId;

  final CommunityRepository _repository;
  final String _ownerId;

  CommunityTab _tab = CommunityTab.directory;
  List<PublicProfile> _directory = const [];
  List<MeetingRequest> _requests = const [];
  String _query = '';

  CommunityTab get tab => _tab;
  List<PublicProfile> get directory => _directory;
  String get query => _query;

  /// Recibidas y todavía sin responder: son las que piden algo del criador.
  List<MeetingRequest> get incoming => [
    for (final request in _requests)
      if (request.isIncomingFor(_ownerId)) request,
  ];

  List<MeetingRequest> get outgoing => [
    for (final request in _requests)
      if (!request.isIncomingFor(_ownerId)) request,
  ];

  /// Cuántas esperan respuesta. Es lo que lleva la insignia de la pestaña: sin
  /// ella, una solicitud puede quedarse días sin que nadie la vea.
  int get pendingCount => incoming.where((r) => r.status.isOpen).length;

  bool get isEmpty => _tab == CommunityTab.directory ? _directory.isEmpty : _requests.isEmpty;

  Future<void> load() async {
    setLoading();
    await Future.wait([_loadDirectory(), _loadRequests()]);
    if (!hasError) setReady();
  }

  void setTab(CommunityTab value) {
    if (_tab == value) return;
    _tab = value;
    safeNotify();
  }

  Future<void> search(String value) async {
    _query = value;
    await _loadDirectory();
    safeNotify();
  }

  Future<bool> respond(MeetingRequest request, MeetingStatus status) async {
    final result = await _repository.respond(ownerId: _ownerId, request: request, status: status);

    return result.fold(
      ok: (_) async {
        await _loadRequests();
        safeNotify();
        return true;
      },
      err: (failure) {
        setFailure(failure);
        return false;
      },
    );
  }

  Future<bool> block(String otherId) async {
    final result = await _repository.block(ownerId: _ownerId, blockedId: otherId);
    return result.fold(
      ok: (_) async {
        await _loadDirectory();
        safeNotify();
        return true;
      },
      err: (failure) {
        setFailure(failure);
        return false;
      },
    );
  }

  Future<bool> report(String otherId, {String? reason}) async {
    final result = await _repository.report(ownerId: _ownerId, reportedId: otherId, reason: reason);
    return result.fold(
      ok: (_) => true,
      err: (failure) {
        setFailure(failure);
        return false;
      },
    );
  }

  Future<void> _loadDirectory() async {
    final result = await _repository.directory(ownerId: _ownerId, query: _query);
    result.fold(ok: (profiles) => _directory = profiles, err: setFailure);
  }

  Future<void> _loadRequests() async {
    final result = await _repository.requests(_ownerId);
    result.fold(ok: (requests) => _requests = requests, err: setFailure);
  }
}
