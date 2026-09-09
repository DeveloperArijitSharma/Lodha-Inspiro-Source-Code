import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_preferences.dart';
import 'app_update_service.dart';
import 'notification_service.dart';
import 'login_screen.dart';
import 'settings_service.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  await Supabase.initialize(
    url: 'https://orsarmmwvjkltpditpnt.supabase.co',
    anonKey: 'sb_publishable_5ODxWB_3VB_JUJDdLyfjuQ_fG4aUlUi',
  );

  final preferences = await InspiroSettingsService.load();
  themeNotifier.value = (preferences['darkMode'] ?? false)
      ? ThemeMode.dark
      : ThemeMode.light;
  await loadAppPreferences();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _updateChecked = false;

  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_persistTheme);
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_persistTheme);
    super.dispose();
  }

  Future<void> _persistTheme() async {
    await InspiroSettingsService.saveTheme(themeNotifier.value == ThemeMode.dark);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_updateChecked) return;
    _updateChecked = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (notificationsNotifier.value) {
        await NotificationService.requestPermission();
      }
      if (!mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      await AppUpdateService().checkAndPrompt(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        final motionDuration = smoothMotionNotifier.value
            ? const Duration(milliseconds: 180)
            : Duration.zero;
        final isDark = currentMode == ThemeMode.dark;

        final systemBarStyle = SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          statusBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness:
              isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
        );

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: systemBarStyle,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Lodha Inspiro',
            themeMode: currentMode,
            themeAnimationDuration: motionDuration,
            theme: ThemeData(
              brightness: Brightness.light,
              scaffoldBackgroundColor: const Color(0xFFEBF0F5),
              fontFamily: 'Google Sans Flex',
              splashFactory: InkSparkle.splashFactory,
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent,
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                systemOverlayStyle: SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.dark,
                  statusBarBrightness: Brightness.light,
                ),
              ),
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF121212),
              fontFamily: 'Google Sans Flex',
              splashFactory: InkSparkle.splashFactory,
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent,
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                systemOverlayStyle: SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.light,
                  statusBarBrightness: Brightness.dark,
                ),
              ),
            ),
            home: const AuthGate(),
          ),
        );
      },
    );
  }
}