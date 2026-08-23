import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/health_record.dart';
import '../../../core/services/app_logger.dart';
import '../../authentication/providers/auth_provider.dart';
import '../repositories/health_repository.dart';

/// State for the Health Records surface of one cat.
///
/// Mirrors the convention used by [CatProvider]: the provider listens
/// to [AuthProvider] for user-id changes, swaps its repository stream
/// when the signed-in user changes, and exposes an `error` + `retry()`
/// pair so the UI's error banner always has a working action.
class HealthProvider extends ChangeNotifier {
  HealthProvider._({
    required HealthRepository repository,
    required AuthProvider authProvider,
  })  : _repository = repository,
        _auth = authProvider {
    _auth.addListener(_handleAuthChange);
    _handleAuthChange();
  }

  final HealthRepository _repository;
  final AuthProvider _auth;

  StreamSubscription<List<HealthRecord>>? _sub;
  bool _disposed = false;

  List<HealthRecord> _records = const <HealthRecord>[];
  bool _loading = true;
  String? _catId;
  AppFailure? _lastError;

  // ---------------------------------------------------------------------------
  // Public surface
  // ---------------------------------------------------------------------------

  List<HealthRecord> get records => List<HealthRecord>.unmodifiable(_records);
  bool get isLoading => _loading;
  AppFailure? get lastError => _lastError;
  String? get catId => _catId;

  void bindCat(String catId) {
    if (_catId == catId) return;
    _catId = catId;
    _resubscribe();
  }

  Future<HealthRecord?> add(HealthRecord draft) async {
    final String? uid = _auth.profile?.uid;
    final String? cid = _catId;
    if (uid == null || cid == null) return null;
    HealthRecord? created;
    AppFailure? failure;
    try {
      clearError();
      final newId = await _repository.add(uid, cid, draft);
      created = draft.copyWith(id: newId);
    } on AppFailure catch (error) {
      failure = error;
      AppLogger.w('HealthProvider.add failed: $failure');
    } catch (error, stack) {
      failure = UnknownFailure(error.toString(), code: 'health-unknown');
      AppLogger.e('HealthProvider.add unexpected', error, stack);
    }
    if (failure != null) _lastError = failure;
    if (!_disposed) notifyListeners();
    return failure == null ? created : null;
  }

  Future<void> update(HealthRecord record) async {
    final String? uid = _auth.profile?.uid;
    final String? cid = _catId;
    if (uid == null || cid == null) return;
    AppFailure? failure;
    try {
      clearError();
      await _repository.update(uid, cid, record);
    } on AppFailure catch (error) {
      failure = error;
      AppLogger.w('HealthProvider.update failed: $failure');
    } catch (error, stack) {
      failure = UnknownFailure(error.toString(), code: 'health-unknown');
      AppLogger.e('HealthProvider.update unexpected', error, stack);
    }
    if (failure != null) _lastError = failure;
    if (!_disposed) notifyListeners();
  }

  Future<void> delete(String recordId) async {
    final String? uid = _auth.profile?.uid;
    final String? cid = _catId;
    if (uid == null || cid == null) return;
    AppFailure? failure;
    try {
      clearError();
      await _repository.delete(uid, cid, recordId);
    } on AppFailure catch (error) {
      failure = error;
      AppLogger.w('HealthProvider.delete failed: $failure');
    } catch (error, stack) {
      failure = UnknownFailure(error.toString(), code: 'health-unknown');
      AppLogger.e('HealthProvider.delete unexpected', error, stack);
    }
    if (failure != null) _lastError = failure;
    if (!_disposed) notifyListeners();
  }

  Future<String?> uploadAttachment({
    required String recordId,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final String? uid = _auth.profile?.uid;
    final String? cid = _catId;
    if (uid == null || cid == null) return null;
    String? url;
    AppFailure? failure;
    try {
      clearError();
      url = await _repository.uploadAttachment(
        userId: uid,
        catId: cid,
        recordId: recordId,
        fileName: fileName,
        bytes: bytes,
        contentType: contentType,
      );
    } on AppFailure catch (error) {
      failure = error;
      AppLogger.w('HealthProvider.uploadAttachment failed: $failure');
    } catch (error, stack) {
      failure = UnknownFailure(error.toString(), code: 'health-upload-unknown');
      AppLogger.e('HealthProvider.uploadAttachment unexpected', error, stack);
    }
    if (failure != null) _lastError = failure;
    if (!_disposed) notifyListeners();
    return failure == null ? url : null;
  }

  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    notifyListeners();
  }

  /// Re-runs the current subscription. Wired to the UI's "retry" button.
  void retry() {
    AppLogger.i('HealthProvider.retry');
    _lastError = null;
    _resubscribe();
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  static HealthProvider create({
    required HealthRepository repository,
    required AuthProvider authProvider,
  }) =>
      HealthProvider._(
        repository: repository,
        authProvider: authProvider,
      );

  void _handleAuthChange() {
    final String? uid = _auth.profile?.uid;
    if (uid == null) {
      _sub?.cancel();
      _sub = null;
      _records = const <HealthRecord>[];
      _loading = false;
      notifyListeners();
      return;
    }
    if (_catId != null) {
      _resubscribe();
    }
  }

  void _resubscribe() {
    final String? uid = _auth.profile?.uid;
    final String? cid = _catId;
    _sub?.cancel();
    _sub = null;
    if (uid == null || cid == null) {
      _records = const <HealthRecord>[];
      _loading = false;
      notifyListeners();
      return;
    }
    _loading = true;
    _lastError = null;
    notifyListeners();
    _sub = _repository.watchForCat(uid, cid).listen(
      (next) {
        _records = next;
        _loading = false;
        notifyListeners();
      },
      onError: (Object error, StackTrace stack) {
        AppLogger.e('HealthProvider: stream error', error, stack);
        _lastError = error is AppFailure
            ? error
            : UnknownFailure(error.toString(), code: 'health-stream-error');
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
