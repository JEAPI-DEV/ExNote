import 'dart:convert';
import 'package:http/http.dart' as http;
import 'waifu_service.dart';

class WaifuPicsService implements WaifuService {
  static const String _baseUrl = 'https://api.waifu.pics';

  @override
  List<String> getSfwTags() {
    return [
      'waifu',
      'neko',
      'shinobu',
      'megumin',
      'bully',
      'cuddle',
      'cry',
      'hug',
      'awoo',
      'kiss',
      'lick',
      'pat',
      'smug',
      'bonk',
      'yeet',
      'blush',
      'smile',
      'wave',
      'highfive',
      'handhold',
      'nom',
      'bite',
      'glomp',
      'slap',
      'kill',
      'kick',
      'happy',
      'wink',
      'poke',
      'dance',
      'cringe',
    ];
  }

  @override
  List<String> getNsfwTags() {
    return ['waifu', 'neko', 'trap', 'blowjob'];
  }

  @override
  Future<String?> fetchWaifuImage(String tag, {required bool isNsfw}) async {
    try {
      final type = isNsfw ? 'nsfw' : 'sfw';
      final uri = Uri.parse('$_baseUrl/$type/$tag');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        return data['url'];
      } else {
        print('Waifu.pics API Error: ${response.statusCode}');
      }
    } catch (e) {
      print('An error occurred fetching Waifu.pics image: $e');
    }
    return null;
  }
}
