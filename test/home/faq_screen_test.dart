import 'package:cat_care/features/home/models/faq_entry.dart';
import 'package:cat_care/features/home/repositories/faq_repository.dart';
import 'package:cat_care/features/home/screens/faq_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('FAQ repository loads and categorizes the bundled JSON', () async {
    final List<FaqEntry> entries = await const FaqRepository().load();
    final Set<String> categories = entries
        .map((FaqEntry entry) => entry.category)
        .toSet();

    expect(entries, hasLength(55));
    expect(
      categories,
      containsAll(<String>{
        'food',
        'behavior',
        'litter',
        'health',
        'grooming',
        'safety',
      }),
    );
    expect(entries.first.questionBn, isNotEmpty);
    expect(entries.first.answerBn, isNotEmpty);
  });

  testWidgets('FAQ groups questions inside category dropdowns', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: FaqScreen(loadEntries: _loadEntries)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Question'), findsNothing);

    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();

    expect(find.text('Question'), findsOneWidget);
    expect(find.text('Answer'), findsNothing);

    await tester.tap(find.text('Question'));
    await tester.pumpAndSettle();

    expect(find.text('Answer'), findsOneWidget);
  });

  testWidgets('FAQ language selection uses Bangla fields', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: FaqScreen(loadEntries: _loadEntries)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('বাংলা'));
    await tester.pumpAndSettle();

    expect(find.text('খাবার'), findsOneWidget);
    await tester.tap(find.text('খাবার'));
    await tester.pumpAndSettle();
    expect(find.text('প্রশ্ন'), findsOneWidget);
  });
}

Future<List<FaqEntry>> _loadEntries() async => const <FaqEntry>[
  FaqEntry(
    id: 'id',
    category: 'food',
    questionEn: 'Question',
    questionBn: 'প্রশ্ন',
    answerEn: 'Answer',
    answerBn: 'উত্তর',
  ),
];
