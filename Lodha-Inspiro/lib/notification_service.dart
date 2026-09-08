import 'package:flutter/services.dart';

class NotificationService {
  static const MethodChannel _channel =
      MethodChannel('lodha_inspiro/native');

  static Future<void> requestPermission() async {
    try {
      await _channel.invokeMethod('requestNotificationPermission');
    } on PlatformException {
      // Notification permission is optional on older Android versions.
    }
  }

  static Future<void> showChatNotification({
    required String title,
    required String body,
  }) async {
    try {
      await _channel.invokeMethod('showChatNotification', {
        'title': title,
        'body': body,
      });
    } on PlatformException {
      // Keep chat usable even if notifications are unavailable.
    }
  }
}
