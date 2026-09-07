import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'home_screen.dart';

// Global ValueNotifier to handle Light/Dark mode toggling
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase with session persistence
  await Supabase.initialize(
    url:
        'https://orsarmmwvjkltpditpnt.supabase.co', // 🔴 Replace with your Supabase URL
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9yc2FybW13dmprbHRwZGl0cG50Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ5ODM4MTMsImV4cCI6MjEwMDU1OTgxM30.T-3DRNT7k6XyK3d3oajNcWkeDxb1yfUGV6QnaqsgJ-M', // 🔴 Replace with your Supabase Anon Key
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Lodha Inspiro',
          themeMode: currentMode,

          // ☀️ LIGHT THEME
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(
                0xFFEBF0F5), // Soft light grey for liquid glass to pop
            fontFamily: 'Google Sans Flex',
            appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent, elevation: 0),
          ),

          // 🌙 DARK THEME
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF121212),
            fontFamily: 'Google Sans Flex',
            appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent, elevation: 0),
          ),

          home: const AuthGate(),
        );
      },
    );
  }
}
