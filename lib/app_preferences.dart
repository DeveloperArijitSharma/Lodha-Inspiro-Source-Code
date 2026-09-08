import 'package:flutter/foundation.dart';

import 'settings_service.dart';

/// Runtime preferences shared across the app.
/// Notifiers make UI changes immediate while SharedPreferences keeps them
/// after the app is restarted.
final ValueNotifier<bool> smoothMotionNotifier = ValueNotifier<bool>(true);
final ValueNotifier<bool> hapticsNotifier = ValueNotifier<bool>(true);
final ValueNotifier<bool> notificationsNotifier = ValueNotifier<bool>(true);

Future<void> loadAppPreferences() async {
  final values = await InspiroSettingsService.load();
  smoothMotionNotifier.value = values['smoothMotion'] ?? true;
  hapticsNotifier.value = values['haptics'] ?? true;
  notificationsNotifier.value = values['notifications'] ?? true;
}

Future<void> setSmoothMotion(bool enabled) async {
  smoothMotionNotifier.value = enabled;
  await InspiroSettingsService.saveSmoothMotion(enabled);
}

Future<void> setHaptics(bool enabled) async {
  hapticsNotifier.value = enabled;
  await InspiroSettingsService.saveHaptics(enabled);
}

Future<void> setNotifications(bool enabled) async {
  notificationsNotifier.value = enabled;
  await InspiroSettingsService.saveNotifications(enabled);
}
