import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/cat_profile.dart';
import '../../../core/services/app_logger.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../cats/providers/cat_provider.dart';
import '../repositories/ai_repository.dart';
import '../utils/cat_summary_builder.dart';

/// `ChangeNotifier` for every AI feature surface. Screens subscribe
/// to a single provider per app and pick the field they need
/// (`chatHistory`, `weeklyReport`, `foodLabel`). The provider keeps
/// `isBusy` flags per surface so one slow call never blocks another
/// (e.g. the weekly report can render while a chat send is in flight).
///
/// Quota errors are not thrown — they are stored in the typed
/// `lastError` field so the UI can render a friendly "limit
/// finished" card. The user can dismiss with [clearError].
class AiProvider extends ChangeNotifier {
  AiProvider({
    required AiRepository repository,
    required CatSummaryBuilder summaryBuilder,
    required AuthProvider authProvider,
    required CatProvider catProvider,
  }) : _repository = repository, // ignore: prefer_initializing_formals
       _summaryBuilder = summaryBuilder, // ignore: prefer_initializing_formals
       _authProvider = authProvider, // ignore: prefer_initializing_formals
       _catProvider = catProvider; // ignore: prefer_initializing_formals

  final AiRepository _repository;
  final CatSummaryBuilder _summaryBuilder;
  final AuthProvider _authProvider;
  final CatProvider _catProvider;

  // ---------------------------------------------------------------------------
  // Chat state
  // ---------------------------------------------------------------------------

  /// In-memory chat history for the active session. The Cloud
  /// Function persists nothing client-side — if the user closes the
  /// app the history is intentionally discarded so the model does
  /// not silently accumulate old turns beyond the rolling window.
  final List<ChatTurn> _chatHistory = <ChatTurn>[];

  /// Read-only view for the UI.
  List<ChatTurn> get chatHistory => List<ChatTurn>.unmodifiable(_chatHistory);

  bool _chatBusy = false;
  bool get chatBusy => _chatBusy;

  /// Send [userMessage] for [catId], append both the user turn and
  /// the model reply to the chat history, and return the reply text.
  /// On failure, [lastError] is set and the user turn is rolled back
  /// so the UI does not show a half-finished conversation.
  Future<String?> sendChatMessage({
    required String catId,
    required String userMessage,
    String locale = 'en',
  }) async {
    if (catId.isEmpty) {
      _lastError = const ValidationFailure(
        'Select an active cat before chatting with the assistant.',
        code: 'ai-no-active-cat',
      );
      notifyListeners();
      return null;
    }
    final String trimmed = userMessage.trim();
    if (trimmed.isEmpty) return null;

    final ChatTurn userTurn = ChatTurn(role: 'user', text: trimmed);
    _chatHistory.add(userTurn);
    _setChatBusy(true);
    clearError();
    try {
      final CatProfile cat = _requireCat(catId);
      final summary = await _summaryBuilder.build(
        ownerId: _requireOwnerId(),
        catId: catId,
      );
      final ChatReply reply = await _repository.chat(
        userMessage: trimmed,
        cat: cat,
        summary: summary,
        locale: locale,
        history: _chatHistory.sublist(0, _chatHistory.length - 1),
      );
      _chatHistory.add(ChatTurn(role: 'model', text: reply.text));
      AppLogger.i('AiProvider.sendChatMessage ok (${reply.text.length} chars)');
      return reply.text;
    } on AppFailure catch (f) {
      // Roll back the optimistic user turn so the conversation does
      // not appear to hang with no reply.
      _chatHistory.removeLast();
      _lastError = f;
      AppLogger.w('AiProvider.sendChatMessage failed: $f');
      return null;
    } finally {
      _setChatBusy(false);
    }
  }

  void clearChat() {
    if (_chatHistory.isEmpty) return;
    _chatHistory.clear();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Weekly report state
  // ---------------------------------------------------------------------------

  WeeklyReportResult? _weeklyReport;
  WeeklyReportResult? get weeklyReport => _weeklyReport;

  bool _weeklyBusy = false;
  bool get weeklyBusy => _weeklyBusy;

  /// Generate or fetch the cached weekly narrative. `force: true`
  /// bypasses the cache (the Cloud Function writes the new value
  /// back to `weeklyReports/{weekId}` regardless).
  Future<void> loadWeeklyReport({
    required String catId,
    required String weekId,
    bool force = false,
    String locale = 'en',
  }) async {
    if (catId.isEmpty) {
      _lastError = const ValidationFailure(
        'Select an active cat to generate a weekly report.',
        code: 'ai-no-active-cat',
      );
      notifyListeners();
      return;
    }
    _setWeeklyBusy(true);
    clearError();
    try {
      final CatProfile cat = _requireCat(catId);
      final summary = await _summaryBuilder.build(
        ownerId: _requireOwnerId(),
        catId: catId,
      );
      final WeeklyReportResult result = await _repository.weeklyReport(
        cat: cat,
        summary: summary,
        weekId: weekId,
        force: force,
        locale: locale,
      );
      _weeklyReport = result;
      AppLogger.i(
        'AiProvider.loadWeeklyReport ok (fromCache=${result.fromCache}, '
        'noData=${result.noData})',
      );
    } on AppFailure catch (f) {
      _lastError = f;
      AppLogger.w('AiProvider.loadWeeklyReport failed: $f');
    } finally {
      _setWeeklyBusy(false);
    }
  }

  // ---------------------------------------------------------------------------
  // Food label state
  // ---------------------------------------------------------------------------

  FoodLabelExtraction? _foodLabel;
  FoodLabelExtraction? get foodLabel => _foodLabel;

  bool _foodLabelBusy = false;
  bool get foodLabelBusy => _foodLabelBusy;

  /// Send a base64-encoded photo of a cat-food label and store the
  /// extracted JSON. Returns the extraction or null on failure.
  Future<FoodLabelExtraction?> extractFoodLabel({
    required String imageBase64,
    required String mimeType,
    String locale = 'en',
  }) async {
    _setFoodLabelBusy(true);
    clearError();
    try {
      final FoodLabelExtraction result = await _repository.extractFoodLabel(
        imageBase64: imageBase64,
        mimeType: mimeType,
        locale: locale,
      );
      _foodLabel = result;
      AppLogger.i(
        'AiProvider.extractFoodLabel ok '
        '(missingData=${result.missingData})',
      );
      return result;
    } on AppFailure catch (f) {
      _lastError = f;
      AppLogger.w('AiProvider.extractFoodLabel failed: $f');
      return null;
    } finally {
      _setFoodLabelBusy(false);
    }
  }

  void clearFoodLabel() {
    if (_foodLabel == null) return;
    _foodLabel = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Shared error + busy
  // ---------------------------------------------------------------------------

  AppFailure? _lastError;
  AppFailure? get lastError => _lastError;

  /// True iff [lastError] is a quota-exhaustion failure. The UI uses
  /// this to render the user-friendly "limit finished" card without
  /// the user having to parse the failure code.
  bool get isQuotaLimited => _lastError is AiQuotaExceededFailure;

  /// True while the AI surfaces should accept user input. Becomes
  /// false the moment a quota error is observed and stays false
  /// until [clearError] (or [reset]) is called. The chat composer,
  /// weekly-report regenerate button, and food-label pickers all
  /// bind to this flag so the user is not invited to send a
  /// request that will be silently rejected by the on-device rate
  /// limiter.
  bool get aiAvailable => _lastError is! AiQuotaExceededFailure;

  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    notifyListeners();
  }

  /// Reset all AI state — chat history, weekly report, food label,
  /// and the latest error. Call this on sign-out so the next user
  /// does not inherit the previous session.
  void reset() {
    _chatHistory.clear();
    _weeklyReport = null;
    _foodLabel = null;
    _lastError = null;
    _chatBusy = false;
    _weeklyBusy = false;
    _foodLabelBusy = false;
    notifyListeners();
    // Best-effort cache wipe. If the clear fails the next user just
    // sees a stale weekly report until they refresh.
    // ignore: discarded_futures
    _repository.clearWeeklyReportCache();
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  void _setChatBusy(bool value) {
    if (_chatBusy == value) return;
    _chatBusy = value;
    notifyListeners();
  }

  void _setWeeklyBusy(bool value) {
    if (_weeklyBusy == value) return;
    _weeklyBusy = value;
    notifyListeners();
  }

  void _setFoodLabelBusy(bool value) {
    if (_foodLabelBusy == value) return;
    _foodLabelBusy = value;
    notifyListeners();
  }

  /// Resolve the active cat profile for [catId]. Throws a typed
  /// [ValidationFailure] when no cat matches — the UI surfaces that
  /// as the friendly "select an active cat" toast.
  CatProfile _requireCat(String catId) {
    for (final CatProfile c in _catProvider.cats) {
      if (c.id == catId) return c;
    }
    throw const ValidationFailure(
      'The selected cat is no longer available. Please pick another.',
      code: 'ai-cat-missing',
    );
  }

  /// The signed-in user id is the Firestore owner id used by every
  /// summary query. Surfaced as a typed failure so the screen can
  /// show "please sign in" instead of letting an empty string ripple
  /// through the summaries.
  String _requireOwnerId() {
    final String uid = _authProvider.profile?.uid ?? '';
    if (uid.isEmpty) {
      throw const ValidationFailure(
        'You must be signed in to use the AI assistant.',
        code: 'ai-not-signed-in',
      );
    }
    return uid;
  }
}
