import 'dart:convert';
import 'package:http/http.dart' as http;
import 'waifu_service.dart';

class NekosiaService implements WaifuService {
  @override
  String get name => 'Nekosia.cat';

  static const String _baseUrl = 'https://api.nekosia.cat/api/v1';

  @override
  List<String> getSfwTags() {
    return [
      'catgirl',
      'foxgirl',
      'wolfgirl',
      'animal-ears',
      'tail',
      'cute',
      'maid',
      'vtuber',
      'uniform',
      'sailor-uniform',
      'hoodie',
      'white-hair',
      'blue-hair',
      'long-hair',
      'blonde',
    ];
  }

  @override
  List<String> getNsfwTags() {
    // Nekosia doesn't provide true NSFW, so we use suggestive tags if applicable.
    // For now, we'll return a subset of tags that might be more appropriate for the 'suggestive' rating.
    return [
      'thigh-high-socks',
      'knee-high-socks',
      'white-tights',
      'black-tights',
      'maid-uniform',
    ];
  }

  @override
  Future<String?> fetchWaifuImage(String tag, {required bool isNsfw}) async {
    final rating = isNsfw ? 'suggestive' : 'safe';
    final url = Uri.parse('$_baseUrl/images/$tag?count=1&rating=$rating');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['image'] != null) {
          return data['image']['original']['url'];
        }
      } else {
        print('Nekosia API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('An error occurred fetching image from Nekosia: $e');
    }
    return null;
  }
}
