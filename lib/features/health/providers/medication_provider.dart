import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/medication.dart';
import '../../../core/services/app_logger.dart';
import '../../authentication/providers/auth_provider.dart';
import '../repositories/medication_repository.dart';

/// State for the Medications surface of one cat.
///
/// In addition to the full list, [active] exposes only medications whose
/// [startDate, endDate] range covers "today" — used by the Routine screen
/// to render the daily-check-off card.
class MedicationProvider extends ChangeNotifier {
  MedicationProvider._({
    required this._repository,
    required this._auth,
  }) {
    _auth.addListener(_handleAuthChange);
    _handleAuthChange();
  }

  final MedicationRepository _repository;
  final AuthProvider _auth;
  StreamSubscription<List<Medication>>? _sub;
  bool _disposed = false;

  List<Medication> _records = const <Medication>[];
  bool _loading = true;
  String? _catId;
  AppFailure? _lastError;

  List<Medication> get records => List<Medication>.unmodifiable(_records);
  List<Medication> get active =>
      _records.where((m) => m.isActiveOn(DateTime.now())).toList();
  bool get isLoading => _loading;
  AppFailure? get lastError => _lastError;

  void bindCat(String catId) {
    if (_catId == catId) return;
    _catId = catId;
    _resubscribe();
  }

  Future<Medication?> add(Medication draft) async {
    final uid = _auth.profile?.uid;
    final cid = _catId;
    if (uid == null || cid == null) return null;
    Medication? created;
    AppFailure? failure;
    try {
      clearError();
      final newId = await _repository.add(uid, cid, draft);
      created = draft.copyWith(id: newId);
    } on AppFailure catch (error) {
      failure = error;
      AppLogger.w('MedicationProvider.add failed: $failure');
    } catch (error, stack) {
      failure = UnknownFailure(error.toString(), code: 'medication-unknown');
      AppLogger.e('MedicationProvider.add unexpected', error, stack);
    }
    if (failure != null) _lastError = failure;
    if (!_disposed) notifyListeners();
    return failure == null ? created : null;
  }

  Future<void> update(Medication record) async {
    final uid = _auth.profile?.uid;
    final cid = _catId;
    if (uid == null || cid == null) return;
    AppFailure? failure;
    try {
      clearError();
      await _repository.update(uid, cid, record);
    } on AppFailure catch (error) {
      failure = error;
      AppLogger.w('MedicationProvider.update failed: $failure');
    } catch (error, stack) {
      failure = UnknownFailure(error.toString(), code: 'medication-unknown');
      AppLogger.e('MedicationProvider.update unexpected', error, stack);
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
      AppLogger.w('MedicationProvider.delete failed: $failure');
    } catch (error, stack) {
      failure = UnknownFailure(error.toString(), code: 'medication-unknown');
      AppLogger.e('MedicationProvider.delete unexpected', error, stack);
    }
    if (failure != null) _lastError = failure;
    if (!_disposed) notifyListeners();
  }

  /// Toggles today's check-off for [medication]. Returns the updated
  /// medication, or `null` if the update failed.
  Future<Medication?> toggleToday(Medication medication) async {
    final next = medication.toggleCheckOff(DateTime.now());
    await update(next);
    return next;
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

  static MedicationProvider create({
    required MedicationRepository repository,
    required AuthProvider authProvider,
  }) =>
      MedicationProvider._(repository: repository, auth: authProvider);

  void _handleAuthChange() {
    final uid = _auth.profile?.uid;
    if (uid == null) {
      _sub?.cancel();
      _sub = null;
      _records = const <Medication>[];
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
      _records = const <Medication>[];
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
            AppLogger.e('MedicationProvider: stream error', error, stack);
            _lastError = error is AppFailure
                ? error
                : UnknownFailure(
                    error.toString(),
                    code: 'medication-stream-error',
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
