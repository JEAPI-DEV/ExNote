abstract class WaifuService {
  Future<String?> fetchWaifuImage(String tag, {required bool isNsfw});
  List<String> getSfwTags();
  List<String> getNsfwTags();
}
