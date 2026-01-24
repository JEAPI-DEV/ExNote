import 'dart:convert';
import 'package:http/http.dart' as http;
import 'waifu_service.dart';

class NekosApiService implements WaifuService {
  @override
  String get name => 'NekosAPI';

  static const String _baseUrl = 'https://api.nekosapi.com/v4';

  @override
  List<String> getSfwTags() {
    return [
      'girl',
      'catgirl',
      'school_uniform',
      'white_hair',
      'pink_hair',
      'blue_hair',
      'black_hair',
      'blonde_hair',
      'brown_hair',
      'red_hair',
      'purple_hair',
      'dress',
      'skirt',
      'bunny_girl',
      'maid',
      'glasses',
      'gloves',
      'horsegirl',
      'kemonomimi',
      'usagimimi',
      'beach',
      'flowers',
      'ice_cream',
      'kissing',
      'night',
      'plants',
      'rain',
      'shorts',
      'sunny',
      'sword',
      'tree',
      'weapon',
      'mountain',
      'reading',
    ];
  }

  @override
  List<String> getNsfwTags() {
    return [
      'bikini',
      'wet',
      'yuri',
      'large_breasts',
      'medium_breasts',
      'small_breasts',
      'exposed_girl_breasts',
      'pussy',
      'masturbating',
    ];
  }

  @override
  Future<String?> fetchWaifuImage(String tag, {required bool isNsfw}) async {
    final ratings = isNsfw ? 'suggestive,borderline,explicit' : 'safe';
    final url = Uri.parse(
      '$_baseUrl/images/random?limit=1&tags=$tag&rating=$ratings',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          return data[0]['url'];
        }
      } else {
        print('NekosAPI error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('An error occurred fetching image from NekosAPI: $e');
    }
    return null;
  }
}
