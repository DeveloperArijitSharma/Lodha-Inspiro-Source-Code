import 'package:shared_preferences/shared_preferences.dart';

class InspiroSettingsService {
  static const _darkModeKey = 'inspiro_dark_mode';
  static const _motionKey = 'inspiro_smooth_motion';
  static const _hapticsKey = 'inspiro_haptics';
  static const _notificationsKey = 'inspiro_notifications';

  static Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  static Future<void> saveTheme(bool dark) async =>
      (await _prefs).setBool(_darkModeKey, dark);

  static Future<void> saveSmoothMotion(bool enabled) async =>
      (await _prefs).setBool(_motionKey, enabled);

  static Future<void> saveHaptics(bool enabled) async =>
      (await _prefs).setBool(_hapticsKey, enabled);

  static Future<void> saveNotifications(bool enabled) async =>
      (await _prefs).setBool(_notificationsKey, enabled);

  static Future<Map<String, bool>> load() async {
    final prefs = await _prefs;
    return {
      'darkMode': prefs.getBool(_darkModeKey) ?? false,
      'smoothMotion': prefs.getBool(_motionKey) ?? true,
      'haptics': prefs.getBool(_hapticsKey) ?? true,
      'notifications': prefs.getBool(_notificationsKey) ?? true,
    };
  }
}
