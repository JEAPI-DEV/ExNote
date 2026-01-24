import 'package:flutter_test/flutter_test.dart';
import 'package:exnote/services/nekos_api_service.dart';

void main() {
  group('NekosApiService', () {
    late NekosApiService service;

    setUp(() {
      service = NekosApiService();
    });

    test('getSfwTags returns a non-empty list', () {
      final tags = service.getSfwTags();
      expect(tags, isNotEmpty);
      expect(tags, contains('girl'));
    });

    test('getNsfwTags returns a non-empty list', () {
      final tags = service.getNsfwTags();
      expect(tags, isNotEmpty);
      expect(tags, contains('pussy'));
    });

    test('fetchWaifuImage returns a valid URL for a valid tag (SFW)', () async {
      final url = await service.fetchWaifuImage('girl', isNsfw: false);
      expect(url, isNotNull);
      expect(url, startsWith('https://'));
      expect(url, contains('nekos-api'));
    });

    test(
      'fetchWaifuImage returns a valid URL for a valid tag (NSFW)',
      () async {
        final url = await service.fetchWaifuImage('pussy', isNsfw: true);
        expect(url, isNotNull);
        expect(url, startsWith('https://'));
        expect(url, contains('nekos-api'));
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
