import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/weight_entry.dart';
import '../../../core/services/app_logger.dart';
import '../../authentication/providers/auth_provider.dart';
import '../repositories/weight_repository.dart';

/// State for the Weight Tracking surface of one cat.
class WeightProvider extends ChangeNotifier {
  WeightProvider._({
    required this._repository,
    required this._auth,
  }) {
    _auth.addListener(_handleAuthChange);
    _handleAuthChange();
  }

  final WeightRepository _repository;
  final AuthProvider _auth;
  StreamSubscription<List<WeightEntry>>? _sub;
  bool _disposed = false;

  List<WeightEntry> _records = const <WeightEntry>[];
  bool _loading = true;
  String? _catId;
  AppFailure? _lastError;

  /// Newest-first list.
  List<WeightEntry> get records => List<WeightEntry>.unmodifiable(_records);

  /// Oldest-first, used by trend charts.
  List<WeightEntry> get chronological =>
      _records.reversed.toList(growable: false);

  WeightEntry? get latest => _records.isEmpty ? null : _records.first;

  bool get isLoading => _loading;
  AppFailure? get lastError => _lastError;

  void bindCat(String catId) {
    if (_catId == catId) return;
    _catId = catId;
    _resubscribe();
  }

  Future<WeightEntry?> add(WeightEntry draft) async {
    final uid = _auth.profile?.uid;
    final cid = _catId;
    if (uid == null || cid == null) return null;
    WeightEntry? created;
    AppFailure? failure;
    try {
      clearError();
      final newId = await _repository.add(uid, cid, draft);
      created = draft.copyWith(id: newId);
    } on AppFailure catch (error) {
      failure = error;
      AppLogger.w('WeightProvider.add failed: $failure');
    } catch (error, stack) {
      failure = UnknownFailure(error.toString(), code: 'weight-unknown');
      AppLogger.e('WeightProvider.add unexpected', error, stack);
    }
    if (failure != null) _lastError = failure;
    if (!_disposed) notifyListeners();
    return failure == null ? created : null;
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
      AppLogger.w('WeightProvider.delete failed: $failure');
    } catch (error, stack) {
      failure = UnknownFailure(error.toString(), code: 'weight-unknown');
      AppLogger.e('WeightProvider.delete unexpected', error, stack);
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

  static WeightProvider create({
    required WeightRepository repository,
    required AuthProvider authProvider,
  }) => WeightProvider._(repository: repository, auth: authProvider);

  void _handleAuthChange() {
    final uid = _auth.profile?.uid;
    if (uid == null) {
      _sub?.cancel();
      _sub = null;
      _records = const <WeightEntry>[];
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
      _records = const <WeightEntry>[];
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
            AppLogger.e('WeightProvider: stream error', error, stack);
            _lastError = error is AppFailure
                ? error
                : UnknownFailure(error.toString(), code: 'weight-stream-error');
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
