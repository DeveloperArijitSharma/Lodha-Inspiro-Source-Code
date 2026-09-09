import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../app_preferences.dart';
import '../main.dart';
import '../ui/app_ui.dart';

/// Drop-in settings section for the existing Settings page.
/// Every control updates the runtime immediately and persists its value.
class AdvancedSettingsSection extends StatelessWidget {
  final bool isDark;
  final Color accentColor;

  const AdvancedSettingsSection({
    super.key,
    required this.isDark,
    this.accentColor = InspiroUi.accent,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : const Color(0xFF172033);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(.08)
                : Colors.white.withOpacity(.68),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(.12) : Colors.white,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.07),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ValueListenableBuilder<bool>(
            valueListenable: smoothMotionNotifier,
            builder: (context, smoothMotion, _) {
              return Column(
                children: [
                  _settingSwitch(
                    context,
                    icon: CupertinoIcons.refresh,
                    title: 'Smooth animations',
                    subtitle:
                        'Use short, fluid transitions and instant feedback.',
                    value: smoothMotion,
                    onChanged: setSmoothMotion,
                    textColor: textColor,
                  ),
                  Divider(
                    height: 22,
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: hapticsNotifier,
                    builder: (context, haptics, _) => _settingSwitch(
                      context,
                      icon: CupertinoIcons.hand_thumbsup,
                      title: 'Touch feedback',
                      subtitle:
                          'Use gentle haptics when controls are tapped.',
                      value: haptics,
                      onChanged: setHaptics,
                      textColor: textColor,
                    ),
                  ),
                  Divider(
                    height: 22,
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: notificationsNotifier,
                    builder: (context, notifications, _) => _settingSwitch(
                      context,
                      icon: CupertinoIcons.bell,
                      title: 'Notifications',
                      subtitle:
                          'Allow Inspiro to request notification permission.',
                      value: notifications,
                      onChanged: setNotifications,
                      textColor: textColor,
                    ),
                  ),
                  Divider(
                    height: 22,
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      CupertinoIcons.refresh,
                      color: accentColor,
                    ),
                    title: Text(
                      'Reset app appearance',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                        fontFamily: InspiroUi.systemFont,
                      ),
                    ),
                    subtitle: Text(
                      'Return theme, motion and touch settings to defaults.',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontFamily: InspiroUi.systemFont,
                      ),
                    ),
                    trailing: Icon(
                      CupertinoIcons.chevron_right,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                    onTap: () async {
                      themeNotifier.value = ThemeMode.light;
                      await setSmoothMotion(true);
                      await setHaptics(true);
                      await setNotifications(true);
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _settingSwitch(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Future<void> Function(bool) onChanged,
    required Color textColor,
  }) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon, color: accentColor),
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontFamily: InspiroUi.systemFont,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: isDark ? Colors.white54 : Colors.black54,
          fontSize: 12.5,
          fontFamily: InspiroUi.systemFont,
        ),
      ),
      value: value,
      activeColor: accentColor,
      onChanged: onChanged,
    );
  }
}
