import 'waifu_service.dart';
import 'waifu_im_service.dart';
import 'waifu_pics_service.dart';
import 'nekosia_service.dart';
import 'nekos_api_service.dart';

class WaifuProviderRegistry {
  static final List<WaifuService> providers = [
    WaifuImService(),
    WaifuPicsService(),
    NekosiaService(),
    NekosApiService(),
  ];

  static WaifuService getProvider(String name) {
    return providers.firstWhere(
      (p) => p.name == name,
      orElse: () => providers.first,
    );
  }

  static List<String> get providerNames =>
      providers.map((p) => p.name).toList();
}
