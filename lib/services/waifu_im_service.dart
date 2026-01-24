import 'package:waifuim_dart/waifuim_dart.dart';
import 'waifu_service.dart';

class WaifuImService implements WaifuService {
  @override
  String get name => 'Waifu.im';

  final WaifuImClient _client;

  WaifuImService({bool debug = false}) : _client = WaifuImClient(debug: debug);

  @override
  List<String> getSfwTags() {
    return [
      'waifu',
      'maid',
      'marin-kitagawa',
      'mori-calliope',
      'raiden-shogun',
      'oppai',
      'selfies',
      'uniform',
      'kamisato-ayaka',
    ];
  }

  @override
  List<String> getNsfwTags() {
    return ['ass', 'hentai', 'paizuri', 'oral', 'ecchi', 'ero'];
  }

  @override
  Future<String?> fetchWaifuImage(String tag, {required bool isNsfw}) async {
    try {
      final imageData = await _client.getImage(tag, isNsfw: isNsfw);
      return imageData['url'];
    } catch (e) {
      print('An error occurred fetching waifu image: $e');
      return null;
    }
  }
}
