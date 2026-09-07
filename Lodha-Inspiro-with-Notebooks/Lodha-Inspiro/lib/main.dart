import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_update_service.dart';
import 'notification_service.dart';
import 'login_screen.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://orsarmmwvjkltpditpnt.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
        'eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9yc2FybW13dmprbHRwZGl0cG50Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ5ODM4MTMsImV4cCI6MjEwMDU1OTgxM30.'
        'T-3DRNT7k6XyK3d3oajNcWkeDxb1yfUGV6QnaqsgJ-M',
  );

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_updateChecked) return;
    _updateChecked = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NotificationService.requestPermission();
      if (!mounted) return;
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      await AppUpdateService().checkAndPrompt(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Lodha Inspiro',
          themeMode: currentMode,
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFEBF0F5),
            fontFamily: 'Google Sans Flex',
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF121212),
            fontFamily: 'Google Sans Flex',
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
          ),
          home: const AuthGate(),
        );
      },
    );
  }
}
