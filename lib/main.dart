import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:spen_remote/spen_remote.dart';
import 'screens/folder_screen.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';
import 'services/stylus_shortcut_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check if it's an Android Samsung device to enable S Pen features
  if (Platform.isAndroid) {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;

    if (androidInfo.manufacturer.toLowerCase() == 'samsung') {
      try {
        await SpenRemote.connect();
        SpenRemote.events.listen((event) {
          if (event.type == 'button') {
            if (event.action == 0) {
              StylusShortcutManager.instance.toggleTool();
            }
          } else if (event.type == 'motion') {
            debugPrint('Air motion dx=${event.dx}, dy=${event.dy}');
          }
        });
      } catch (e) {
        debugPrint('Failed to connect to S Pen: $e');
      }
    }
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Ex Note',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const FolderScreen(),
    );
  }
}
