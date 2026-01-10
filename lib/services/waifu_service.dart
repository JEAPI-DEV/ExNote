import 'package:waifuim_dart/waifuim_dart.dart';

class WaifuService {
  final WaifuImClient _client;

  WaifuService({bool debug = false}) : _client = WaifuImClient(debug: debug);

  Future<String?> fetchWaifuImage(String tag, {required bool isNsfw}) async {
    try {
      final imageData = await _client.getImage(tag, isNsfw: isNsfw);
      return imageData['url'];
    } catch (e) {
      print('❌ An error occurred fetching waifu image: $e');
      return null;
    }
  }
}
