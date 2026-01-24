import 'package:flutter_test/flutter_test.dart';
import 'package:exnote/services/nekosia_service.dart';

void main() {
  group('NekosiaService', () {
    late NekosiaService service;

    setUp(() {
      service = NekosiaService();
    });

    test('getSfwTags returns a non-empty list', () {
      final tags = service.getSfwTags();
      expect(tags, isNotEmpty);
      expect(tags, contains('catgirl'));
    });

    test('getNsfwTags returns a non-empty list', () {
      final tags = service.getNsfwTags();
      expect(tags, isNotEmpty);
      expect(tags, contains('thigh-high-socks'));
    });

    test('fetchWaifuImage returns a valid URL for a valid tag (SFW)', () async {
      // This is a live test, which might be flaky but good for smoke testing
      final url = await service.fetchWaifuImage('catgirl', isNsfw: false);
      expect(url, isNotNull);
      expect(url, startsWith('https://cdn.nekosia.cat/'));
    });

    test(
      'fetchWaifuImage returns a valid URL for a valid tag (Suggestive)',
      () async {
        final url = await service.fetchWaifuImage('maid', isNsfw: true);
        expect(url, isNotNull);
        expect(url, startsWith('https://cdn.nekosia.cat/'));
      },
    );

    test('fetchWaifuImage returns null for an invalid tag', () async {
      final url = await service.fetchWaifuImage(
        'invalid_tag_12345',
        isNsfw: false,
      );
      expect(url, isNull);
    });
  });
}
