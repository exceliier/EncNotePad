import 'package:flutter_test/flutter_test.dart';
import 'package:encnotepad/features/document/domain/document_model.dart';
import 'package:encnotepad/features/document/ui/editor_screen.dart';

void main() {
  group('Search Functionality Tests', () {
    late DocumentModel document;

    setUp(() {
      final part1 = PartModel(
        id: 'p1',
        title: 'Banking Password',
        body: 'Username: admin, SecretKey: 998877',
        order: 0,
      );
      final part2 = PartModel(
        id: 'p2',
        title: 'AWS Cloud Console',
        body: 'Access Key ID: AKIAIOSFODNN7EXAMPLE',
        order: 1,
      );
      final sec1 = SectionModel(
        id: 's1',
        title: 'Financial Accounts',
        isCollapsed: true,
        order: 0,
        parts: [part1],
      );
      final sec2 = SectionModel(
        id: 's2',
        title: 'Work & DevOps',
        isCollapsed: true,
        order: 1,
        parts: [part2],
      );

      document = DocumentModel(
        meta: DocumentMeta.create(),
        sections: [sec1, sec2],
      );
    });

    test('Computes search matches for Section Title', () {
      final results = computeSearchResults(document, 'Financial');
      expect(results.length, equals(1));
      expect(results.first.type, equals(SearchResultType.section));
      expect(results.first.sectionTitle, equals('Financial Accounts'));
      expect(results.first.matchLocation, equals('Section Title'));
    });

    test('Computes search matches for Part Title', () {
      final results = computeSearchResults(document, 'Banking');
      expect(results.length, equals(1));
      expect(results.first.type, equals(SearchResultType.part));
      expect(results.first.partTitle, equals('Banking Password'));
      expect(results.first.matchLocation, equals('Part Title'));
    });

    test('Computes search matches for Part Details', () {
      final results = computeSearchResults(document, 'AKIAIOSFODNN7EXAMPLE');
      expect(results.length, equals(1));
      expect(results.first.type, equals(SearchResultType.part));
      expect(results.first.partTitle, equals('AWS Cloud Console'));
      expect(results.first.matchLocation, equals('Part Details'));
    });

    test('Returns empty list when query is empty or whitespace', () {
      expect(computeSearchResults(document, ''), isEmpty);
      expect(computeSearchResults(document, '   '), isEmpty);
    });

    test('Performs case-insensitive search', () {
      final results = computeSearchResults(document, 'financial');
      expect(results.length, equals(1));
      expect(results.first.sectionTitle, equals('Financial Accounts'));
    });
  });
}
