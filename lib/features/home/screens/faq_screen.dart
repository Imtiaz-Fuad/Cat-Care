import 'package:flutter/material.dart';

import '../models/faq_entry.dart';
import '../repositories/faq_repository.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({this.loadEntries, super.key});

  final Future<List<FaqEntry>> Function()? loadEntries;

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  late final Future<List<FaqEntry>> _entries;
  String _language = 'en';

  @override
  void initState() {
    super.initState();
    _entries = (widget.loadEntries ?? const FaqRepository().load)();
  }

  @override
  Widget build(BuildContext context) {
    final bool bangla = _language == 'bn';
    return Scaffold(
      appBar: AppBar(title: Text(bangla ? 'সাধারণ প্রশ্ন' : 'FAQ')),
      body: FutureBuilder<List<FaqEntry>>(
        future: _entries,
        builder:
            (BuildContext context, AsyncSnapshot<List<FaqEntry>> snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      bangla
                          ? 'প্রশ্নগুলো লোড করা যায়নি।'
                          : 'The questions could not be loaded.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                );
              }

              final Map<String, List<FaqEntry>> categories = _groupByCategory(
                snapshot.data ?? const <FaqEntry>[],
              );
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: <Widget>[
                  _Header(
                    language: _language,
                    onLanguageChanged: (String value) {
                      setState(() => _language = value);
                    },
                  ),
                  const SizedBox(height: 18),
                  for (final MapEntry<String, List<FaqEntry>> category
                      in categories.entries) ...<Widget>[
                    _CategoryTile(
                      category: category.key,
                      entries: category.value,
                      language: _language,
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
      ),
    );
  }

  Map<String, List<FaqEntry>> _groupByCategory(List<FaqEntry> entries) {
    final Map<String, List<FaqEntry>> grouped = <String, List<FaqEntry>>{};
    for (final FaqEntry entry in entries) {
      grouped.putIfAbsent(entry.category, () => <FaqEntry>[]).add(entry);
    }
    return grouped;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.language, required this.onLanguageChanged});

  final String language;
  final ValueChanged<String> onLanguageChanged;

  @override
  Widget build(BuildContext context) {
    final bool bangla = language == 'bn';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          bangla
              ? 'আপনি কি কখনো বিড়াল পোষেননি? এগুলো আপনার কাজে আসতে পারে'
              : 'New cat parent? These might help you.',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: const Color(0xFF5A2A1B),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        SegmentedButton<String>(
          segments: const <ButtonSegment<String>>[
            ButtonSegment<String>(value: 'en', label: Text('English')),
            ButtonSegment<String>(value: 'bn', label: Text('বাংলা')),
          ],
          selected: <String>{language},
          onSelectionChanged: (Set<String> selection) {
            if (selection.isNotEmpty) onLanguageChanged(selection.first);
          },
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith<Color?>((
              Set<WidgetState> states,
            ) {
              return states.contains(WidgetState.selected)
                  ? const Color(0xFFA5482A)
                  : const Color(0xFFFFF8F4);
            }),
            foregroundColor: WidgetStateProperty.resolveWith<Color?>((
              Set<WidgetState> states,
            ) {
              return states.contains(WidgetState.selected)
                  ? Colors.white
                  : const Color(0xFF6D3525);
            }),
          ),
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.entries,
    required this.language,
  });

  final String category;
  final List<FaqEntry> entries;
  final String language;

  @override
  Widget build(BuildContext context) {
    const BorderSide edge = BorderSide(color: Color(0xFFE5A990));
    final BorderRadius radius = BorderRadius.circular(20);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: const Color(0xFFFFEFE7),
      shape: RoundedRectangleBorder(borderRadius: radius, side: edge),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: ValueKey<String>('category-$category-$language'),
        maintainState: true,
        shape: RoundedRectangleBorder(borderRadius: radius, side: edge),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: radius,
          side: edge,
        ),
        iconColor: const Color(0xFF9A452A),
        collapsedIconColor: const Color(0xFF9A452A),
        title: Text(
          _categoryLabel(category, language),
          style: const TextStyle(
            color: Color(0xFF5A2A1B),
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          language == 'bn'
              ? '${entries.length}টি প্রশ্ন'
              : '${entries.length} questions',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        children: <Widget>[
          for (int index = 0; index < entries.length; index++) ...<Widget>[
            _QuestionTile(entry: entries[index], language: language),
            if (index < entries.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  String _categoryLabel(String value, String language) {
    if (language == 'bn') {
      return switch (value) {
        'food' => 'খাবার',
        'behavior' => 'আচরণ',
        'litter' => 'লিটার',
        'health' => 'স্বাস্থ্য',
        'grooming' => 'পরিচর্যা',
        'safety' => 'নিরাপত্তা',
        _ => value,
      };
    }
    return value.isEmpty
        ? value
        : '${value[0].toUpperCase()}${value.substring(1)}';
  }
}

class _QuestionTile extends StatelessWidget {
  const _QuestionTile({required this.entry, required this.language});

  final FaqEntry entry;
  final String language;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(16);
    return Material(
      color: const Color(0xFFFFFBF8),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: Color(0xFFEBC3B4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: ValueKey<String>('question-${entry.id}-$language'),
        shape: RoundedRectangleBorder(borderRadius: radius),
        collapsedShape: RoundedRectangleBorder(borderRadius: radius),
        iconColor: const Color(0xFF9A452A),
        collapsedIconColor: const Color(0xFF9A452A),
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        title: Text(
          entry.questionFor(language),
          style: const TextStyle(
            color: Color(0xFF442A22),
            fontWeight: FontWeight.w700,
          ),
        ),
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              entry.answerFor(language),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF654B42),
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
