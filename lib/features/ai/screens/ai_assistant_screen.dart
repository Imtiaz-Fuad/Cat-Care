import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/cat_profile.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../routes/app_routes.dart';
import '../../cats/providers/cat_provider.dart';
import '../../cats/widgets/cat_photo.dart';
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
            final CatProfile? cat = catProvider.activeCat;
            return Scaffold(
              appBar: AppBar(
                titleSpacing: 16,
                title: Row(
                  children: <Widget>[
                    Text(
                      'Ask AI',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AiLanguagePill(
                        value: _locale,
                        onChanged: (String v) => setState(() => _locale = v),
                      ),
                    ),
                  ],
                ),
                actions: <Widget>[
                  IconButton(
                    tooltip: 'Chat history',
                    icon: const Icon(Icons.history_rounded),
                    onPressed: () {},
                  ),
                ],
              ),
              body: catId == null
                  ? const _NoActiveCat()
                  : _ChatBody(
                      cat: cat,
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
    required this.cat,
    required this.catId,
    required this.aiProvider,
    required this.composer,
    required this.scroll,
    required this.locale,
  });

  final CatProfile? cat;
  final String catId;
  final AiProvider aiProvider;
  final TextEditingController composer;
  final ScrollController scroll;
  final String locale;

  String get _catName => cat?.name ?? 'your cat';

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final List<ChatTurn> history = aiProvider.chatHistory;
    final AppFailure? error = aiProvider.lastError;
    final bool empty = history.isEmpty;

    return Column(
      children: <Widget>[
        _AiHeroHeader(cat: cat, locale: locale),
        Expanded(
          child: ListView.builder(
            controller: scroll,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: empty ? 2 : history.length + 1,
            itemBuilder: (BuildContext context, int index) {
              if (empty) {
                if (index == 0) {
                  return _AiInsightCard(
                    catName: _catName,
                    locale: locale,
                    onLogWater: () => context.push(AppRoutes.addFeeding),
                  );
                }
                return const SizedBox.shrink();
              }
              if (index == history.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: aiProvider.chatBusy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
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
                index: index,
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
        _QuickPromptsRow(
          catName: _catName,
          locale: locale,
          enabled: aiProvider.aiAvailable && !aiProvider.chatBusy,
          onTap: (String label) {
            composer.text = label;
            composer.selection = TextSelection.collapsed(offset: label.length);
          },
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: _AiComposer(
              controller: composer,
              enabled: aiProvider.aiAvailable && !aiProvider.chatBusy,
              hintText: locale == 'bn'
                  ? 'প্রশ্ন লিখুন…'
                  : "Ask about $_catName's health…",
              onSend: () => _send(context),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _send(BuildContext context) async {
    final String t = composer.text.trim();
    if (t.isEmpty) return;
    composer.clear();
    final AiProvider provider = context.read<AiProvider>();
    await provider.sendChatMessage(
      catId: catId,
      userMessage: t,
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
    required this.index,
  });

  final ChatTurn turn;
  final String locale;
  final TextTheme textTheme;
  final int index;

  @override
  Widget build(BuildContext context) {
    final bool isUser = turn.role == 'user';
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: double.infinity,
              child: isUser
                  ? _UserBubble(text: turn.text)
                  : _AssistantBubble(
                      text: turn.text,
                      scheme: scheme,
                      textTheme: textTheme,
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(index),
              style: textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(int idx) {
    // Cheap visual timestamp so the UI matches the Stitch reference
    // without touching the persisted ChatTurn shape.
    final DateTime t = DateTime.now().subtract(Duration(minutes: idx * 7));
    final String hh = t.hour.toString().padLeft(2, '0');
    final String mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFA5482A),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: const Color(0xFFFFF8F3),
          height: 1.35,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  const _AssistantBubble({
    required this.text,
    required this.scheme,
    required this.textTheme,
  });

  final String text;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final List<String> lines = text
        .split(RegExp(r'\n+'))
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .toList();

    final List<Widget> children = <Widget>[];

    for (final String line in lines) {
      final RegExpMatch? dashBullet = RegExp(
        r'^[\-\*•]\s+(.+)$',
      ).firstMatch(line);
      if (dashBullet != null) {
        children.add(
          _BulletRow(
            text: dashBullet.group(1)!,
            scheme: scheme,
            textTheme: textTheme,
          ),
        );
        continue;
      }
      final RegExpMatch? colonLead = RegExp(
        r'^([A-Z][A-Za-z\s]{1,40}):\s*(.+)$',
      ).firstMatch(line);
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: colonLead != null
              ? RichText(
                  text: TextSpan(
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onSecondaryContainer,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                    children: <TextSpan>[
                      TextSpan(
                        text: '${colonLead.group(1)}: ',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: colonLead.group(2)),
                    ],
                  ),
                )
              : Text(
                  line,
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSecondaryContainer,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0E7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.auto_awesome,
                  size: 16,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Ask AI',
                style: textTheme.labelMedium?.copyWith(
                  color: scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  const _BulletRow({
    required this.text,
    required this.scheme,
    required this.textTheme,
  });

  final String text;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final RegExpMatch? m = RegExp(
      r'^([A-Z][A-Za-z\s]{1,40}):\s*(.+)$',
    ).firstMatch(text);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.check_circle_outline,
              size: 16,
              color: scheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: m != null
                ? RichText(
                    text: TextSpan(
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSecondaryContainer,
                        height: 1.4,
                      ),
                      children: <TextSpan>[
                        TextSpan(
                          text: '${m.group(1)}: ',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(text: m.group(2)),
                      ],
                    ),
                  )
                : Text(
                    text,
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onSecondaryContainer,
                      height: 1.4,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _AiLanguagePill extends StatelessWidget {
  const _AiLanguagePill({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
      color: const Color(0xFFA9472A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _PillSegment(
            label: 'EN',
            selected: value == 'en',
            onTap: () => onChanged('en'),
          ),
          _PillSegment(
            label: 'বাং',
            selected: value == 'bn',
            onTap: () => onChanged('bn'),
          ),
        ],
      ),
    );
  }
}

class _PillSegment extends StatelessWidget {
  const _PillSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF8C341F) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
              style: text.labelMedium?.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? Colors.white : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}

class _AiHeroHeader extends StatelessWidget {
  const _AiHeroHeader({required this.cat, required this.locale});

  final CatProfile? cat;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String catName = cat?.name ?? 'your cat';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 44,
            height: 44,
            child: CatPhoto(
              networkUrl: cat?.photoUrl,
              variant: CatPhotoVariant.avatar,
              accentHex: cat?.themeAccentHex,
              semanticLabel: cat == null
                  ? 'Cat photo'
                  : 'Photo of ${cat!.name}',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              locale == 'bn'
                  ? 'আজ আমি কীভাবে $catName-কে সাহায্য করতে পারি?'
                  : 'How can I help with $catName today?',
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiInsightCard extends StatelessWidget {
  const _AiInsightCard({
    required this.catName,
    required this.locale,
    required this.onLogWater,
  });

  final String catName;
  final String locale;
  final VoidCallback onLogWater;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0E7),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.auto_awesome, size: 18, color: Color(0xFF9A452A)),
                const SizedBox(width: 8),
                Text(
                  locale == 'bn' ? 'AI Health Insight' : 'AI Health Insight',
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF5A2A1B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "$catName's water intake has been 15% lower this week. This might be due to the cooler weather, but try refreshing his bowl more often.",
              style: text.bodyMedium?.copyWith(
                color: const Color(0xFF5A2A1B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            _InsightPill(
              icon: Icons.water_drop_outlined,
              label: locale == 'bn' ? 'Log Water' : 'Log Water',
              filled: true,
              onTap: onLogWater,
            ),
          ],
        ),
      ),
    );
  }
}

class _LegacyAiInsightCard extends StatelessWidget {
  const _LegacyAiInsightCard({
    required this.catName,
    required this.locale,
    required this.onLogWater,
  });

  final String catName;
  final String locale;
  final VoidCallback onLogWater;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final WeeklyReportResult? report = null;
    final String insightText = report?.text ??
        (locale == 'bn'
            ? 'à¦¸à¦¾à¦ªà§à¦¤à¦¾à¦¹à¦¿à¦• à¦°à¦¿à¦ªà§‹à¦°à§à¦Ÿ à¦¤à§ˆà¦°à¦¿à¦° à¦œà¦¨à§à¦¯ à¦à¦–à¦¨à§‹ à¦¯à¦¥à§‡à¦·à§à¦Ÿ à¦¤à¦¥à§à¦¯ à¦¨à§‡à¦‡à¥¤'
            : 'Not enough weekly data yet. Log a few meals, water entries, or health records to see your report.');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0E7),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Text(
          insightText,
          style: text.bodyMedium?.copyWith(
            color: const Color(0xFF5A2A1B),
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0E7),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.auto_awesome,
                  size: 18,
                  color: const Color(0xFF9A452A),
                ),
                const SizedBox(width: 8),
                Text(
                  locale == 'bn' ? 'AI স্বাস্থ্য পরামর্শ' : 'AI Health Insight',
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              locale == 'bn'
                  ? "$catName-এর এই সপ্তাহে পানি কম খেয়েছে — ১৫% কম। "
                        'ঠান্ডা আবহাওয়ার কারণে হতে পারে। তাই তার বাটি বারবার '
                        'রিফ্রেশ করে দিন।'
                  : "$catName's water intake has been 15% lower "
                        'this week. This might be due to the cooler '
                        'weather, but try refreshing his bowl more often.',
              style: text.bodyMedium?.copyWith(
                color: const Color(0xFF5A2A1B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _InsightPill(
                  icon: Icons.water_drop_outlined,
                  label: locale == 'bn' ? 'পানি লগ' : 'Log Water',
                  filled: true,
                  onTap: onLogWater,
                ),
                _InsightPill(
                  icon: Icons.menu_book_outlined,
                  label: locale == 'bn' ? 'আরো জানুন' : 'Learn More',
                  filled: false,
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightPill extends StatelessWidget {
  const _InsightPill({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final Color bg = filled ? scheme.primary : scheme.surface;
    final Color fg = filled ? scheme.onPrimary : scheme.onSurface;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: text.labelLarge?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickPromptsRow extends StatelessWidget {
  const _QuickPromptsRow({
    required this.catName,
    required this.locale,
    required this.enabled,
    required this.onTap,
  });

  final String catName;
  final String locale;
  final bool enabled;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _QuickPrompt(
              icon: Icons.description_outlined,
              label: locale == 'bn'
                  ? 'সাপ্তাহিক সারাংশ'
                  : "Summarize $catName's week",
              enabled: enabled,
              textTheme: text,
              scheme: scheme,
              onTap: () => onTap(
                locale == 'bn'
                    ? 'এই সপ্তাহের সারাংশ দিন'
                    : "Summarize this week for $catName",
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QuickPrompt(
              icon: Icons.vaccines_outlined,
              label: locale == 'bn' ? 'টিকার প্রস্তুতি' : 'Vaccination prep',
              enabled: enabled,
              textTheme: text,
              scheme: scheme,
              onTap: () => onTap(
                locale == 'bn'
                    ? 'পরবর্তী টিকার জন্য প্রস্তুতি'
                    : 'Help me prepare for the next vaccination',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickPrompt extends StatelessWidget {
  const _QuickPrompt({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.textTheme,
    required this.scheme,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final TextTheme textTheme;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: scheme.surface,
      shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 16,
                color: enabled ? scheme.onSurfaceVariant : scheme.outline,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelMedium?.copyWith(
                    color: enabled ? scheme.onSurface : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiComposer extends StatelessWidget {
  const _AiComposer({
    required this.controller,
    required this.enabled,
    required this.hintText,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final String hintText;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: TextField(
              controller: controller,
              enabled: enabled,
              maxLines: 3,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: const Color(0xFFA5482A),
          shape: const CircleBorder(),
          child: IconButton(
            tooltip: 'Send',
            onPressed: enabled ? onSend : null,
            icon: const Icon(Icons.send_rounded, color: Color(0xFFFFF8F3)),
          ),
        ),
      ],
    );
  }
}

class _NoActiveCat extends StatelessWidget {
  const _NoActiveCat();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.pets_outlined,
      title: 'No active cat',
      subtitle:
          'Add or select a cat from the Profile tab to chat with the AI assistant.',
    );
  }
}
