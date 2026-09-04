import 'dart:async';

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/cat_profile.dart';
import '../../../core/models/behavior_log.dart';
import '../../../core/models/health_record.dart';
import '../../../core/models/medication.dart';
import '../../../core/models/vaccination.dart';
import '../../../core/models/routine_task.dart';
import '../../../core/services/app_logger.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../cats/providers/cat_provider.dart';
import '../../health/providers/behavior_provider.dart';
import '../../health/providers/health_provider.dart';
import '../../health/providers/medication_provider.dart';
import '../../health/providers/vaccination_provider.dart';
import '../../routine/providers/routine_provider.dart';
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
    MedicationProvider? medicationProvider,
    VaccinationProvider? vaccinationProvider,
    BehaviorProvider? behaviorProvider,
    HealthProvider? healthProvider,
    RoutineProvider? routineProvider,
    SharedPreferences? preferences,
  }) : _repository = repository, // ignore: prefer_initializing_formals
       _summaryBuilder = summaryBuilder, // ignore: prefer_initializing_formals
       _authProvider = authProvider, // ignore: prefer_initializing_formals
       _catProvider = catProvider, // ignore: prefer_initializing_formals
       _medicationProvider = medicationProvider,
       _vaccinationProvider = vaccinationProvider,
       _behaviorProvider = behaviorProvider,
       _healthProvider = healthProvider,
       _routineProvider = routineProvider,
       _preferences = preferences;

  final AiRepository _repository;
  final CatSummaryBuilder _summaryBuilder;
  final AuthProvider _authProvider;
  final CatProvider _catProvider;
  final MedicationProvider? _medicationProvider;
  final VaccinationProvider? _vaccinationProvider;
  final BehaviorProvider? _behaviorProvider;
  final HealthProvider? _healthProvider;
  final RoutineProvider? _routineProvider;
  final SharedPreferences? _preferences;
  String? _loadedHistoryKey;
  bool _historyLoading = false;

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

    await loadChatHistory(catId);
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
      final String additionalContext = _careContext(catId);
      final ChatReply reply = await _repository.chat(
        userMessage: trimmed,
        cat: cat,
        summary: summary,
        additionalContext: additionalContext,
        locale: locale,
        history: _chatHistory.sublist(0, _chatHistory.length - 1),
      );
      _chatHistory.add(ChatTurn(role: 'model', text: reply.text));
      await _persistChatHistory(catId);
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
    final String? key = _loadedHistoryKey;
    if (key != null) {
      // ignore: discarded_futures
      _preferences?.remove(key);
    }
    notifyListeners();
  }

  Future<void> loadChatHistory(String catId) async {
    final String key = _historyKey(catId);
    if (_loadedHistoryKey == key || _historyLoading) return;
    _historyLoading = true;
    try {
      final String? raw = _preferences?.getString(key);
      _chatHistory.clear();
      if (raw != null && raw.isNotEmpty) {
        final dynamic decoded = jsonDecode(raw);
        if (decoded is List) {
          _chatHistory.addAll(
            decoded.whereType<Map>().map((item) => ChatTurn(
                  role: item['role'] == 'model' ? 'model' : 'user',
                  text: item['text'] is String ? item['text'] as String : '',
                )).where((turn) => turn.text.isNotEmpty).take(40),
          );
        }
      }
      _loadedHistoryKey = key;
      notifyListeners();
    } catch (_) {
      _chatHistory.clear();
      _loadedHistoryKey = key;
    } finally {
      _historyLoading = false;
    }
  }

  String _historyKey(String catId) =>
      'ai.chat.${_authProvider.profile?.uid ?? 'unknown'}.$catId';

  Future<void> _persistChatHistory(String catId) async {
    final SharedPreferences? prefs = _preferences;
    if (prefs == null) return;
    final List<ChatTurn> bounded = _chatHistory.length <= 40
        ? _chatHistory
        : _chatHistory.sublist(_chatHistory.length - 40);
    await prefs.setString(
      _historyKey(catId),
      jsonEncode(bounded.map((turn) => <String, String>{
            'role': turn.role,
            'text': turn.text,
          }).toList()),
    );
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
      final String additionalContext = _careContext(catId);
      final WeeklyReportResult result = await _repository.weeklyReport(
        cat: cat,
        summary: summary,
        additionalContext: additionalContext,
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
    _loadedHistoryKey = null;
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

  String _careContext(String catId) {
    String date(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final List<String> lines = <String>[];
    final meds = (_medicationProvider?.records ?? const <Medication>[]).where((m) => m.catId == catId).take(8);
    final vaccines = (_vaccinationProvider?.records ?? const <Vaccination>[]).where((v) => v.catId == catId).take(8);
    final behavior = (_behaviorProvider?.records ?? const <BehaviorLog>[]).where((b) => b.catId == catId).take(8);
    final health = (_healthProvider?.records ?? const <HealthRecord>[]).where((h) => h.catId == catId).take(6);
    final RoutineProvider? routineProvider = _routineProvider;
    final routines = (routineProvider?.todaysRoutines ?? const <RoutineTask>[]).take(12);
    lines.add('Medications: ${meds.isEmpty ? 'none recorded' : meds.map((m) => '${m.name} (${m.dose}, ${m.frequency}, ${m.active ? 'active' : 'inactive'}${m.notes == null ? '' : ', note: ${m.notes}'})').join('; ')}');
    lines.add('Vaccinations: ${vaccines.isEmpty ? 'none recorded' : vaccines.map((v) => '${v.vaccineCode} on ${date(v.administeredAt)}${v.nextDue == null ? '' : ', next due ${date(v.nextDue!)}'}${v.vetName == null ? '' : ', vet: ${v.vetName}'}${v.notes == null ? '' : ', note: ${v.notes}'}').join('; ')}');
    lines.add('Behavior observations: ${behavior.isEmpty ? 'none recorded' : behavior.map((b) => '${date(b.recordedAt)} appetite=${b.appetite ?? 'n/a'}, activity=${b.activity ?? 'n/a'}, mood=${b.mood ?? 'n/a'}, sleep=${b.sleepHours ?? 'n/a'}h, vomiting=${b.vomitingPresent ?? 'n/a'}, diarrhea=${b.diarrheaPresent ?? 'n/a'}, urination=${b.urinationNormal ?? 'n/a'}, litter=${b.litterNormal ?? 'n/a'}, aggression=${b.aggressionPresent ?? 'n/a'}, hiding=${b.hidingPresent ?? 'n/a'}${b.notes == null ? '' : ', note: ${b.notes}'}').join('; ')}');
    lines.add('Routines: ${routines.isEmpty ? 'none recorded' : routines.map((r) => '${r.title} (${r.category}, ${routineProvider?.isCompletedToday(r) == true ? 'completed today' : 'not completed today'})').join('; ')}');
    lines.add('Health records: ${health.isEmpty ? 'none recorded' : health.map((h) => '${date(h.recordedAt)} ${h.title}${h.vetName == null ? '' : ', vet: ${h.vetName}'}${h.diagnosis == null ? '' : ', diagnosis: ${h.diagnosis}'}${h.prescription == null ? '' : ', prescription: ${h.prescription}'}${h.medicines.isEmpty ? '' : ', medicines: ${h.medicines.join(', ')}'}${h.vaccines.isEmpty ? '' : ', vaccines: ${h.vaccines.join(', ')}'}${h.tests.isEmpty ? '' : ', tests: ${h.tests.join(', ')}'}${h.notes == null ? '' : ', note: ${h.notes}'}').join('; ')}');
    return 'Additional care records (use only as recorded facts; do not invent trends):\n${lines.join('\n')}';
  }
}
