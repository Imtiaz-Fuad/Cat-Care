import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/behavior_log.dart';
import '../../../core/services/app_logger.dart';
import '../../authentication/providers/auth_provider.dart';
import '../repositories/behavior_repository.dart';

/// State for the Behavior Logs surface of one cat.
class BehaviorProvider extends ChangeNotifier {
  BehaviorProvider._({
    required this._repository,
    required this._auth,
  }) {
    _auth.addListener(_handleAuthChange);
    _handleAuthChange();
  }

  final BehaviorRepository _repository;
  final AuthProvider _auth;
  StreamSubscription<List<BehaviorLog>>? _sub;
  bool _disposed = false;

  List<BehaviorLog> _records = const <BehaviorLog>[];
  bool _loading = true;
  String? _catId;
  AppFailure? _lastError;

  List<BehaviorLog> get records => List<BehaviorLog>.unmodifiable(_records);
  bool get isLoading => _loading;
  AppFailure? get lastError => _lastError;

  void bindCat(String catId) {
    if (_catId == catId) return;
    _catId = catId;
    _resubscribe();
  }

  Future<BehaviorLog?> add(BehaviorLog draft) async {
    final uid = _auth.profile?.uid;
    final cid = _catId;
    if (uid == null || cid == null) return null;
    BehaviorLog? created;
    AppFailure? failure;
    try {
      clearError();
      final newId = await _repository.add(uid, cid, draft);
      created = draft.copyWith(id: newId);
    } on AppFailure catch (error) {
      failure = error;
      AppLogger.w('BehaviorProvider.add failed: $failure');
    } catch (error, stack) {
      failure = UnknownFailure(error.toString(), code: 'behavior-unknown');
      AppLogger.e('BehaviorProvider.add unexpected', error, stack);
    }
    if (failure != null) _lastError = failure;
    if (!_disposed) notifyListeners();
    return failure == null ? created : null;
  }

  Future<void> update(BehaviorLog record) async {
    final uid = _auth.profile?.uid;
    final cid = _catId;
    if (uid == null || cid == null) return;
    AppFailure? failure;
    try {
      clearError();
      await _repository.update(uid, cid, record);
    } on AppFailure catch (error) {
      failure = error;
      AppLogger.w('BehaviorProvider.update failed: $failure');
    } catch (error, stack) {
      failure = UnknownFailure(error.toString(), code: 'behavior-unknown');
      AppLogger.e('BehaviorProvider.update unexpected', error, stack);
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
      AppLogger.w('BehaviorProvider.delete failed: $failure');
    } catch (error, stack) {
      failure = UnknownFailure(error.toString(), code: 'behavior-unknown');
      AppLogger.e('BehaviorProvider.delete unexpected', error, stack);
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

  static BehaviorProvider create({
    required BehaviorRepository repository,
    required AuthProvider authProvider,
  }) => BehaviorProvider._(repository: repository, auth: authProvider);

  void _handleAuthChange() {
    final uid = _auth.profile?.uid;
    if (uid == null) {
      _sub?.cancel();
      _sub = null;
      _records = const <BehaviorLog>[];
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
      _records = const <BehaviorLog>[];
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
            AppLogger.e('BehaviorProvider: stream error', error, stack);
            _lastError = error is AppFailure
                ? error
                : UnknownFailure(
                    error.toString(),
                    code: 'behavior-stream-error',
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
