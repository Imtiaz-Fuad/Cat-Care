import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/vaccination.dart';
import '../../../core/services/app_logger.dart';
import '../../authentication/providers/auth_provider.dart';
import '../repositories/vaccination_repository.dart';

/// State for the Vaccinations surface of one cat.
class VaccinationProvider extends ChangeNotifier {
  VaccinationProvider._({required this._repository, required this._auth}) {
    _auth.addListener(_handleAuthChange);
    _handleAuthChange();
  }

  final VaccinationRepository _repository;
  final AuthProvider _auth;
  StreamSubscription<List<Vaccination>>? _sub;
  bool _disposed = false;

  List<Vaccination> _records = const <Vaccination>[];
  bool _loading = true;
  String? _catId;
  AppFailure? _lastError;

  List<Vaccination> get records => List<Vaccination>.unmodifiable(_records);
  bool get isLoading => _loading;
  AppFailure? get lastError => _lastError;

  void bindCat(String catId) {
    if (_catId == catId) return;
    _catId = catId;
    _resubscribe();
  }

  Future<Vaccination?> add(Vaccination draft) async {
    final uid = _auth.profile?.uid;
    final cid = _catId;
    if (uid == null || cid == null) return null;
    Vaccination? created;
    AppFailure? failure;
    try {
      clearError();
      final newId = await _repository.add(uid, cid, draft);
      created = draft.copyWith(id: newId);
    } on AppFailure catch (error) {
      failure = error;
      AppLogger.w('VaccinationProvider.add failed: $failure');
    } catch (error, stack) {
      failure = UnknownFailure(error.toString(), code: 'vaccination-unknown');
      AppLogger.e('VaccinationProvider.add unexpected', error, stack);
    }
    if (failure != null) _lastError = failure;
    if (!_disposed) notifyListeners();
    return failure == null ? created : null;
  }

  Future<void> update(Vaccination record) async {
    final uid = _auth.profile?.uid;
    final cid = _catId;
    if (uid == null || cid == null) return;
    AppFailure? failure;
    try {
      clearError();
      await _repository.update(uid, cid, record);
    } on AppFailure catch (error) {
      failure = error;
      AppLogger.w('VaccinationProvider.update failed: $failure');
    } catch (error, stack) {
      failure = UnknownFailure(error.toString(), code: 'vaccination-unknown');
      AppLogger.e('VaccinationProvider.update unexpected', error, stack);
    }
    if (failure != null) _lastError = failure;
    if (!_disposed) notifyListeners();
  }

  Future<void> delete(String recordId) async {
    final uid = _auth.profile?.uid;
    final cid = _catId;
    if (uid == null || cid == null) return;
    AppFailure? failure;
    try {
      clearError();
      await _repository.delete(uid, cid, recordId);
    } on AppFailure catch (error) {
      failure = error;
      AppLogger.w('VaccinationProvider.delete failed: $failure');
    } catch (error, stack) {
      failure = UnknownFailure(error.toString(), code: 'vaccination-unknown');
      AppLogger.e('VaccinationProvider.delete unexpected', error, stack);
    }
    if (failure != null) _lastError = failure;
    if (!_disposed) notifyListeners();
  }

  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    notifyListeners();
  }

  void retry() {
    _lastError = null;
    _resubscribe();
  }

  static VaccinationProvider create({
    required VaccinationRepository repository,
    required AuthProvider authProvider,
  }) => VaccinationProvider._(repository: repository, auth: authProvider);

  void _handleAuthChange() {
    final uid = _auth.profile?.uid;
    if (uid == null) {
      _sub?.cancel();
      _sub = null;
      _records = const <Vaccination>[];
      _loading = false;
      notifyListeners();
      return;
    }
    if (_catId != null) _resubscribe();
  }

  void _resubscribe() {
    final uid = _auth.profile?.uid;
    final cid = _catId;
    _sub?.cancel();
    _sub = null;
    if (uid == null || cid == null) {
      _records = const <Vaccination>[];
      _loading = false;
      notifyListeners();
      return;
    }
    _loading = true;
    _lastError = null;
    notifyListeners();
    _sub = _repository
        .watchForCat(uid, cid)
        .listen(
          (next) {
            _records = next;
            _loading = false;
            notifyListeners();
          },
          onError: (Object error, StackTrace stack) {
            AppLogger.e('VaccinationProvider: stream error', error, stack);
            _lastError = error is AppFailure
                ? error
                : UnknownFailure(
                    error.toString(),
                    code: 'vaccination-stream-error',
                  );
            _loading = false;
            notifyListeners();
          },
        );
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _auth.removeListener(_handleAuthChange);
    super.dispose();
  }
}
