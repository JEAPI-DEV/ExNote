abstract class WaifuService {
  String get name;
  Future<String?> fetchWaifuImage(String tag, {required bool isNsfw});
  List<String> getSfwTags();
  List<String> getNsfwTags();

  @override
  String toString() => name;
}
