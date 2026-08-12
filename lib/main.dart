import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'providers/theme_provider.dart';
import 'widgets/vhs_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  runApp(
    const ProviderScope(
      child: EasyLoaderApp(),
    ),
  );
}

class EasyLoaderApp extends ConsumerWidget {
  const EasyLoaderApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preset = ref.watch(themeProvider);
    final themeData = AppThemeData.fromPreset(preset);

    return MaterialApp(
      title: 'Easy Loader Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: themeData.primaryColor,
        scaffoldBackgroundColor: themeData.backgroundColor,
        appBarTheme: AppBarTheme(
          backgroundColor: themeData.backgroundColor,
          elevation: 0,
          iconTheme: IconThemeData(color: themeData.textColor),
        ),
      ),
      builder: (context, child) {
        return preset == AppThemePreset.vhsTheme 
          ? VhsOverlay(child: child!) 
          : child!;
      },
      home: const HomeScreen(),
    );
  }
}
