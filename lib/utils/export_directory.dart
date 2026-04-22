import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ExportDirectory {
  static Future<Directory> get() async {
    if (Platform.isAndroid) {
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (await downloadDir.exists()) {
        return downloadDir;
      }

      final documentsDir = Directory('/storage/emulated/0/Documents');
      if (await documentsDir.exists()) {
        return documentsDir;
      }

      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) return externalDir;
    }
    return await getApplicationDocumentsDirectory();
  }
}
