import '../../../core/base/base_viewmodel.dart';
import '../model/community.dart';
import '../repository/community_repository.dart';

/// Redactar una solicitud de encuentro — `RF-COM`.
class MeetingRequestViewModel extends BaseViewModel {
  MeetingRequestViewModel({
    required CommunityRepository repository,
    required String ownerId,
    required String toOwner,
    DateTime Function() clock = DateTime.now,
  }) : _repository = repository,
       _ownerId = ownerId,
       _toOwner = toOwner,
       _clock = clock;

  final CommunityRepository _repository;
  final String _ownerId;
  final String _toOwner;
  final DateTime Function() _clock;

  String? _birdId;
  String _message = '';
  String _place = '';
  DateTime? _date;

  String? get birdId => _birdId;
  String get place => _place;
  DateTime? get date => _date;

  /// El mensaje es lo único que de verdad hace falta: proponer un encuentro sin
  /// decir nada es un mensaje en blanco que el otro criadero no sabrá responder.
  bool get canSubmit => _message.trim().isNotEmpty && !isLoading;

  void setBird(String? value) {
    _birdId = value;
    safeNotify();
  }

  void setMessage(String value) {
    _message = value;
    safeNotify();
  }

  void setPlace(String value) => _place = value;

  void setDate(DateTime? value) {
    _date = value;
    safeNotify();
  }

  Future<MeetingRequest?> submit() async {
    if (!canSubmit) return null;

    setLoading();
    final result = await _repository.send(
      ownerId: _ownerId,
      toOwner: _toOwner,
      fromBirdId: _birdId,
      message: _message,
      place: _place,
      proposedDate: _date,
    );

    return result.fold(
      ok: (request) {
        setReady();
        return request;
      },
      err: (failure) {
        setFailure(failure);
        return null;
      },
    );
  }

  DateTime get today {
    final now = _clock();
    return DateTime(now.year, now.month, now.day);
  }
}
