import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/empty_state.dart';
import '../../cats/providers/cat_provider.dart';
import '../providers/ai_provider.dart';
import '../repositories/ai_repository.dart';
import '../widgets/ai_guardrail_banner.dart';

/// Conversational AI assistant for the active cat. See
/// `docs/architecture.md` § "AI Architecture (Future)":
///
///   * All work happens via the Cloud Function `chatAssistant`
///     (region: asia-south1). The function merges the cat summary,
///     locale, and history before calling Gemini.
///   * This screen only renders state from [AiProvider] and pushes
///     new turns into it; the repository is never referenced here.
///   * Quota exhaustion renders [AiQuotaBanner] in place of the
///     error string so the user sees "limit finished" instead of a
///     raw SDK exception.
class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();
  String _locale = 'en';

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<CatProvider, AiProvider>(
      builder:
          (
            BuildContext context,
            CatProvider catProvider,
            AiProvider aiProvider,
            Widget? _,
          ) {
            final String? catId = catProvider.activeCatId;
            return Scaffold(
              appBar: AppBar(
                title: const Text('AI Assistant'),
                actions: <Widget>[
                  IconButton(
                    tooltip: 'Clear conversation',
                    icon: const Icon(Icons.delete_sweep_outlined),
                    onPressed: aiProvider.chatHistory.isEmpty
                        ? null
                        : () => aiProvider.clearChat(),
                  ),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(56),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: AiLanguageToggle(
                            value: _locale,
                            onChanged: (String v) =>
                                setState(() => _locale = v),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              body: catId == null
                  ? const _NoActiveCat()
                  : _ChatBody(
                      catId: catId,
                      aiProvider: aiProvider,
                      composer: _composer,
                      scroll: _scroll,
                      locale: _locale,
                    ),
            );
          },
    );
  }
}

class _ChatBody extends StatelessWidget {
  const _ChatBody({
    required this.catId,
    required this.aiProvider,
    required this.composer,
    required this.scroll,
    required this.locale,
  });

  final String catId;
  final AiProvider aiProvider;
  final TextEditingController composer;
  final ScrollController scroll;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final List<ChatTurn> history = aiProvider.chatHistory;
    final AppFailure? error = aiProvider.lastError;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: AiGuardrailBanner(
            message: locale == 'bn'
                ? 'AI সহায়তা করে, রোগ নির্ণয় করে না। যেকোনো সিদ্ধান্তের আগে পশুচিকিত্সকের পরামর্� নিন।'
                : 'AI assists, does not diagnose. Always confirm with a vet.',
          ),
        ),
        Expanded(
          child: history.isEmpty
              ? const _EmptyChat()
              : ListView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: history.length + 1,
                  itemBuilder: (BuildContext context, int index) {
                    if (index == history.length) {
                      // Tail spinner while the next reply is in flight.
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: aiProvider.chatBusy
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      );
                    }
                    final ChatTurn turn = history[index];
                    return _ChatBubble(
                      turn: turn,
                      locale: locale,
                      textTheme: text,
                    );
                  },
                ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: aiProvider.isQuotaLimited
                ? AiQuotaBanner(onDismiss: aiProvider.clearError)
                : AiErrorCard(failure: error, onDismiss: aiProvider.clearError),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: AiPromptField(
                    controller: composer,
                    enabled: aiProvider.aiAvailable && !aiProvider.chatBusy,
                    hintText: locale == 'bn'
                        ? 'প্রশ্ন লিখুন…'
                        : 'Ask anything about your cat…',
                    onSubmitted: (_) => _send(context),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Send',
                  onPressed: (aiProvider.aiAvailable && !aiProvider.chatBusy)
                      ? () => _send(context)
                      : null,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _send(BuildContext context) async {
    final String text = composer.text.trim();
    if (text.isEmpty) return;
    composer.clear();
    final AiProvider provider = context.read<AiProvider>();
    await provider.sendChatMessage(
      catId: catId,
      userMessage: text,
      locale: locale,
    );
    if (!scroll.hasClients) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!scroll.hasClients) return;
    await scroll.animateTo(
      scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.turn,
    required this.locale,
    required this.textTheme,
  });

  final ChatTurn turn;
  final String locale;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final bool isUser = turn.role == 'user';
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: isUser ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              turn.text,
              style: textTheme.bodyMedium?.copyWith(
                color: isUser ? scheme.onPrimary : scheme.onSurface,
              ),
            ),
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.medical_services_outlined,
                      size: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      locale == 'bn'
                          ? 'পশুচিকিত্সক দ্বারা যাচাই করুন'
                          : 'Verify with a vet',
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.support_agent_outlined, size: 56, color: scheme.primary),
            const SizedBox(height: 12),
            Text(
              'Ask anything about your cat',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Examples: "My cat vomited once — should I worry?", '
              '"Is it safe to give cooked chicken?", '
              '"How much should my kitten sleep?"',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Text(
              'Tip: type in English or বাংলা — the assistant replies '
              'in the same language.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: <Widget>[
                _SuggestionChip(
                  label: 'Weekly Report',
                  icon: Icons.insights_outlined,
                  onTap: () => context.push('/weekly-report'),
                ),
                _SuggestionChip(
                  label: 'Emergency Guide',
                  icon: Icons.local_hospital_outlined,
                  onTap: () => context.push('/emergency'),
                ),
                _SuggestionChip(
                  label: 'Food Label',
                  icon: Icons.qr_code_scanner_outlined,
                  onTap: () => _showLabelHint(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showLabelHint(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Open Food Label from the Profile tab to scan a label photo.',
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

class _NoActiveCat extends StatelessWidget {
  const _NoActiveCat();

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.pets_outlined,
      title: 'No active cat',
      subtitle:
          'Add or select a cat from the Profile tab to chat with the AI assistant.',
    );
  }
}
